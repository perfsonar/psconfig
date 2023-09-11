import shared.client.psconfig.groups.exclude_self_scope as exclude_self_scope
from .excludes_address_pair import ExcludesAddressPair
from .base_group import BaseGroup

class BaseP2PGroup(BaseGroup):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._exclude_checksum_map =  None
    
    def dimension_count(self):
        '''Returns 2 since there are two dimensions (src, dst) in point-to-point test'''
        return 2

    def excludes_self(self, val=None):
        if val:
            if exclude_self_scope.VALID_VALUES.get(val):
                self.data['excludes-self'] = val
            else:
                #invalid value - leave unchanged
                pass
        
        return self.data.get('excludes-self')
    
    def excludes(self, val=None):
        '''Gets/sets excludes a list'''
        return self._field_class_list('excludes', ExcludesAddressPair, val)
    
    def exclude(self, index, val=None):
        '''Gets/sets exclude as specified index'''
        return self._field_class_list_item('excludes', index, ExcludesAddressPair, val)

    def add_exclude(self, val=None):
        '''Adds exclude to list'''
        self._add_field_class('excludes', ExcludesAddressPair, val)

    def is_excluded_selectors(self, addr_sels):
        '''Given list of two address selectors, returns True if should be excluded, False otherwise'''

        #validate
        if not (addr_sels and isinstance(addr_sels, list) and len(addr_sels) == 2):
            return
        
        #process excludes
        exclude_this = False
        excludes = self.excludes()
        if len(excludes) > 0:
            #init _exclude_checksum_map if needed
            if not self._exclude_checksum_map():
                tmp_map = {}
                for excl_pair in excludes:
                    local_checksum = excl_pair.local_address().checksum()
                    tmp_map[local_checksum] = tmp_map.get(local_checksum, {})
                    for target in excl_pair.target_addresses():
                        tmp_map[local_checksum][target.checksum()] = True
                
                self._exclude_checksum_map = tmp_map
            
            #check
            a_checksum = addr_sels[0].checksum()
            b_checksum = addr_sels[1].checksum()
            if self._exclude_checksum_map.get(a_checksum) and \
                self._exclude_checksum_map.get(a_checksum).get(b_checksum):
                exclude_this = True
            
        return exclude_this
    
    def is_excluded_addresses(self, a_addr, b_addr, a_host, b_host):
        '''Given two addresses and two hosts, returns True if should be excluded and False otherwise'''
        
        #validate
        if not (a_addr and b_addr):
            return True
        
        #default exclude_self is host
        exclude_self = self.excludes_self()
        if not exclude_self:
            exclude_self = exclude_self_scope.HOST
        
        #check host scope
        if exclude_self == exclude_self_scope.HOST:
            if a_host and b_host and (a_host.lower() == b_host.lower()):
                return True
            
        #check address scope
        if exclude_self == exclude_self_scope.HOST or exclude_self == exclude_self_scope.ADDRESS:
            if a_addr._parent_address:
                addr1 = a_addr._parent_address
            else:
                addr1 = a_addr.address()
            
            if b_addr._parent_address:
                addr2 = b_addr._parent_address
            else:
                addr2 = b_addr.address()
            
            if addr1 and addr2 and (addr1 == addr2):
                return True
        
        #don't exclude
        return False
    
    def select_addresses(self, addr_nlas):
        '''Given two name/label/address dictionaries, returns the a tuple of Address objects. If excluded
            return and empty list'''

        #validate
        if not (addr_nlas and isinstance(addr_nlas, list) and len(addr_nlas) == 2):
            return

        address_pairs = []

        for a_addr_nla in addr_nlas[0]:
            for b_addr_nla in addr_nlas[1]:
                a_addr = self.select_address(
                    a_addr_nla['address'],
                    a_addr_nla['label'],
                    b_addr_nla['name']
                )
                b_addr = self.select_address(
                    b_addr_nla['address'],
                    b_addr_nla['label'],
                    a_addr_nla['name']
                )

                a_host = a_addr_nla['address'].host_ref()
                b_host = b_addr_nla['address'].host_ref()
                
                #pass host directly since AddressLabel won't have host_ref
                if not (self.is_excluded_addresses(a_addr, b_addr, a_host, b_host)):
                    address_pairs += [a_addr, b_addr]
        
        return address_pairs
    
    def _stop(self):
        self._exclude_checksum_map = None
