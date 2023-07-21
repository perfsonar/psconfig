import os
import re

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
        curr_interface = None
        ifdetails = None

        IP_ADDR = os.popen("ip addr show").readlines()

        for line in IP_ADDR:
            # detect primary interface line
            interface = re.search('^\d+: ([^ ]+?)(@[^ ]+)?: (.+)$', line)

            if interface:
                curr_interface = interface.groups()[0]
                ifdetails = interface.groups()[2]
            
            # parse inet and inet6 lines for addresses.
            # To get interface aliases, we must use the name at end of the line.
            # inet6 lines don't have an intf name at the end, so ipv6 addresses will always go with the non-alias name.
            inet = re.search('inet (\d+\.\d+\.\d+\.\d+).+scope (global|host) (\S+)', line)

            if inet:
                ret_interfaces[curr_interface] = ret_interfaces.get(curr_interface, [])
                ret_interfaces[curr_interface].append(inet.groups()[0])
            
            inet6 = re.search('inet6 ([a-fA-F0-9:]+)\/\d+ scope (global|host)', line)

            if inet6:
                ret_interfaces[curr_interface] = ret_interfaces.get(curr_interface, [])
                ret_interfaces[curr_interface].append(inet6.groups()[0])
        
        if by_interface:
            return ret_interfaces
        
        else:
            ret_values = []
            for key in ret_interfaces:
                ret_values += ret_interfaces[key]
            return ret_values
