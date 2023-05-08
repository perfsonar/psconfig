from ipaddress import ip_network, ip_address, IPv6Address, IPv4Address
from .....utilities.dns import resolve_address

from .base_filter import BaseFilter

class NetMask(BaseFilter):

    def __init__(self):
        self.type = 'netmask'
        self.data['type'] = 'netmask'
    
    def netmask(self, val=None):
        '''Gets/sets netmask'''
        return self._field_ipcidr('netmask', val)

    def matches(self, address_obj, psconfig):
        '''Return False or True depending on if given address and Config object match the provided netmask'''
        if not (address_obj and address_obj.address()):
            return False

        #get address
        address = address_obj.address()
        ip_addresses= []

        try:
            if type(ip_address(address)) is IPv6Address or type(ip_address(address)) is IPv4Address:
                ip_addresses.append(address)
            else:
                ip_addresses.append(resolve_address(address))
        except ValueError:
            ip_addresses.append(resolve_address(address))
        
        matches = False
        netmask = self.netmask()

        for ip in ip_addresses:
            if ip_address(ip) in ip_network(netmask):
                matches = True
            if matches:
                break
        
        return False
        