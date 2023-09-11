'''A library for generating a list of tasks represented by a PSConfig. Iterates through
each task in a Config object and organizes into a list of tasks.'''

from ..config import Config
from .template import Template
from ...pscheduler.task import Task
from ...pscheduler.api_connect import ApiConnect
import re
import json
'''

my $logger;
if(Log::Log4perl->initialized()) {
    #this is intended to be a lib reliant on someone else initializing env
    #detect if they did but quietly move on if not
    #anything using $logger will need to check if defined
    $logger = get_logger(__PACKAGE__);
}

'''

class TaskGenerator(object):

    def __init__(self, **kwargs) -> None:
        self.task_name = kwargs.get('task_name', '')
        self.psconfig = kwargs.get('psconfig', Config())
        self.match_addresses = kwargs.get('match_addresses', [])
        self.pscheduler_url = kwargs.get('pscheduler_url', '')
        self.default_archives = kwargs.get('default_archives', [])
        self.use_psconfig_archives = kwargs.get('use_psconfig_archives', True)
        self.bind_map = kwargs.get('bind_map', {})

        self.error = ''

        ##Updated on call to start()
        self.started = None #boolean flag
        self.task = None
        self.group = None
        self.schedule = None
        self.tools = None
        self.priority = None
        self.test = None
        ##Updated each call to next()
        self.expanded_test = None
        self.expanded_archives = None
        self.expanded_contexts = None
        self.expanded_reference = None
        self.scheduled_by_address = None
        self.addresses = None

        #private
        self._match_addresses_map = None

    def start(self):
        '''Prepares generator to begin iterating through tasks. Must be run before any call to next()'''
        #handle required properties without defaults
        if not self.task_name:
            self.error = 'TaskGenerator must be given a task_name property'
            return

        #find task
        task = self.psconfig.task(self.task_name)

        if task:
            self.task = task
        else:
            self.error = 'Unable to find a task with name {}'.format(self.task_name)
            return
        
        #find group
        group = self.psconfig.group(task.group_ref())
        if group:
            self.group = group
        else:
            self.error = 'Unable to find a group with name {}'.format(task.group_ref())
            return
        
        #find test
        test = self.psconfig.test(task.test_ref())
        if test:
            self.test = test
        else:
            self.error = 'Unable to find a test with name {}'.format(task.test_ref())
        

        #find schedule (optional)
        schedule = self.psconfig.schedule(task.schedule_ref())
        if schedule:
            self.schedule = schedule
        
        #find tools (optional)
        tools = task.tools()
        if (tools) and (len(tools) > 0):
            self.tools = tools
        
        #find priority (optional)
        priority = task.priority()
        if priority:
            self.priority = priority
        
        #set match addresses if any
        if len(self.match_addresses) > 0:
            match_addresses_map = {x.lower() : True for x in self.match_addresses}
            self._match_addresses_map = match_addresses_map
        else:
            self._match_addresses_map = None
        
        #validate specs?

        #start group
        group.start(self.psconfig)

        #set started
        self.started = True

        #return true if reach here
        return True
    
    def next(self):
        '''Finds the next matching task. Returns the addresses and remaining values can be pulled
            from class properties'''
        
        #make sure we are started
        if not self.started:
            return
        
        #clear out stuff set each next iteration
        self._reset_next()

        #find the next test we have to run
        scheduled_by = self.task.scheduled_by() if self.task.scheduled_by() else 0
        addrs = []
        matched = False
        flip = False
        scheduled_by_addr = None

        addrs = self.group.next()

        #while addrs := self.group.next(): ############needs python >= 3.8
        while addrs:
            #validate scheduled by
            if scheduled_by >= len(addrs):
                self.error = 'The scheduled-by property for task {} is too big. It is set to {} but must not be bigger than {}'.format(self.task_name, scheduled_by, len(addrs))
                return
            
            #check if disabled
            disabled = False
            for addr in addrs:
                if self._is_disabled(addr):
                    disabled = True
                    break
            
            if disabled:
                addrs = self.group.next()
                continue

            #get the scheduled-by address
            scheduled_by_addr = addrs[scheduled_by]

            #if the default scheduled-by address is no-agent, pick first address that is not no-agent
            has_agent = False
            needs_flip = False #local var so don't leak non-matching address flip value to matching address
            if self._is_no_agent(scheduled_by_addr):
                needs_flip = True
                for addr in addrs:
                    if not self._is_no_agent(addr):
                        scheduled_by_addr = addr
                        has_agent = True
                        break
            else:
                has_agent = True

            #if the address responsible for scheduling matches us, exit loop, otherwise keep looking
            if has_agent and self._is_matching_address(scheduled_by_addr):
                matched = True
                flip = needs_flip
                break

            addrs = self.group.next()

        #if no match, then exit
        if not matched:
            return

        #set addresses
        self.addresses = addrs

        ##
        #create object to be queried by jq template vars
        archives = self._get_archives(scheduled_by_addr)
        if self.error:
            return self._handle_next_error(addrs, self.error)
        
        hosts = self._get_hosts()

        if self.error:
            return self._handle_next_error(addrs, self.error)
        
        contexts = []
        has_contexts = False
        for addr in addrs:
            addr_contexts = self._get_contexts(addr)
            if self.error:
                return self._handle_next_error(addrs, self.error)
            if addr_contexts:
                has_contexts = True  
            contexts += addr_contexts
        
        jq_obj = self._jq_obj(archives, hosts, contexts)
        ## end jq obj

        #init template so we can start expanding variables
        template = Template(groups=addrs, 
                            scheduled_by_address=scheduled_by_addr, 
                            flip=flip,
                            jq_obj=jq_obj)
        
        #set scheduled_by_address for this iteration
        self.scheduled_by_address = scheduled_by_addr

        #expand test spec
        test = template.expand(self.test.data)

        if test:
            self.expanded_test = test
        
        else:
            return self._handle_next_error(addrs, "Error expanding test specification: {}".format(template.error))

        #expand archivers
        expanded_archives = []
        for archive in archives:
            expanded_archive = template.expand(archive)
            if not expanded_archive:
                return self._handle_next_error(addrs, "Error expanding archives: {}".format(template.error))
            expanded_archives.append(expanded_archive)

        self.expanded_archives = expanded_archives

        test_data = self.expanded_test

        test_data_spec = self.expanded_test['spec']
        test_data_hash = {}
        test_data_spec_hash = {}
        for test_data_key in test_data_spec:
            test_data_value = test_data_spec[test_data_key]
            test_data_spec_hash[test_data_key] = test_data_value
        
        test_data_hash['type'] = test_data['type']
        test_data_hash['spec'] = test_data_spec_hash

        test_data_json = json.dumps(test_data_hash)
        # remove quotes around numbers
        # I did't find more elegant way for unquoting numbers
        test_data_json = re.sub("['\"](\d+)['\"]", r'\1',test_data_json) #removes both single and double quotes
        number_of_participants = len(contexts)
        # self.pscheduler_url is uninitialized during template validation
        # only do this check if we have contexts to determine and a pscheduler server we can contact
        if has_contexts and self.pscheduler_url:
            psc_url = self.pscheduler_url + '/tests'
            if not psc_url:
                self.error = 'psc_url is NULL'
            psc_client = ApiConnect(url=psc_url)
            if not psc_client:
                self.error = 'psc_client is NULL'
            retrieved_number_of_participants = psc_client.get_number_of_participants(test_data_json)
            if (retrieved_number_of_participants == -1) or (retrieved_number_of_participants == '-1'):
                number_of_participants = len(contexts)
                self.error = 'Invalid number of participants'
            else:
                number_of_participants = retrieved_number_of_participants
        
        #expand contexts
        #Note: Assumes first address is first participant, second is second participant, etc.
        participants_counter = 0
        expanded_contexts = []
        for context in contexts:
            # expand contexts according to number of participants
            if participants_counter < number_of_participants:
                expanded_context = template.expand(context)
                if not expanded_context:
                    return self._handle_next_error(addrs, "Error expanding context: {}".format(template.error))
                expanded_contexts.append(expanded_context)

            participants_counter += 1

        self.expanded_contexts = expanded_contexts

        #expand reference
        reference = None
        if self.task.reference():
            reference = template.expand(self.task.reference())
            if reference:
                self.expanded_reference = reference
            else:
                return self._handle_next_error(addrs, "Error expanding reference: {}".format(template.error))

        #return the matching address set
        return addrs
    
    def stop(self):
        '''Stops the iteration and resets variables'''
        self._reset_next()
        self.started = False
        self.group.stop()
        self.task = None
        self.group = None
        self.schedule = None

    def pscheduler_task(self):
        '''Converts current task to a pScheduler Task object'''

        #make sure we are started
        if not self.started:
            return
        
        #create hash to be used as data
        task_data = {}

        #set test
        if self.expanded_test:
            task_data['test'] = self._pscheduler_prep(self.expanded_test)
        else:
            self.error = 'No expanded test found, can\'t create'
            return
        
        #set archives
        if self.expanded_archives:
            for archive in self.expanded_archives:
                self._pscheduler_prep(archive)
            task_data['archives'] = self.expanded_archives
        
        #set contexts
        if self.expanded_contexts:
            has_context = False
            for participant in self.expanded_contexts:
                for context in participant:
                    self._pscheduler_prep(context)
                    has_context = True
            
            if has_context:
                task_data['contexts'] = {'contexts': self.expanded_contexts}
            
        #set schedule
        if self.schedule:
            task_data['schedule'] = self._pscheduler_prep(self.schedule.data)
        
        #set reference
        if self.expanded_reference:
            task_data['reference'] = self.expanded_reference
        
        #set tools
        if self.tools:
            task_data['tools'] = self.tools
        
        #set priority
        if self.priority:
            task_data['priority'] = self.priority

        #time to create pscheduler task
        psched_task = Task(url = self.pscheduler_url,
                           data = task_data)
        
        #set bind map - defaults to empty object
        psched_task.bind_map = self.bind_map ###why not use add_bind_map method?

        #set lead bind address
        for addr in self.addresses:
            if addr.lead_bind_address():
                psched_task.add_lead_bind_map(addr.address(), addr.lead_bind_address())
                #since pscheduler may return pscheduler-address as lead, also need that in map if defined
                if addr.pscheduler_address():
                    psched_task.add_lead_bind_map(addr.pscheduler_address(), addr.lead_bind_address())
        
        return psched_task
    
    def _jq_obj(self, archives, hosts, contexts):
        #convert addresses
        addresses = []
        for address in self.addresses:
            addresses.append(address.data)
        
        #return object
        jq_obj = {
            'addresses': addresses,
            'archives': archives,
            'contexts': contexts,
            'hosts': hosts,
            'task': self.task.data,
            'test': self.test.data
        }

        if self.schedule:
            jq_obj['schedule'] = self.schedule.data
        
        return jq_obj
    
    def _pscheduler_prep(self, obj):
        #this is a pass by reference, so _meta will be gone in any uses after this
        #if this becomes a problem we can copy, but for efficiency purposes just removing for now
        if obj.get('_meta'):
            del obj['_meta']
        
        return obj
    
    def _is_matching_address(self, address):
        #if undefined matching addresses then everything matches 
        if not self._match_addresses_map:
            return True

        if address._parent_address:
            #if parent is set, then must match parent, otherwise no match
            if self._match_addresses_map.get(str(address._parent_address).lower()):
                return True
        elif self._match_addresses_map.get(str(address.address()).lower()):
            #no parent set, so match address
            return True
        
        #if get here , then not a match
        return False
    
    def _is_no_agent(self, address=None):
        ##
        # Checks if address or host has no-agent set. If either has it set then it 
        # will be no-agent.

        #return None if no address given
        if not address:
            return
        
        #check address no_agent
        if address._is_no_agent():
            return True
        
        #check host no_agent
        host = None
        try:
            host = self.psconfig.host(address.host_ref())
        except Exception as e:
            if address._parent_host_ref:
                host = self.psconfig.host(address._parent_host_ref)
        
        if host and host.no_agent():
            return True
        
        return False
    
    def _is_disabled(self, address=None):
        ##
        # Checks if address or host has disabled set. If either has it set then it 
        # will be disabled.
        #return undefined if no address given
        if not address:
            return

        #check address disabled
        if address._is_disabled():
            return True
        
        #check host disabled
        host = None
        
        try:
            host = self.psconfig.host(address.host_ref())
        except Exception as e:
            if address._parent_host_ref:
                host = self.psconfig.host(address._parent_host_ref)
            
        if host and host.disabled():
            return True
        
        return False
    
    def _get_archives(self, address=None, template=None): ######template not used. check usage
        archives = []

        if not address:
            return archives
        
        #init some values
        task = self.task
        psconfig = self.psconfig
        archive_tracker = {}

        #configuring archives from psconfig if allowed
        if self.use_psconfig_archives:
            host = None
            try:
                host = self.psconfig.host(address.host_ref())
            except Exception as e:
                if address._parent_host_ref:
                    host = self.psconfig.host(address._parent_host_ref)
            archive_refs = []
            if task.archive_refs():
                archive_refs += task.archive_refs()
            if host and host.archive_refs():
                archive_refs += host.archive_refs()
            
            #iterate through archives skipping duplicates
            for archive_ref in archive_refs:
                #get archive obj
                archive = psconfig.archive(archive_ref)
                if not archive:
                    self.error = "Unable to find archive defined in task: {}".format(archive_ref)
                    return
                #check if duplicate
                checksum = archive.checksum()
                if archive_tracker.get(checksum):
                    continue #skip duplicates
                #if made it here, add to the list
                archive_tracker[checksum] = True
                archives.append(archive.data)
        
        #configure default archives
        for archive in self.default_archives:
            #check if duplicate
            checksum = archive.checksum()
            if archive_tracker.get(checksum):
                continue # skip duplicates
            #if made it here, add to the list
            archive_tracker[checksum] = True
            archives.append(archive.data)
        
        return archives
    
    def _get_hosts(self):
        ##
        # Get hosts for each address.

        #iterate addresses
        hosts = []

        for address in self.addresses:
            #check host no_agent
            host = None
            try:
                host = self.psconfig.host(address.host_ref())
            except Exception as e:
                if address._parent_host_ref:
                    host = self.psconfig.host(address._parent_host_ref)
            if host:
                hosts.append(host.data)
            else:
                hosts.append({}) #push empty object to keep indices consistent
        
        return hosts
    
    def _get_contexts(self, address=None):
        contexts = []

        if not (address and address.context_refs()):
            return contexts
        
        #init some values
        psconfig = self.psconfig
        for context_ref in address.context_ref():
            context = psconfig.context(context_ref)

            if not context:
                self.error = "Unable to find context '$context_ref' defined for address {}".format(address.address())
                return
            contexts.append(context.data)
        
        return contexts
    
    def _handle_next_error(self, addrs=[], error=None):
        addr_string = ''
        for addr in addrs:
            if addr_string:
                addr_string += '->'
            if (addr and addr.address()):
                addr_string += addr.address()
            else:
                addr_string += 'None'
        
        if not error:
            error = "Unspecified"
        
        self.error = "task=" + self.task_name + ",addresses=" + addr_string + ",error=" + error

        return addrs

    def _reset_next(self):
        self.error = None
        self.expanded_test = None
        self.expanded_archives = None
        self.expanded_contexts = None
        self.expanded_reference = None
        self.scheduled_by_address = None
        self.addresses = None
