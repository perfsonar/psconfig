from ..base_meta_node import BaseMetaNode

class BaseGroup(BaseMetaNode):

    def __init__(self):
        self.type = None #override this!
        self.started = False
        self.iter = 0
        self._address_queue = []
        self._psconfig = None

    
    def default_address_label(self, val=None):
        '''Gets/sets default-address-label'''
        return self._field('default-address-label', val)
    
    def dimension_count(self):
        '''function to override that returns number of dimensions'''
        #returns number of dimensions
        raise Exception('Override this')
    
    def dimension(self):
        '''function that returns dimension at given index'''
        raise Exception('Override this')
    
    def dimension_step(self, indices):
        '''function to override that returns dimension at given coordinates. This is only used in
        iterating through group. For complex toplogies there may be merging and other things
        done here'''
        #accepts list of indices for each dimension and returns AddressSelector
        raise Exception('Override this')
    
    def dimension_size(self, index):
        '''Returns size of dimensions at given index'''
        #accepts dimension for which you want the size and return int
        raise Exception('Overrise this')

    def select_addresses(self, addr_nlas):
        '''Given an array of dictionaries containing {'name':'..', 'label':'..', 'address': Address}
        find all the combose and return a list of lists of BaseAddress objects where things
        like remote address and labelled address have been worked-out'''

        raise Exception('override this')
    
    def is_excluded_selectors(self, addr_sels):
        '''Method that indicates if given address combination should be excluded. This
        implementation always returns False(never exclude), should be overridden if you
        need different behavior.'''
        #override this if group has ways to exclude address selector combinations
        return False

    def start(self, psconfig):
        '''Initializes variables used to iterate through group'''
        #Gets the next group of address selectors

        #if already started
        if self.started:
            return
        
        self._reset_iter()
        self._psconfig = psconfig
        self._start()
        self.started = True
    
    def _start(self):
        #override this if you have local state set to start
        return
    
    def grab_next(self):
        '''Grabs the next address combination, or returns empty list if none. Must call start first.'''
        #Gets the next group of address selectors

        #only run this if we ran start
        if not self.started:
            return
        
        #loop generalized for N dimensions that iterates through each dimension
        #and grabs next item in series.
        while(not self._address_queue):
            excluded = True
            addr_sels =  []

            while excluded:
                #exit if reached max
                if self.iter > self.max_iter():
                    return

                working_size = 1
                addr_sels = []
                i = self.dimension_count()
                while i > 0:
                    index = None
                    if i == self.dimension_count():
                        index = self.iter % self.dimension_size(i-1)
                    else:
                        working_size *= self.dimension_size(i)
                        index = int(self.iter/ (working_size + 0.0))

                    addr_sel = self.dimension_step(i-1, index)
                    addr_sels = [addr_sel] + addr_sels

                    i -= 1
                
                excluded = self.is_excluded_selectors(addr_sels)
                self._increment_iter()

            #we now have the selectors. time to expand
            addr_nlas = []
            for addr_sel in addr_sels:
                addr_nlas.append(addr_sel.select(self._psconfig))
            
            #we now have the name, label, addresses, time to combine in group specific way
            addr_combos = self.select_addresses(addr_nlas)
            if addr_combos:
                self._address_queue.append(addr_combos)
        
        addresses = self._address_queue.pop(0)
        return addresses
        
    def stop(self):
        '''Ends iteration and resets iteration variables'''

        self.started = False
        self._reset_iter()
        self._stop()
        self._psconfig = None
    
    def _stop(self):
        #override this if you have a local state to reset
        return
    
    def max_iter(self):
        '''Return maximum possible number of combinations to iterate over'''
        max_size = 1
        for i in range(self.dimension_count()):
            max_size *= self.dimension_size(i)
        return max_size-1
    
    def select_address(self, local_addr, local_label, remote_addr_key):
        '''Selects address given a address obj, label and remote address key.'''
        ##
        # Selects address given a address obj, label and remote address key. Once we get
        # >2 dimensions remote key may be aggregate of other dimensions

        #validate
        if not local_addr:
            return
        
        #set label to default
        default_label = self.default_address_label()
        if default_label and not local_label:
            local_label = default_label
        
        #check for remotes first - if remote_addr_key None then below is None
        remote_addr_entry = local_addr.remote_address(remote_addr_key)
        if remote_addr_entry:
            remote_label_entry = remote_addr_entry.label(local_label)
            if remote_label_entry:
                #return label with disabled and no-agent settings merged-in
                return self.merge_parents(remote_label_entry, [local_addr, remote_addr_entry])
            elif (not local_label) and remote_addr_entry.address():
                #return remote address with disabled and no-agent settings merged in 
                #only fall back to this if no label specified
                return self.merge_parents(remote_addr_entry, [local_addr])
            else:
                return
        
        #check for label next
        if local_label:
            label_entry = local_addr.label(local_label)
            if label_entry:
                return self.merge_parents(label_entry, [local_addr])
            else:
                #if we have a label but we don't have a match, then skip this address
                return
        
        #finally, if none of the above work, just use the address obj as is
        return local_addr
    
    def merge_parents(self, addr, parents):
        '''Merges inherited values into addresses from parent addresses if any'''

        #make sure we have required params
        if not (addr, parents):
            return
        
        #iterate through parents
        for parent in parents:
            if parent.no_agent() or parent._parent_no_agent:
                addr._parent_no_agent = True
            if parent.disabled() or parent._parent_disabled:
                addr._parent_disabled = True
            
            if 'host_ref' in dir(parent):
                #only Address has host_ref, so set that as parent
                addr._parent_address = parent.address()
                addr._parent_name = parent.map_name()
                if parent.host_ref():
                    addr._parent_host_ref = parent.host_ref()
            elif parent._parent_host_ref:
                addr._parent_host_ref = parent._parent_host_ref

        return addr
    
    def _increment_iter(self):
        self.iter += 1
    
    def _reset_iter(self):
        self.iter = 0
