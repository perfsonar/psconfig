from ...jq_transform import JQTransform
from .base_filter import BaseFilter

class JQ(BaseFilter):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.type = 'jq'
        self.data['type'] = 'jq'
    
    def jq(self, val=None):
        '''Gets/sets JQTransform object for matching address properties'''
        return self._field_class('jq', JQTransform, val)
    
    def matches(self, address, psconfig):
        '''Return False or True depending on if given address match jq. JQ script must return boolean true 
        or non-empty string. Boolean false or empty string means negatory'''

        #can't do anything unless address is defined
        if not (address and psconfig):
            return False
        
        #check jq
        jq = self.jq()
        if jq:
            #try to apply transform
            jq_result = jq.apply(address.data)
            if not jq_result:
                return False
        
        return True
