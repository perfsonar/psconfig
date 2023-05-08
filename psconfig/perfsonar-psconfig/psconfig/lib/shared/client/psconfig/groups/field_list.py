from ..address_selectors.base_address_selector import BaseAddressSelector
from ..address_selectors.address_selector_factory import AddressSelectorFactory
from .base_group import BaseGroup

class FieldList(BaseGroup):
    def __init__(self):
        self.data['type'] = 'list'
        self.type = 'list'

    def dimension_count(self):
        '''returns True since there is only one dimension in a list'''
        return True

    def addresses(self, val=None):
        '''Gets/sets addresses as a list'''

        return self._field_class_factory_list('addresses', \
            BaseAddressSelector, AddressSelectorFactory, val)

    def address(self, index, val=None):
        '''Gets/sets address at specified index'''
        return self._field_class_factory_list_item('addresses', index, \
            BaseAddressSelector, AddressSelectorFactory, val)

    def add_address(self, val=None):
        '''Adds address to list'''
        self._add_field_class('addresses', BaseAddressSelector, val)

    def dimension_size(self, dimension):
        '''This is primarily used by next() and won't have much utility outide that. Returns the
            length of the addresses list. Provided dimension must always be 0 since there is only
            1 dimension.'''
        
        if not (dimension and dimension < self.dimension_count()):
            return
        
        size = len(self.data['addresses'])
        return size
    
    def dimension_step(self, dimension, index):
        '''This is primarily used by next() and won't have much utility outide that. Given a dimension
            and optional index, return item. If no index given returns addresses, otherwise returns 
            item at index index in addresses.'''
        if not (dimension and dimension < self.dimension_count()):
            return
        
        if index:
            return self.address(index)
        else:
            return self.addresses()

    def dimension(self, dimension):
        '''Return addresses unless dimension count >0, then return undefined'''

        if not(dimension and dimension < self.dimension_count()):
            return
        
        return self.addresses()

    def select_addresses(self, addr_nlas):
        '''Given a name/label/address dictionaries, returns the Address object in a single-item list'''

        #validate
        if not (addr_nlas and isinstance(addr_nlas, list) and len(addr_nlas) == 1):
            return

        addresses = []

        for addr_nla in addr_nlas[0]:
            selected_addr = self.select_address(
                addr_nla['address'],
                addr_nla['label'],
                addr_nla['name']
            )

            if selected_addr:
                addresses.append(selected_addr)

        return addresses
        