from .base_address_selector import BaseAddressSelector

class NameLabel(BaseAddressSelector):

    def __init__(self):
        self.type = 'namelabel' #override this

    def name(self, val=None):
        '''Gets/sets name'''
        return self._field_name('name', val)

    def label(self, val=None):
        return self._field_name('label', val)
    
    def select(self, psconfig):
        '''Selects addresses with given name and label then returns as list of name/label/address
            dictionaries.'''
        
        #make sure we have a psconfig
        if not psconfig:
            return None, None
        
        #make sure we have a name
        name = self.name()
        if not name:
            return None, None
        
        #make sure it matches an address
        address = psconfig.address(name)
        if not address:
            return None, None
        
        #got everything we need, return. Label may be None, but that's ok
        return [{'label':self.label(), 'name':name, 'address': address}]
    
    