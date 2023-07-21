from .base_filter import BaseFilter

class AddressClass(BaseFilter):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.type = 'address-class'
        self.data['type'] = 'address-class'
    
    def field_class(self, val=None):
        '''Returns class'''

        return self._field_name('class', val)

    def matches(self, address, psconfig):
        '''Return False or True depending on if given address and Config object match this class'''
        
        #return match if no tag defined
        class_name = self.field_class()
        if not class_name:
            return True

        #cant do anything unless address is defined
        if not address:
            return False
        
        #if can't find address class, fail
        addr_class = psconfig.address_class(class_name)
        if not addr_class:
            return False
        
        return addr_class.matches(address, psconfig)
        
