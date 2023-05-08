from .base_address_selector import BaseAddressSelector

class FieldClass(BaseAddressSelector):
    def __init__(self):
        self.type = 'class' #override this

    def field_class(self, val=None):
        '''Gets/sets class'''
        return self._field_name('class', val)
    
    def select(self, psconfig):
        #make sure we have a config
        if not psconfig:
            return None, None
        
        #make sure we have a name
        class_name = self.field_class()
        if not class_name:
            return None, None
        
        #make sure it matches an address
        address_class = psconfig.address_class(class_name)
        if not address_class:
            return None, None
        
        return address_class.select(psconfig)

    