'''A library for filling in template variables in JSON
'''

from .base_template import BaseTemplate
import re
from ipaddress import ip_address, IPv6Address

class Template(BaseTemplate):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.groups = kwargs.get('groups', [])
        self.scheduled_by_address = kwargs.get('scheduled_by_address')
        self.flip = kwargs.get('flip', False)

    def _expand_var(self, template_var):
        addr_match = re.match('^address\[(\d+)\]$', template_var)
        pscheduler_address_match = re.match('^pscheduler_address\[(\d+)\]$', template_var)
        lead_bind_address_match = re.match('^lead_bind_address\[(\d+)\]$', template_var)
        jq_match = re.match('^jq (.+)$', template_var)

        if addr_match:
            val = self._parse_group_address(int(addr_match.group(1)))
        elif pscheduler_address_match:
            val = self._parse_pscheduler_address(int(pscheduler_address_match.group(1)))
        elif lead_bind_address_match:
            val = self._parse_lead_bind_address(int(lead_bind_address_match.group(1)))
        elif template_var == 'scheduled_by_address':
            val = self._parse_scheduled_by_address()
        elif template_var == 'flip':
            val = self._parse_flip()
        elif template_var == 'localhost':
            val = self._parse_localhost()
        elif jq_match:
            val = self._parse_jq(jq_match.group(1))
        else:
            self.error = 'Unrecognized template variable {}'.format(template_var)
        
        return val
    
    def _parse_group_address(self, index):
        if index > len(self.groups):
            self.error = 'Index is too big in group[{}] template variable'.format(index)
            return
        
        #this should not happen, but here for completeness
        if not self.groups[index].address():
            self.error = 'Template variable group[{}] does not have an address'.format(index)
            return
        
        return '"' + self.groups[index].address() + '"'
    
    def _parse_pscheduler_address(self, index):
        if index >= len(self.groups):
            self.error = 'Index is too big in group[{}] template variable'.format(index)
            return
        
        #this should not happen but here for completeness
        address = self.groups[index].pscheduler_address()
        #fallback to address
        if not address:
            address = self.groups[index].address()
        if not address:
            self.error = 'Template variable group[{}] does not have a pscheduler-address nor address'.format(index)
            return
        
        #bracket ipv6 addresses - if hostname and not an ip then continue
        try:
            if type(ip_address(address)) is IPv6Address:
                address = '[' + address + ']'
        except ValueError:
            pass

        return '"' + address + '"'
    
    def _parse_lead_bind_address(self, index):
        if index >= len(self.groups):
            self.error = 'Index is too big in group[{}] template variable'.format(index)
            return
        
        #this should not happen, but here for completeness
        address = self.groups[index].lead_bind_address()
        #fallback to address
        if not address:
            address = self.groups[index].address()
        if not address:
            self.error = 'Template variable group[{}] does not have a lead-bind-address or address'.format(index)
            return
        return '"' + address + '"'
    
    def _parse_scheduled_by_address(self):
        #should not be possible, but double-check
        if not self.scheduled_by_address:
            self.error = 'No scheduled_by_address value provided. This is likely a bug in the software.'
            return
        
        #also should not happen, but here for completeness
        if not self.scheduled_by_address.address():
            self.error = 'scheduled_by_address cannot be determined. This is likely a bug in the software.'
            return
        
        return '"' + self.scheduled_by_address.address() + '"'
    
    def _parse_flip(self):
        return "true" if self.flip else "false"
    
    def _parse_localhost(self):
        #if flipped, use scheduled_by_address
        if self.flip:
            return self._parse_scheduled_by_address()
        
        #otherwise use localhost
        return 'localhost'
    