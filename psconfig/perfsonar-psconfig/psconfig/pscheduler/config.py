from ..remote import Remote
from .schema import Schema
from ..client.psconfig.base_node import BaseNode
from jsonschema import validate as jsonvalidate

class Config(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.error = ''
    
    def remotes(self, val=None):
        '''Sets/gets list of Remote objects'''
        return self._field_class_list('remotes', Remote, val)
    
    def remote(self, index, val=None):
        '''Sets/gets Remote object at given index'''
        return self._field_class_list_item('remotes', index, Remote, val)
    
    def add_remote(self, val=None):
        '''Adds Remote object to remotes list'''
        self._add_field_class('remotes', Remote, val)
    
    def pscheduler_assist_server(self, val=None):
        '''Sets/gets the pscheduler-assist-server field as a host with optional port in form HOST:PORT'''
        return self._field_urlhostport('pscheduler-assist-server', val)
    
    def pscheduler_bind_map(self, val=None):
        '''Sets/gets HasRef used in binding to pscheduler servers. The key is the remote host and the
            value is the local address to use for binding'''
        return self._field_anyobj('pscheduler-bind-map', val)
    
    def pscheduler_fail_attempts(self, val=None):
        '''The number of times to try to connect to pscheduler assist server before giving up'''
        return self._field_cardinal('pscheduler-fail-attempts', val)
    
    def match_addresses(self, val=None):
        '''Sets/gets list of addresses (as strings) for which the agent is responsible for creating tests'''
        self._field_host_list('match-addresses', val)
    
    def match_address(self, index, val=None):
        '''Sets/gets an addresses (as string) at the given index'''
        return self._field_host_list_item('match-addresses', index, val)
    
    def add_match_address(self, val=None):
        '''Adds a match address to the list of match-addresses'''
        return self._add_field_host('match-addresses', val)
    
    def include_directory(self, val=None):
        '''Gets/sets the directory where local configuration files live'''
        return self._field('include-directory', val)
    
    def archive_directory(self, val=None):
        '''Gets/sets the directory where local archiver definitions live'''
        return self._field('archive-directory', val)
    
    def transform_directory(self, val=None):
        '''Gets/sets the directory where local transform scripts live'''
        return self._field('transform-directory', val)
    
    def requesting_agent_file(self, val=None):
        '''Gets/sets the location of a file with the requesting agent definition'''
        return self._field('requesting-agent-file', val)
    
    def client_uuid_file(self, val=None):
        '''Gets/sets the location of a the file containing the UUID used by this agent'''
        return self._field('client-uuid-file', val)
    
    def pscheduler_tracker_file(self, val=None):
        '''Gets/sets the location of the file used to track previously talked to pscheduler servers'''
        return self._field('pscheduler-tracker-file', val)
    
    def check_interval(self, val=None):
        '''Gets/sets how often to check for changes to remote configuation files. Formatted as IS8601
        duration.'''
        return self._field_duration('check-interval', val)
    
    def check_config_interval(self, val=None):
        '''Gets/sets how often to check for changes to local configuation files. Formatted as IS8601
        duration.'''
        return self._field_duration('check-config-interval', val)
    
    def task_min_ttl(self, val=None):
        '''The minimum amount of time before a created task expires. Formatted as IS8601
        duration.'''
        return self._field_duration('task-min-ttl', val)
    
    def task_min_runs(self, val=None):
        '''The minimum number of runs that must be scheduled for a task.'''
        return self._field_cardinal('task-min-runs', val)
    
    def task_renewal_fudge_factor(self, val=None):
        '''The percentage of time before expiration to renew a task.'''
        return self._field_probability('task-renewal-fudge-factor', val)
    
    def disable_cache(self, val=None):
        '''Gets/sets whether templates should be cached'''
        return self._field_bool('disable-cache', val)
    
    def cache_directory(self, val=None):
        '''Gets/sets the directory where cached templates live'''
        return self._field('cache-directory', val)
    
    def cache_expires(self, val=None):
        '''Gets/sets how long to keep templates cached'''
        return self._field_duration('cache-expires', val)
    
    def validate(self):
        '''Validates this object against JSON schema. Returns error messages of a 0 length array if valid'''
        schema = self.schema()
        try:
            validator = jsonvalidate(instance=self.data, schema=schema)
            return []
        except Exception as e:
            return [e]
        
    def schema(self):
        '''Returns the JSON schema for this config'''
        return Schema().psconfig_pscheduler_json_schema()
