from ..base_meta_node import BaseMetaNode

class BaseAddress(BaseMetaNode):
    #properties inherited from a parent that don't mess with the json. used internally in
    # test iteration and should not generally be used directly by clients

    def __init__(self, **kwargs):
        BaseMetaNode.__init__(self, **kwargs)
        self._parent_disabled = None
        self._parent_no_agent = None
        self._parent_host_ref = None
        self._parent_address = None
        self._parent_name = None
    
    def address(self, val=None):
        '''Gets/sets address'''
        return self._field_host('address', val)

    def lead_bind_address(self, val=None):
        '''Gets/sets lead-bind-address'''
        return self._field_host('lead-bind-address', val)
    
    def pscheduler_address(self, val=None):
        '''Gets/sets pscheduler-address'''
        return self._field_urlhostport('pscheduler-address', val)
    
    def disabled(self, val=None):
        '''Gets/sets disabled'''
        return self._field_bool('disabled', val)
    
    def no_agent(self, val=None):
        '''Gets/sets no-agent'''
        return self._field_bool('no-agent', val)
    
    def context_refs(self, val=None):
        '''Gets/sets contexts as a list'''
        return self._field_refs('contexts', val)
    
    def add_context_ref(self, val):
        '''Adds a context to the list'''
        self._add_field_ref('contexts', val)
    
    def _is_no_agent(self):
        return self.no_agent() or self._parent_no_agent
    
    def _is_disabled(self):
        return self.disabled() or self._parent_disabled
    