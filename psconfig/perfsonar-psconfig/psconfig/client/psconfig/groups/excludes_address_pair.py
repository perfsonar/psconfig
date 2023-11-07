from ..address_selectors.address_selector_factory import AddressSelectorFactory
from ..address_selectors.base_address_selector import BaseAddressSelector

from ..base_node import BaseNode

class ExcludesAddressPair(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def local_address(self, val=None):
        '''Get/sets local-address'''
        return self._field_class_factory('local-address',\
            BaseAddressSelector,
            AddressSelectorFactory,
            val)
    
    def target_addresses(self, val=None):
        '''Get/sets target-addresses as a list'''
        return self._field_class_factory_list('target-addresses',\
                    BaseAddressSelector,
                    AddressSelectorFactory,
                    val)
    
    def target_address(self, index, val=None):
        '''Get/sets target-address at specified index'''
        return self._field_class_factory_list_item('target-addresses', index,\
            BaseAddressSelector, AddressSelectorFactory, val)
    
    def add_target_address(self, val=None):
        '''Adds target-address to list'''
        self._add_field_class('target-addresses',\
            BaseAddressSelector, val)
