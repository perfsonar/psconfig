'''
A client tracking and maintaining pscheduler tasks across multiple servers
'''

import os
import json
#check the imports
#from pscheduler.log import Log
import time
from ...utilities.iso8601 import duration_to_seconds
from .api_filters import ApiFilters
from .api_connect import ApiConnect
import datetime

class TaskManager(object):
    def __init__(self, **kwargs):
        self.existing_task_map = {}
        self.new_archives = {}
        self.duplicate_new_task_map = {}
        self.new_tasks = []
        self.deleted_tasks = []
        self.leads_to_keep = {}
        self.added_tasks = []
        #self.leads = {}
        
        #mandatory
        if not isinstance(kwargs.get('pscheduler_url'), str):
            raise TypeError("pscheduler_url must be string")
        self.pscheduler_url = kwargs['pscheduler_url']

        if not isinstance(kwargs.get('reference_label'), str):
            raise TypeError("reference_label must be string")
        self.reference_label = kwargs['reference_label']

        if not isinstance(kwargs.get('tracker_file'), str):
            raise TypeError("tracker_file must be string")
        self.tracker_file = kwargs['tracker_file']

        if not isinstance(kwargs.get('client_uuid_file'), str):
            raise TypeError("client_uuid_file must be string")
        self.client_uuid_file = kwargs['client_uuid_file']

        if not isinstance(kwargs.get('user_agent'), str):
            raise TypeError("user_agent must be string")
        self.user_agent = kwargs['user_agent']

        self.created_by = self._created_by()

        if not isinstance(kwargs.get('new_task_min_ttl'), int):
            raise TypeError("new_task_min_ttl must be integer")
        self.new_task_min_ttl = kwargs['new_task_min_ttl']

        if not isinstance(kwargs.get('new_task_min_runs'), int):
            raise TypeError("new_task_min_runs must be integer")
        self.new_task_min_runs = kwargs['new_task_min_runs']

        if not isinstance(kwargs.get('old_task_deadline'), int):
            raise TypeError("old_task_deadline must be integer")
        self.old_task_deadline = kwargs['old_task_deadline']

        #optional argument 
        if 'task_renewal_fudge_factor' in kwargs:
            if not isinstance(kwargs.get('task_renewal_fudge_factor'), float):  # Num to float?
                raise TypeError("task_renewal_fudge_factor must be float")
        self.task_renewal_fudge_factor = kwargs.get('task_renewal_fudge_factor', 0.0)

        #optional argument
        if 'debug' in kwargs:
            if not isinstance(kwargs.get('debug'), bool):
                raise TypeError("debug must be boolean")
        self.debug = kwargs.get('debug')
        
        self.errors = [] 
        
        #get list of leads
        self.tracker_file_json = self._read_json_file(self.tracker_file)
        self.leads = self.tracker_file_json.get('leads', {})
        self._update_lead(self.pscheduler_url, {})

        #get list of existing MAs
        self.existing_archives = self.tracker_file_json.get('archives', {})

        #build list of existing tasks
        """    $self->logf()->global_context({"action" => "list"}); """
        bind_map = kwargs.get('bind_map')

        ##
        # Note: I don't think we need lead_address_map here anymore, but may be wrong. Keep code for now
        # but may want to remove this to ease confusion in future.
        lead_address_map = kwargs.get('lead_address_map')

        visited_leads = {}
        for psc_url in self.leads:
            log_ctx = {'url': psc_url}
            '''$self->log_info("Getting task list from $psc_url", $log_ctx);'''
            #Query lead
            psc_lead = self.leads[psc_url] 
            existing_task_map = {}
            psc_filters = ApiFilters()
            psc_filters.detail_enabled(True)
            psc_filters.reference_param(self.reference_label, {'created-by': self.created_by})
            psc_client = ApiConnect(url=psc_url, filters=psc_filters,
                                    bind_map=bind_map, lead_address_map=lead_address_map)
            
            #get hostname to see if this is a server we already visited using a different address
            psc_hostname = psc_client.get_hostname()
            if psc_client.error:
                '''$self->log_error("Error getting hostname from $psc_url: " . $psc_client->error(), $log_ctx);'''
                psc_lead['error_time'] = int(time.time())
                self.errors.append("Problem retrieving host information from pScheduler lead {}: {}".format(psc_url, psc_client.error))
                continue
            elif not psc_hostname:
                '''$self->log_error("Error: $psc_url returned an empty hostname", $log_ctx );'''
                psc_lead['error_time'] = int(time.time())
                self.errors.append("Empty string returned from {}/hostname. It may not have its hostname configured correctly.".format(psc_url))
                continue
            elif visited_leads.get(psc_hostname):
                '''$self->log_debug("Already visited server at $psc_url using " . $visited_leads{$psc_hostname} . ", so skipping.", $log_ctx);'''
                continue
            else:
                visited_leads[psc_hostname] = psc_url

            #get tasks
            existing_tasks = psc_client.get_tasks()
            if existing_tasks and len(existing_tasks) > 0 and psc_client.error:
                    #there was an error getting an individual task
                    '''$self->log_error("Error fetching an individual task, but was able to get list: " .  $psc_client->error(), $log_ctx);'''
            elif psc_client.error:
                #there was an error getting the entire list
                '''$self->log_error("Error getting task list from $psc_url: " . $psc_client->error(), $log_ctx);'''
                psc_lead['error_time'] = int(time.time())
                self.errors.append("Problem getting existing tests from pScheduler lead {}: {}".format(psc_url, psc_client.error))
                continue
            #can get rid of this
            elif len(existing_tasks) == 0:
                #Todo: Drop this when 4.0 deprecated. fallback in case detail filter not supported (added in 4.0.2).
                '''$self->log_debug("Trying to get task list without enabled filter", $log_ctx);'''
                del psc_client.filters.taskfilters['detail'] 
                existing_tasks = psc_client.get_tasks() 
                if psc_client.error:
                    #there was an error getting the entire list
                    '''$self->log_error("Error getting task list from $psc_url: " . $psc_client->error(), $log_ctx);'''
                    psc_lead['error_time'] = int(time.time())
                    self.errors.append("Problem getting existing tests from pScheduler lead {}: {}".format(psc_url, psc_client.error))
                    continue
            
            #add to existing task map
            for existing_task in existing_tasks:
                if not existing_task.detail_enabled():  
                    continue
                self.log_task(existing_task)
                
                #make an array since could have more than one test with same checksum 
                if not self.existing_task_map.get(existing_task.checksum()):
                    self.existing_task_map[existing_task.checksum()] = {}
                
                if not self.existing_task_map.get(existing_task.checksum()).get(existing_task.tool()):
                    self.existing_task_map[existing_task.checksum()][existing_task.tool()] = {}
                
                self.existing_task_map[existing_task.checksum()][existing_task.tool()][existing_task.uuid] = {
                    'task': existing_task,
                    'keep': False
                }


    def add_task(self, **kwargs):
        '''$self->logf()->global_context({"action" => "add_to_manager"});'''
        #mandatory
        try:
            new_task = kwargs['task']
        except KeyError:
            pass
        
        local_address = kwargs.get('local_address')
        #Note: we can get rid of this as a parameter when we drop MeshConfig libs from toolkit GUI
        repeat_seconds = kwargs.get('repeat_seconds')

        if (not repeat_seconds) and (new_task.schedule_repeat()):
            try:
                repeat_seconds = duration_to_seconds(new_task.schedule_repeat())  
            except Exception:
                #Ignore if can't convert
                pass

        #set reference params
        ##need to copy this so different addresses don't break checksum
        tmp_created_by = {}
        if local_address:
            tmp_created_by['address'] = local_address
        for cp in self.created_by:
            tmp_created_by[cp] = self.created_by[cp]
        
        new_task.reference_param(self.reference_label, {'created-by': tmp_created_by})

        #determine if we need new task and create
        need_new_task, new_task_start = self._need_new_task(new_task)
        if need_new_task:
            self.duplicate_new_task_map[new_task.checksum()] = True
            #task does not exist, we need to create it
            new_task.schedule_start(self._ts_to_iso(new_task_start))
            #set end time to greater of min repeats and expiration time
            min_repeat_time = 0
            if repeat_seconds:
                # a bit hacky, but trying to convert an ISO duration to seconds is both imprecise
                # and expensive so just use given value since these generally start out as
                # seconds anyways.
                min_repeat_time = repeat_seconds * self.new_task_min_runs
            
            #use new start time if exists, otherwise start with current time
            if new_task_start:
                new_until = new_task_start
            else:
                new_until = int(time.time())
            
            if (min_repeat_time > self.new_task_min_ttl):
                #if the minimum number of repeats is longer than the min ttl, use the greater value
                new_until += min_repeat_time
            else:
                #just add the minimum ttl
                new_until += self.new_task_min_ttl
            
            new_task.schedule_until(self._ts_to_iso(new_until))
            print(new_task.data)
            self.new_tasks.append(new_task)
    

    def commit(self):

        self.errors = []
        self._delete_tasks()
        self._create_tasks()
        self._cleanup_leads()
        self._write_tracker_file()


    def check_assist_server(self):
        '''$self->logf()->global_context({"action" => "check_assist_server", "url" =>  $self->pscheduler_url()});'''

        psc_client = ApiConnect(url=self.pscheduler_url)
        psc_client.get_test_urls()
        if psc_client.error:
            '''$self->log_error("Error checking assist server: " . $psc_client->error());'''
            return False
        else:
            return True


    def _delete_tasks(self):
        '''$self->logf()->global_context({"action" => "delete"});'''

        cached_lead = None
        cached_bind = None

        #clear out previous deleted tasks
        self.deleted_tasks = []

        '''$self->log_info("Deleting tasks");'''
        found_task_to_delete = False
        
        for checksum in self.existing_task_map:
            cmap = self.existing_task_map[checksum]

            for tool in cmap:
                tmap = cmap[tool]

                for uuid in tmap:
                    #prep task
                    meta_task = tmap[uuid]
                    task = meta_task['task']
                    #optimization so don't lookup lead for same params
                    if cached_lead:
                        task.url = cached_lead
                        if cached_bind:
                            task.bind_address = cached_bind 
                    else:
                        cached_lead = task.refresh_lead()
                        cached_bind = task.bind_address 
                    
                    if task.error:
                        err = "Problem determining which pscheduler to submit test to for deletion, skipping test {}: {}".format(task.to_str(), task.error)
                        '''
                        $self->log_error($err);
                        '''
                        self.errors.append(err)
                        continue

                    #if we keep, make sure we track lead, otherwise delete
                    if meta_task.get('keep'):
                        #make sure we keep the lead around
                        self.leads_to_keep[task.url] = True
                    else:
                        '''$self->log_task($task);'''
                        found_task_to_delete = True
                        task.delete_task()
                        if task.error:
                            self.leads_to_keep[task.url] = True
                            self._update_lead(task.url, {'error_time': int(time.time())})
                            err = "Problem deleting test {}, continuing with rest of config: {}".format(task.to_str(), task.error)
                            '''$self->log_error($err);'''
                            self.errors.append(err)
                        else:
                            self.deleted_tasks.append(task)
                    
        if not found_task_to_delete:
            '''$self->log_info("No tasks marked for deletion") unless($found_task_to_delete);'''
            pass
        '''$self->log_info("Done deleting tasks");'''


    def _need_new_task(self, new_task):
        existing = self.existing_task_map

        #If we use one of bind address maps, we have to refresh the lead here or else the
        #checksum will be wrong. If we don't specify then don't worry about it as its a
        #perfomance hit
        if new_task.needs_bind_addresses():
            new_task.refresh_lead() 

        #calculate the checksum once
        new_task_checksum = new_task.checksum()

        #if we already have this task in the queue to be created, such as when it
        #is specified in multiple meshes, then we don't want to add it again
        if self.duplicate_new_task_map.get(new_task_checksum):
            return False, None
        
        #if private ma params change, then need new task
        #also update new_archives here so we don't have to re-calculate all the checksums
        #Note: Don't worry about removed archives since task checksum has that covered
        ma_changed = False  
        for archive in new_task.archives():
            opaque_new_checksum = archive.checksum()
            #Key combines task and archive checksum since multiple tasks may have archive sthat only differ between opaque parts
            #Likewise, within a task we may have archives that only differ by private fields
            archive_key = new_task_checksum + '__' + opaque_new_checksum
            old_checksum = self.existing_archives.get(archive_key)
            new_checksum = archive.checksum(include_private=True)
            if not self.new_archives.get(archive_key):
                self.new_archives[archive_key] = {}
            self.new_archives[archive_key][new_checksum] = True
            if not (old_checksum and old_checksum.get(new_checksum)):
                '''$self->log_info("MA changed for $archive_key -> $new_checksum");'''
                ma_changed = True
        
        #if no matching checksum, then does not exist
        if ma_changed or not existing.get(new_task_checksum):
            return True, None
        
        #if matching checksum, and tool is not defined on new task then we match
        need_new_task = True
        new_start_time = None  
        if not new_task.requested_tools():
            cmap = existing.get(new_task_checksum)   
            for tool in cmap:
                need_new_task, new_start_time = self._evaluate_task(cmap[tool], need_new_task, new_start_time)
        else:
            #we have a matching checksum and we have an explicit tool, find one that matches
            cmap = existing.get(new_task_checksum)
            #search requested tools in order since that is preference order
            for req_tool in new_task.requested_tools():
                if cmap.get(req_tool):
                    need_new_task, new_start_time = self._evaluate_task(cmap[req_tool], need_new_task, new_start_time)
        
        return need_new_task, new_start_time
    

    def _evaluate_task(self, tmap, need_new_task, new_start_time):
        current_time = int(time.time())

        for uuid in tmap:
            old_task = tmap[uuid]
            old_task['keep'] = True 
            until_ts = self._iso_to_ts(old_task['task'].schedule_until())

            if need_new_task:

                #if detail has start use that, otherwise use added time
                if old_task['task'].detail_start():
                    old_task_start_iso = old_task['task'].detail_start()
                else:
                    old_task_start_iso = old_task['task'].detail_added()
                old_task_start_ts = self._iso_to_ts(old_task_start_iso)

                if ((not old_task['task'].detail_exclusive()) #not exclusive
                    and old_task['task'].detail_multiresult() #is multi-result
                    and (old_task_start_ts + 15*60) < int(time.time()) #started at least 15 min ago
                    and (
                        (old_task['task'].detail_runs_started() is not None and  (old_task['task'].detail_runs_started()== 0)) #have at no runs started (v1.1 and later)
                        or (old_task['task'].detail_runs_started() is not None and (old_task['task'].detail_runs() <= 2)) #have less than two runs (not 1 because count bugged) (pre-v1.1)
                        )):

                        #if background-multi, one or less runs and start time is 15 minutes (arbitrary)
                        # in the past the start time is immediately. Fixes special cases where bgm
                        # task first run is not scheduled and this no tests run
                        '''
                        $self->log_info("Stuck background-multi task found (start=$old_task_start_iso: $uuid, runs=1). Will cancel and recreate.");
                        '''
                        old_task['keep'] = False
                        new_start_time = int(time.time())
                elif ((not until_ts) or (until_ts > (self.old_task_deadline + (self.new_task_min_ttl * self.task_renewal_fudge_factor)))):
                    #if old task has no end time or will not expire before deadline, no task needed
                    need_new_task = False
                    #continue with loop since need to mark other tasks that might be older as keep
                elif ((until_ts > current_time) and ((not new_start_time) or (new_start_time < until_ts))):
                    #if until_ts is in the future or found a task that runs longer than one we already saw, set the start time
                    new_start_time = until_ts

        return need_new_task, new_start_time

    
    def _create_tasks(self):
        '''$self->logf()->global_context({"action" => "create"});'''

        #clear out previous added tasks
        self.added_tasks = []

        '''$self->log_info("Creating tasks");'''

        if not self.new_tasks:
            '''$self->log_info("No tasks to create")'''
        
        for new_task in self.new_tasks:
            #determine lead - do here as optimization so we only do it for tests that need to be added
            new_task.refresh_lead()
            if new_task.error:
                err = "Problem determining which pscheduler to submit test to for creation, skipping test {}: {}".format(new_task.to_str(), new_task.error)
                '''$self->log_error($err);'''

                self.errors.append(err)
                continue
            
            self.leads_to_keep[new_task.url] = True
            '''$self->log_task($new_task);'''

            new_task.post_task()

            if new_task.error:
                err = "Problem adding test {}, continuing with rest of config: {}".format(new_task.to_str(), new_task.error)
                '''$self->log_error($err);'''

                self.errors.append(err)
            else:
                self.added_tasks.append(new_task)
                self._update_lead(new_task.url, {'success_time': int(time.time())})
        
        '''$self->log_info("Done creating tasks");'''


    def _write_tracker_file(self):
        content = {
            'leads': self.leads,
            'archives': self.new_archives
        }

        try:
            print(content)
            with open(self.tracker_file, 'w') as outfile:
                json.dump(content, outfile, indent=2) 
        except Exception as e:
            self.errors.append(e)

    def _cleanup_leads(self):

        #clean out leads that we don't need anymore
        del_lead_urls = []
        for lead_url in self.leads:
            if not self.leads_to_keep.get(lead_url):
                del_lead_urls.append(lead_url)
        
        for lead_url in del_lead_urls:
            del self.leads[lead_url]

    def log_task(self, task):

        local_ctx = {}
        local_ctx['checksum'] = task.checksum()
        local_ctx['lead_url'] = task.url
        if task.lead_bind():
            local_ctx['lead_bind'] = task.lead_bind()
        local_ctx['test_type'] = task.test_type()

        '''
            if($self->logger()){
            $self->logger()->info($self->logf()->format_task($task, $local_ctx));
            }elsif($self->debug()){
                print $task->json({'pretty' => 1}) . "\n";
            }
        '''
    
    def _created_by(self):
        client_uuid = self._get_client_uuid() 
        if not client_uuid:
            client_uuid = self._set_client_uuid() 
        
        return {'uuid': client_uuid, 'user-agent': self.user_agent}

    
    def _get_client_uuid(self):
        '''
        Returns the UUID to use in the client-uuid field from a file
        '''
        uuid = ''
        if os.path.isfile(self.client_uuid_file):
            with open(self.client_uuid_file, 'r') as file:
                for line in file:
                    uuid = line.rstrip('\n') 
                    if uuid:
                        break
        return uuid
    
    
    def _set_client_uuid(self):
        '''
        Generates a uuid and stores in a file
        '''
        uuid_file = self.client_uuid_file
        uuid = str(uuid.uuid4()).upper()
        with open(uuid_file, 'w') as file:
            file.write(uuid)
        return uuid
            

    def _update_lead(self, url, fields):
        if not self.leads.get(url):
            self.leads[url] = {}
        for field in fields:
            self.leads[url][field] = fields[field]

    def _read_json_file(self, json_file):

        json_data = {}
        
        if os.path.isfile(json_file):
            try:
                with open(json_file) as jsonfile:
                    json_data = json.load(jsonfile) 
            except Exception as e:
                pass
            
        return json_data


    def _iso_to_ts(self, iso_str):
        if not iso_str:
            return

        #ensure no microseconds for strptime to work
        dt = datetime.datetime.strptime(iso_str, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc)
        return dt.timestamp()
        

    def _ts_to_iso(self, ts):
        if not ts:
            return
        
        #remove micro seconds
        return datetime.datetime.utcfromtimestamp(ts).replace(microsecond=0).isoformat() + 'Z'
