
from .base_node import BaseNode
from ..utils import Utils, build_err_msg, extract_url_uuid
from .archive import Archive
from .run import Run
from hashlib import md5
from base64 import b64encode
from ipaddress import ip_address, IPv6Address
from urllib.parse import urlparse, urlunparse
import json
import copy

class Task(BaseNode):
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.bind_map = kwargs.get('bind_map', {}) #host interface
        self.lead_bind_map = kwargs.get('lead_bind_map', {})
        self.lead_address_map = kwargs.get('lead_address_map', {}) #host
        self.error = ''
        
    def _post_url(self):
        tasks_url = self.url
        tasks_url = tasks_url.strip()
        if not tasks_url.endswith('/'):
            tasks_url += '/'
        tasks_url += 'tasks'
        return tasks_url
    
    def schema(self, val=None):
        if val is not None:
            self.data['schema'] = val
        
        return self.data.get('schema', None)
    
    def priority(self, val=None):
        if val is not None:
            self.data['priority'] = val
        
        return self.data.get('priority', None)
    
    def test_type(self, val=None):
        if val is not None:
            self._init_field(self.data, 'test')
            self.data['test']['type'] = val
        
        try:
            return self.data['test']['type']
        except KeyError:
            return None
    
    def test_spec(self, val=None):
        if val is not None:
            self._init_field(self.data, 'test')
            self.data['test']['spec'] = val
        
        try:
            return self.data['test']['spec']
        except KeyError:
            return None
    
    #get when field is not None and val is None. set when both not None
    def test_spec_param(self, field=None, val=None):
        if field is None:
            return None
        
        if val is not None:
            self._init_field(self.data, 'test')
            self._init_field(self.data['test'], 'spec')
            self.data['test']['spec'][field] = val
        
        try:
            return self.data['test']['spec'][field]
        except KeyError:
            return None
    
    def tool(self, val=None):
        if val is not None:
            self.data['tool'] = val
        
        return self.data.get('tool', None)
    
    def lead_bind(self, val=None):
        if val is not None:
            self.data['lead_bind'] = val
        return self.data.get('lead_bind', None)
    
    def reference(self, val=None):
        if val is not None:
            self.data['reference'] = val
        return self.data.get('reference', None)

    def contexts(self, val=None):
        if val is not None:
            self.data['contexts'] = val
        return self.data.get('contexts', None)
    
    #get when field is not None and val is None. set when both not None
    def reference_param(self, field=None, val=None):
        if field is None:
            return None
        
        if val is not None:
            self._init_field(self.data, 'reference')
            self.data['reference'][field] = val
        
        try:
            return self.data['reference'][field]
        except KeyError:
            return None
    
    def schedule(self, val=None):
        if val is not None:
            self.data['schedule'] = val
        return self.data.get('schedule', None)
    
    def schedule_maxruns(self, val=None):
        if val is not None:
            self._init_field(self.data, 'schedule')
            self.data['schedule']['max-runs'] = val
        
        try:
            return self.data['schedule']['max-runs']
        except KeyError:
            return None
    
    def schedule_repeat(self, val=None):
        if val is not None:
            self._init_field(self.data, 'schedule')
            self.data['schedule']['repeat'] = val
        
        try:
            return self.data['schedule']['repeat']
        except KeyError:
            return None
    
    def schedule_sliprand(self, val=None):
        if val is not None:
            self._init_field(self.data, 'schedule')
            if val:
                self.data['schedule']['sliprand'] = True
            else:
                self.data['schedule']['sliprand'] = False
        try:
            return self.data['schedule']['sliprand']
        except KeyError:
            return None

    
    def schedule_slip(self, val=None):
        if val is not None:
            self._init_field(self.data, 'schedule')
            self.data['schedule']['slip'] = val
        
        try:
            return self.data['schedule']['slip']
        except KeyError:
            return None
    
    def schedule_start(self, val=None):
        if val is not None:
            self._init_field(self.data, 'schedule')
            self.data['schedule']['start'] = val
        try:
            return self.data['schedule']['start']
        except KeyError:
            return None
    
    def schedule_until(self, val=None):
        if val is not None:
            self._init_field(self.data, 'schedule')
            self.data['schedule']['until'] = val
        try:
            return self.data['schedule']['until']
        except KeyError:
            return None
    
    def detail(self, val=None):
        if val is not None:
            self.data['detail'] = val
        return self.data.get('detail', None)
    
    def detail_enabled(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            if val:
                self.data['detail']['enabled'] = True
            else:
                self.data['detail']['enabled'] = False
        
        try:
            return self.data['detail']['enabled']
        except KeyError:
            return None
    
    def detail_start(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            self.data['detail']['start'] = val
        
        try:
            return self.data['detail']['start']
        except KeyError:
            return None
    
    def detail_runs(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            self.data['detail']['runs'] = val
        try:
            return self.data['detail']['runs']
        except KeyError:
            return None

    def detail_runs_started(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            self.data['detail']['runs-started'] = val
        
        try:
            return self.data['detail']['runs-started']
        except KeyError:
            return None
    
    def detail_added(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            self.data['detail']['added'] = val
        try:
            return self.data['detail']['added']
        except KeyError:
            return None
    
    def detail_slip(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            self.data['detail']['slip'] = val
        try:
            return self.data['detail']['slip']
        except KeyError:
            return None
    
    def detail_duration(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            self.data['detail']['duration'] = val
        try:
            return self.data['detail']['duration']
        except KeyError:
            return None
    
    def detail_participants(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            self.data['detail']['participants'] = val
        
        try:
            return self.data['detail']['participants']
        except KeyError:
            return None

    def detail_exclusive(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            if val:
                self.data['detail']['exclusive'] = True
            else:
                self.data['detail']['exclusive'] = False
        
        try:
            return self.data['detail']['exclusive']
        except KeyError:
            return None

    def detail_multiresult(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            if val:
                self.data['detail']['multi-result'] = True
            else:
                self.data['detail']['multi-result'] = False
        try:
            return self.data['detail']['multi-result']
        except KeyError:
            return None
    
    def detail_anytime(self, val=None):
        if val is not None:
            self._init_field(self.data, 'detail')
            if val:
                self.data['detail']['anytime'] = True
            else:
                self.data['detail']['anytime'] = False
        try:
            return self.data['detail']['anytime']
        except KeyError:
            return None
    
    def archives(self, val=None):
        if val is not None:
            self.data['archives'] = []
            for v in val:
                tmp_archive = {
                    'archiver': v.name, 
                    'data': v.data
                }
                if v.ttl is not None:
                    tmp_archive['ttl'] = v.ttl
                self.data['archives'].append(tmp_archive)
        
        archives = []
        for archive in self.data['archives']:
            tmp_archive_obj = Archive(
                name=archive['archiver'],
                data=archive['data']
                )
            if 'ttl' in archive:
                tmp_archive_obj.ttl = archive['ttl']
            archives.append(tmp_archive_obj)
        
        return archives
    
    def add_archive(self, val=None):
        if val is None:
            return
        self.data['archives'] = self.data.get('archives', [])

        tmp_archive = {
            'archiver': val.name, 
            'data': val.data
        }

        if val.ttl is not None:
            tmp_archive['ttl'] = val.ttl
        self.data['archives'].append(tmp_archive)
    
    def requested_tools(self, val=None):
        if val is not None:
            self.data['tools'] = val
        return self.data.get('tools', None)
    
    def add_requested_tool(self, val=None):
        if val is None:
            return
        
        self.data['tools'] = self.data.get('tools', None)
        self.data['tools'].append(val)
    
    def add_bind_map(self, target=None, bind=None):
        if target is None or bind is None:
            return
        self.bind_map[target] = bind
    
    def add_lead_bind_map(self, target=None, bind=None):
        if target is None or bind is None:
            return
        self.lead_bind_map['target'] = bind
    
    def add_lead_address_map(self, target=None, addr=None):
        if target is None or addr is None:
            return
        self.lead_address_map[target] = addr
    
    def add_local_bind_map(self, bind):
        if bind is None:
            return
        self.bind_map['_default'] = bind
    
    def add_local_lead_bind_map(self, bind=None):
        if bind is None:
            return
        self.lead_bind_map['_default'] = bind
    

    def post_task(self):
        
        if self.schema() is None:
            if self.priority() is None:
                #priority introduced in v3
                self.schema(3)
            elif self.contexts(): 
                #contexts introduced in version 3
                self.schema(2)
            else:
                self.schema(1)
        
        self._init_field(self.data, 'schedule')
        self._init_field(self.data, 'test')
        self._init_field(self.data['test'], 'spec')
        self.data['test']['spec']['schema'] = self.data['test']['spec'].get('schema', 1)

        #send request
        content = self._post(self.data)
        if self.error:
            return -1 
        if not content:
            self.error = "No task url returned by POST"
            return -1
        
        task_uuid = extract_url_uuid(url=content)
        if task_uuid:
            self.uuid = task_uuid
        else:
            self.error = "Unable to determine UUID"
            return -1

        return 0
    
    def delete_task(self):

        #send request
        content = self._delete()
        if self.error:
            return -1
        return 0
    
    def runs(self):

        #build url
        runs_url = self.url
        runs_url = runs_url.strip()

        if not runs_url.endswith('/'):
            runs_url += '/'
        
        runs_url = runs_url + "tasks/" + self.uuid + "/runs"

        filters = {}
        response = Utils().send_http_request(
            connection_type='GET',
            url=runs_url,
            timeout=self.filters.timeout,
            ca_certificate_file=self.filters.ca_certificate_file,
            ca_certificate_path=self.filters.ca_certificate_path,
            verify_hostname=self.filters.verify_hostname,
            local_address=self.bind_address
        )

        if not response.ok:
            self.error = build_err_msg(http_response=response)
            return
        
        response_json = response.json()

        if not response_json:
            self.error = "No run objects returned"
            return
        
        if not isinstance(response_json, list):
            self.error = "Runs must be an array. Not {}".format(type(response_json))
            return
        
        runs = []
        for run_url in response_json:
            run_uuid = extract_url_uuid(url=run_url)
            if not run_uuid:
                self.error = "Unable to extract name from url {}".format(run_url)
                return
            run = self.get_run(run_uuid)
            if not run:
                #There was an error
                return 
            runs.append(run)
        return runs

    def run_uuids(self):

        #build url
        runs_url = self.url
        runs_url = runs_url.strip()

        if not runs_url.endswith('/'):
            runs_url += '/'

        runs_url = runs_url + "tasks/" + self.uuid + "/runs"

        filters = {}
        response = Utils().send_http_request(
            connection_type='GET',
            url=runs_url,
            timeout=self.filters.timeout,
            ca_certificate_file=self.filters.ca_certificate_file,
            ca_certificate_path=self.filters.ca_certificate_path,
            verify_hostname=self.filters.verify_hostname,
            local_address=self.bind_address
        )

        if not response.ok:
            self.error = build_err_msg(http_response=response)
            return
        
        response_json = response.json()
        if not response_json:
            self.error = "No run objects returned"
            return

        if not isinstance(response_json, list):
            self.error = "Runs must be a list. Not {}".format(type(response_json))
            return
        
        runs = []
        for run_url in response_json:
            run_uuid = extract_url_uuid(url=run_url)
            if not run_uuid:
                self.error = "Unable to extract name from url {}".format(run_url)
                return
            runs.append(run_uuid)
        
        return runs
    
    def get_run(self, run_uuid):
        #build url
        run_url = self.url
        run_url = run_url.strip()

        if not run_url.endswith('/'):
            run_url += '/'
        
        run_url = run_url + "tasks/" + self.uuid + "/runs/{}".format(run_uuid)

        #fetch tool
        run_response = Utils().send_http_request(
            connection_type='GET',
            url=run_url,
            timeout=self.filters.timeout,
            ca_certificate_file=self.filters.ca_certificate_file,
            ca_certificate_path=self.filters.ca_certificate_path,
            verify_hostname=self.filters.verify_hostname,
            local_address=self.bind_address
        )

        if not run_response.ok:
            self.error = build_err_msg(http_response=run_response)
            return
        
        run_response_json = run_response.json()
        if not run_response_json:
            self.error = "No run object returned from {}".format(run_url)
            return
        
        return Run(
            data=run_response_json,
            url=run_url,
            filters=self.filters,
            uuid=run_uuid
        )

    def get_lead(self):

        #need a test_type and test_spec for this to work
        if not (self.test_type() and self.test_spec()):
            return
        
        #do any address based mappings here
        participants_lead_bind = ""

        if self.url:
            url_obj = urlparse(self.url)
            lead = url_obj.hostname
            #map url to a specific public address if needed
            if self.lead_address_map.get(lead) is not None:
                url_obj = url_obj._replace(netloc=url_obj.netloc.replace(url_obj.hostname, self.lead_address_map[lead]))
                self.url = urlunparse(url_obj)
                lead = self.lead_address_map[lead] # urlparse(self.url).hostname
            #init bindings if we haven't already done so
            if self.needs_bind_addresses():
                #set bind map
                if self.bind_map.get(lead) is not None: 
                    self.bind_address = self.bind_map[lead]
                elif self.bind_map.get('_default') is not None:
                    if not (ip_address(lead).is_loopback or lead.startswith('localhost')):
                        self.bind_address = self.bind_map['_default']
                
                #set participants lead
                if self.lead_bind_map.get(lead) is not None:
                    participants_lead_bind = self.lead_bind_map[lead]
                elif self.lead_bind_map.get('_default') is not None:
                    #Only do this if url points to local pscheduler - may cause problems if default assist server in .conf is remote
                    if (ip_address(lead).is_loopback or lead.startswith('localhost')):
                        participants_lead_bind = self.lead_bind_map['_default']
                
            elif self.lead_bind():
                #if lead_bind is already set, give it to participants
                participants_lead_bind = self.lead_bind()
            
            #map the url to a specific public address if needed -- not needed!?
        
        #build url
        lead_url = self.url
        lead_url = lead_url.strip()
        if not lead_url.endswith('/'):
            lead_url += '/'
        lead_url = lead_url + "tests/" + self.test_type() + "/participants"

        #fetch lead
        if not self.data['test']['spec'].get('schema'): 
            self.data['test']['spec']['schema'] = 1
        get_params = {'spec':self.test_spec()}
        if participants_lead_bind:
            get_params['lead-bind'] = participants_lead_bind
        
        lead_response = Utils().send_http_request(
            connection_type='GET',
            url=lead_url,
            get_params=get_params,
            timeout=self.filters.timeout,
            ca_certificate_file=self.filters.ca_certificate_file,
            ca_certificate_path=self.filters.ca_certificate_path,
            verify_hostname=self.filters.verify_hostname,
            local_address=self.bind_address
        )
        if not lead_response.ok:
            self.error = build_err_msg(http_response=lead_response)
            return
        
        lead_response_json = {}
        try:
            lead_response_json = lead_response.json()
        except Exception as e:
            self.error = "Error parsing lead object returned from {}: {}".format(lead_url, e)
            return
        
        if not lead_response_json.get('participants'):
            self.error = "Error parsing lead object returned from {}: No participant list returned".format(lead_url)
            return
        
        if not len(lead_response_json.get('participants')) > 0:
            self.error = "Error parsing lead object returned from {}: No participants provided in the returned list".format(lead_url)
            return

        lead = lead_response_json['participants'][0]

        #switch to public address if mapping exists
        if lead and self.lead_address_map.get(lead):
            lead = self.lead_address_map[lead]
        
        #set bind address if we have a bind map populated
        if lead and self.bind_map and self.bind_map.get(lead):
            self.bind_address = self.bind_map[lead]
        elif self.bind_map and self.bind_map.get('_default'):
            self.bind_address = self.self.bind_map['_default']

        #set lead bind address if we have map set - only set it if we are local (first participant None) or explicitly call out the address
        if lead and self.lead_bind_map and self.lead_bind_map.get(lead):
            self.lead_bind = self.lead_bind_map[lead]
        elif self.lead_bind_map and self.lead_bind_map.get('_default'):
            self.lead_bind = self.lead_bind_map['_default']
        
        return lead
    
    def get_lead_url(self, scheme='https', port='', path='/pscheduler'):

        if port:
            port = ":" + port
        if not path.startswith('/'):
            path = '/' + path
        
        #get address
        address = self.get_lead()
        if not address:
            return
        
        #bracket ipv6
        if type(ip_address(address)) is IPv6Address:
            address = "[{}]".format(address)
        
        return "{}://{}{}{}".format(scheme, address, port, path)
    
    def refresh_lead(self, scheme='https', port='', path='/pscheduler'):
        lead = self.get_lead_url(scheme, port, path) 
        if lead:
            #if lead exists, change url, otherwise keep the same
            self.url = lead
        return lead
    
    def needs_bind_addresses(self):
        if self.bind_map and not self.bind_address: 
            return True
        if self.lead_bind_map and not self.lead_bind():
            return True
        return False

    def checksum(self):
        #calculates checksum for comparing tasks, ignoring stuff like UUID and lead url
        #make sure these fields are consistent
        self.data['archives'] = self.data.get('archives', [])
        self.data['schedule'] = self.data.get('schedule', {})

        data_copy = copy.deepcopy(self.data)
        data_copy['schema'] = '' #clear out this since if other params same then should be equal
        data_copy['test']['spec']['schema'] = '' #clear out this since if other params same then should be equal
        data_copy['tool'] = '' #clear out tool since set by server
        data_copy['href'] = '' #clear out href
        data_copy['schedule']['start'] = '' #clear out temporal values
        data_copy['schedule']['until'] = '' #clear out temporal values
        data_copy['detail'] = {} #clear out detail

        #clear our private fields that won't get displayed by remote tasks
        for archive in data_copy['archives']:
            for datum in archive['data'].keys():
                if datum.startswith('_'):
                    archive['data'][datum] = ''
        
        for tparam in data_copy['test']['spec']:
            if tparam.startswith('_'):
                data_copy['test']['spec'][tparam] = ''

        #canonical should keep it consistent by sorting keys
        data_copy_canonical = json.dumps(data_copy, sort_keys=True, separators=(',',':')).encode('utf-8')
        return b64encode(md5(data_copy_canonical).digest()).decode().rstrip('=')
    
    def to_str(self): #use __str__?
        string = self.test_type()
        tool = self.tool()
        if tool:
            string = string + '/' + tool
        if self.test_spec_param("source") or self.test_spec_param("dest") or self.test_spec_param("destination"):
            string += '('
            string += self.test_spec_param("source") if self.test_spec_param("source") else 'self'
            if self.test_spec_param("dest"):
                string += "->" + self.test_spec_param("dest")
            elif self.test_spec_param("destination"):
                string += "->" + self.test_spec_param("destination")
            string += ')'
        
        return string
