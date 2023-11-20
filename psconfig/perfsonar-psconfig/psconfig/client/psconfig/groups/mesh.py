
from ..address_selectors.base_address_selector import BaseAddressSelector
from ..address_selectors.address_selector_factory import AddressSelectorFactory
from .base_p2p_group import BaseP2PGroup

class Mesh(BaseP2PGroup):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.type = 'mesh'
        self.data['type'] = 'mesh'
        
    
    def addresses(self, val=None):
        '''Gets/sets addresses as list'''
        return self._field_class_factory_list('addresses',\
            BaseAddressSelector, AddressSelectorFactory, val)

    def address(self, index, val=None):
        '''Gets/sets address at specified index'''
        return self._field_class_factory_list_item('addresses', index,\
            BaseAddressSelector, AddressSelectorFactory, val)
        
    def add_address(self, val=None):
        '''Adds address to list'''
        self._add_field_class('addresses', BaseAddressSelector, val)

    def dimension_size(self, dimension):
        '''This is primarily used by next() and won't have much utility outside that. Returns the
            length of the addresses list since both dimensions are the same in a mesh.'''
        if not (dimension < self.dimension_count()):
            return
        
        size = len(self.data['addresses'])
        return size
    
    def dimension_step(self, dimension, index):
        '''This is primarily used by next() and won't have much utility outide that. Given a dimension
            and optional index, return item. If no index given returns addresses, otherwise returns 
            item at index index in addresses.'''
        if not (dimension < self.dimension_count()):
            return
        
        if index is not None:
            return self.address(index)
        else:
            return self.addresses()
    
    def dimension(self, dimension):
        '''Return addresses unless dimension count >1, then return None'''
        if not (dimension < self.dimension_count()):
            return
        
        return self.addresses()
    