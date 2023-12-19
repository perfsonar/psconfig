'''
Classes for metric collection about pSConfig agents
'''

import re
import datetime

from file_read_backwards import FileReadBackwards
from json import loads, dumps

class PSConfigRunMetrics:
    guid = None
    pid = None
    start = None
    end = None
    total = 0
    by_src = {}

    def __init__(self, agent_name):
        self.agent_name = agent_name

    def _to_iso8601(self, time_str):
        return time_str.replace(' ', 'T') + 'Z'
 
    def _to_ts(self, time_str):
        return int(datetime.datetime.timestamp(datetime.datetime.strptime(time_str,"%Y-%m-%d %H:%M:%S")))
 
    def to_json(self, pretty=False):
        agent_key = "{}-agent".format(self.agent_name)
        tasks_key = "{}-agent".format(self.agent_name)
        json_obj = { agent_key: {}, tasks_key: {} }
        #fill in agent info
        if self.start:
            json_obj[agent_key]["start-time"] = self._to_iso8601(self.start)
        if self.end:
            json_obj[agent_key]["end-time"] = self._to_iso8601(self.end)

        #fill in task info
        json_obj[tasks_key]["total"] = self.total
        for src, src_obj in self.by_src.items():
            json_obj[tasks_key][src] = { "total": src_obj.get("total", None) }
            for url, url_count in src_obj.get("by_url", {}).items():
                json_obj[tasks_key][src][url] = url_count

        #return json string
        if pretty:
            return dumps(json_obj, indent=2)
        return dumps(json_obj)

    def to_prometheus(self):
        s = "# HELP perfsonar_psconfig_{0}_agent_start_time Number of seconds since 1970 of psconfig-{0}-agent start time\n".format(self.agent_name)
        s += "# TYPE perfsonar_psconfig_{0}_agent_start_time gauge\n".format(self.agent_name)
        s += 'perfsonar_psconfig_{}_agent_start_time{{guid="{}"}} {}\n'.format(self.agent_name, self.guid, self._to_ts(self.start))
        s += "# HELP perfsonar_psconfig_{0}_agent_end_time Number of seconds since 1970 of psconfig-{0}-agent end time\n".format(self.agent_name)
        s += "# TYPE perfsonar_psconfig_{0}_agent_end_time gauge\n".format(self.agent_name)
        s += 'perfsonar_psconfig_{}_agent_end_time{{guid="{}"}} {}\n'.format(self.agent_name, self.guid, self._to_ts(self.end))
        if self.by_src:
            s += "# HELP perfsonar_psconfig_{0}_tasks Number of tasks configured by pSConfig in {0}\n".format(self.agent_name)
            s += "# TYPE perfsonar_psconfig_{0}_tasks gauge\n".format(self.agent_name)
            for src, src_obj in self.by_src.items():
                s += 'perfsonar_psconfig_{}_tasks{{guid="{}",src="{}"}} {}\n'.format(self.agent_name, self.guid, src, src_obj["total"])
                for url, url_count in src_obj.get("by_url", {}).items():
                    s += 'perfsonar_psconfig_{}_tasks{{guid="{}",src="{}",url="{}"}} {}\n'.format(self.agent_name, self.guid, src, url, url_count)
        
        return s

    def __str__(self) -> str:
        s = "Agent Last Run Start Time: {}\n".format(self.start)
        s += "Agent Last Run End Time: {}\n".format(self.end)
        s += "Agent Last Run Process ID (PID): {}\n".format(self.pid)
        s += "Agent Last Run Log GUID: {}\n".format(self.guid)
        s += "Total tasks managed by agent: {}\n".format(self.total)
        for src in sorted(self.by_src.keys()):
            src_stats = self.by_src.get(src, {})
            if src == 'remote':
                s += "From remote definitions: {}\n".format(src_stats.get("total", 0))
            elif src == 'include':
                s += "From include files: {}\n".format(src_stats.get("total", 0))
            else:
                s += "From {}: {}\n".format(src, src_stats.get("total", 0))

            for url in sorted(src_stats.get("by_url", {}).keys()):
                s += "    {}: {}\n".format(url, src_stats["by_url"][url])

        return s

class PSConfigMetricCalculator:

    def __init__(self, agent_name, logdir="/var/log/perfsonar"):
        self.logdir = logdir
        self.agent_name = agent_name

    def agent_log_file(self):
        return "{}/psconfig-{}-agent.log".format(self.logdir, self.agent_name)

    def tasks_log_file(self):
        return "{}/psconfig-{}-agent-tasks.log".format(self.logdir, self.agent_name)

    def find_guid(self):
        guid = None
        guid_regex = re.compile('^.*guid=(.+?) msg=Agent completed running$')
        with FileReadBackwards(self.agent_log_file(), encoding="utf-8") as frb:
            while True:
                l = frb.readline()
                if not l:
                    break
                
                guid_match = guid_regex.match(l)
                if guid_match:
                    guid = guid_match.group(1)
                    break
        return guid
    

    def run_metrics(self, guid_match='.+?'):
        stats = PSConfigRunMetrics(self.agent_name)

        #Get guid, pid start and end info from agent log
        run_end_regex = re.compile(f'^(.+) INFO pid=(.+?) prog=.+? line=.+? guid=({guid_match}) msg=Agent completed running$')
        run_start_regex = None
        with FileReadBackwards(self.agent_log_file(), encoding="utf-8") as frb:
            while True:
                #Check end of file
                l = frb.readline()
                if not l:
                    break
                
                #Check end of run (we'll see this first since going backwards through)
                run_end_match = run_end_regex.match(l)
                if run_start_regex:
                    run_start_match = run_start_regex.match(l)
                    if run_start_match:
                        stats.start = run_start_match.group(1)
                        break
                elif run_end_match:
                    stats.end = run_end_match.group(1)
                    stats.pid = run_end_match.group(2)
                    stats.guid = run_end_match.group(3)
                    run_start_regex = re.compile(f'^(.+) INFO pid={stats.pid} prog=.+? line=.+? guid={stats.guid} msg=Running agent\.\.\.$')

        #Check if we found a guid, return if not
        if stats.guid is None:
            return stats

        #If we have guid, calculate stats
        run_ctx_regex = re.compile(f"^.+ INFO guid={stats.guid} (.+) task=.+$")
        with FileReadBackwards(self.tasks_log_file(), encoding="utf-8") as frb:
            while True:
                #end if no more lines
                l = frb.readline()
                if not l:
                    break
                
                #match run context fields
                run_ctx_match = run_ctx_regex.match(l)
                if not run_ctx_match:
                    #skip if no match
                    continue
                
                # we have a match, let's do some math
                stats.total += 1
                
                #figure out context fields (these vary, hence not in regex)
                ctx_map = {}
                for ctx_kv in re.findall(r'(\w+?)=(.+?)( |$)', run_ctx_match.group(1)):
                    ctx_map[ctx_kv[0]] = ctx_kv[1]
                
                #calculate categorical stats
                if ctx_map.get("config_src", None):
                    curr_stat = stats.by_src.setdefault(ctx_map["config_src"], {'total': 0, 'by_url': {} })
                    curr_stat['total'] += 1
                    if ctx_map.get("config_url", None):
                        curr_stat['by_url'].setdefault(ctx_map["config_url"], 0)
                        curr_stat['by_url'][ctx_map["config_url"]] += 1
                    elif ctx_map.get("config_file", None):
                        curr_stat['by_url'].setdefault(ctx_map["config_file"], 0)
                        curr_stat['by_url'][ctx_map["config_file"]] += 1
                
        return stats

    def get_tasks(self, guid, print_func=None):
        tasks = []
        task_regex = re.compile(f"^.+ INFO guid={guid} .+ task=(.+)$")
        with FileReadBackwards(self.tasks_log_file(), encoding="utf-8") as frb:
            while True:
                l = frb.readline()
                if not l:
                    break
                
                task_match = task_regex.match(l)
                if task_match:
                    task_json = task_match.group(1)
                    try:
                        tasks.append(loads(task_json))
                    except Exception as e:
                        if print_func:
                            print_func("Error parsing task: {}".format(str(e)))
                elif tasks:
                    #no use in looking, we reached end of guid
                    break
        return tasks