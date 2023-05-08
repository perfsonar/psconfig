from ipaddress import ip_address, IPv6Address, IPv4Address
from .....utilities.dns import resolve_address
from .base_filter import BaseFilter

class IPVersion(BaseFilter):

    def __init__(self):
        self.type = 'ip-version'
        self.data['type'] = 'ip-version'

    def ip_version(self, val=None):
        '''Gets/sets ip-version'''
        return self._field_ipversion('ip-version', val)

    def matches(self, address_obj, psconfig):
        '''Return False or True depending on if given address and config object match ip version'''

        #can't do anything unless address is defined
        if not (address_obj and address_obj.address()):
            return False
        
        #get address
        address = address_obj.address()
        ip_addresses = []

        try:
            if (type(ip_address(address)) is IPv6Address) or (type(ip_address(address)) is IPv4Address):
                ip_addresses.append(address)
            else:
                ip_addresses.append(resolve_address(address))
        except ValueError:
            ip_addresses.append(resolve_address(address))
        
        matches = False

        for ip in ip_addresses:
            if ((self.ip_version() == 4) and (type(ip_address(ip)) is IPv4Address)):
                matches = True
                break
            
            if ((self.ip_version() == 6) and (type(ip_address(ip)) is IPv6Address)):
                matches = True
                break

        return matches
        