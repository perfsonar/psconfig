import netifaces

class Host():
    '''
    A module that provides functions for querying information about the host on
    which the application is running
    '''

    def get_ips(self, by_interface=False):
        '''A function that returns the IP addresses from a host. The current  
            implementation parses the output of the /sbin/ip command to look for the
            IP addresses.'''
        
        ret_interfaces = {}
        for iface in netifaces.interfaces():
            ret_interfaces[iface] = []
            addresses = netifaces.ifaddresses(iface)
            for family in addresses:
                for addr_info in addresses[family]:
                    if addr_info.get("addr", None):
                        ret_interfaces[iface].append(addr_info["addr"])
        

        if by_interface:
            return ret_interfaces
        else:
            ret_values = []
            for key in ret_interfaces:
                ret_values += ret_interfaces[key]
            return ret_values
