from ..address_selectors.address_selector_factory import AddressSelectorFactory
from ..address_selectors.base_address_selector import BaseAddressSelector
from .base_p2p_group import BaseP2PGroup

class Disjoint(BaseP2PGroup):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.data['type'] = 'disjoint'
        self.type = self.data.get('type')
        self._merged_addresses = []
        self._a_address_map = {}
        self._b_address_map = {}
        self._checked_pairs = {}
        

    def unidirectional(self, val=None):
        '''Gets/sets unidirectional'''

        return self._field_bool('unidirectional', val)

    def a_addresses(self, val=None):
        '''Gets/sets a-addresses'''

        return self._field_class_factory_list('a-addresses',\
            BaseAddressSelector, AddressSelectorFactory,val)
        
    def a_address(self, index, val=None):
        '''Gets/sets a-address at specified index'''

        return self._field_class_factory_list_item('a-addresses', index, \
            BaseAddressSelector, AddressSelectorFactory, val)
    
    def add_a_address(self, val=None):
        '''Adds a-address to list'''

        self._add_field_class('a-addresses', BaseAddressSelector, val)

    def b_addresses(self, val=None):
        '''Gets/sets b-addresses'''
        return self._field_class_factory_list('b-addresses',\
            BaseAddressSelector, AddressSelectorFactory, val)
        
    def b_address(self, index, val=None):
        '''Gets/sets b-address at specified index'''

        return self._field_class_factory_list_item('b-addresses', index, \
            BaseAddressSelector, AddressSelectorFactory, val)
    
    def add_b_address(self, val=None):
        '''Adds b-address to list'''

        self._add_field_class('b-addresses', BaseAddressSelector, val)


    def dimension_size(self, dimension):
        '''This is primarily used by next() and won't have much utility outide that. It merges 
            a_addresses and b_addresses and returnes the total size as needed by the next() algorithm 
            genealized for n dimensions. Tests are then excluded using the is_excluded_selectors below.'''
        
        if not (dimension < self.dimension_count()):
            return
        
        size = len(self._merged_addresses)

        return size

    def dimension_step(self, dimension, index):
        '''Similar to dimension size, not very useful outside of next() context. See  
            dimension_size() comment.'''
        if not (dimension < self.dimension_count()):
            return
        
        if index is not None:
            return self._merged_addresses[index]
        else:
            return self._merged_addresses

    def dimension(self, dimension):
        '''Return a_addresses for 0 and b_addresses for 1. None otherwise'''
        if not (dimension < self.dimension_count()):
            return
        
        if dimension == 0:
            return self.a_addresses()
        else:
            return self.b_addresses()

    def _start(self):
        merged_addresses = []
        a_addr_map = {}
        b_addr_map = {}
        for a_addr in self.a_addresses():
            merged_addresses.append(a_addr)
            a_addr_map[a_addr.checksum()] = True
        
        for b_addr in self.b_addresses():
            merged_addresses.append(b_addr)
            b_addr_map[b_addr.checksum()] = True
        
        self._merged_addresses = merged_addresses
        self._a_address_map = a_addr_map
        self._b_address_map = b_addr_map
        self._checked_pairs = {}

        return
    
    def _stop(self):
        self._merged_addresses = None
        self._a_address_map = None
        self._b_address_map = None
        self._checked_pairs = None
        self._exclude_checksum_map = None


    def is_excluded_selectors(self, addr_sels):
        '''Given two selectors, return True if should be excluded and False otherwise'''
        
        #validate
        if not (addr_sels and isinstance(addr_sels, list) and len(addr_sels) == 2):
            return
        
        #verify that we haven't already checked this
        checksum0 = addr_sels[0].checksum()
        checksum1 = addr_sels[1].checksum()
        if self._checked_pairs.get("{}->{}".format(checksum0, checksum1)):
            return True
        
        #check that first is in a and the other in b, if bidirectional also ok if reverse
        if not (
            (self._a_address_map.get(checksum0) and self._b_address_map.get(checksum1)) or \
                (not self.unidirectional() and self._a_address_map.get(checksum1) and self._b_address_map.get(checksum0))
            ):
            return True
        
        self._checked_pairs["{}->{}".format(checksum0, checksum1)] = True

        return super().is_excluded_selectors(addr_sels)
