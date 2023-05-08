from .base_filter import BaseFilter

class Tag(BaseFilter):

    def __init__(self):
        self.data['type'] = 'tag'
        self.type = 'tag'

    def tag(self, val=None):
        '''Gets/sets tag'''

        return self._field('tag', val)

    
    def matches(self, address, psconfig):
        '''Return False or True depending on if given address and Config object has the given tag'''
        
        #return match if no tag defined
        tag = self.tag()

        if not tag:
            return True
        tag = str(tag).lower()

        #can't do anything unless address is defined
        if not address:
            return False

        #try to match tags in address
        if address.tags():
            for addr_tag in address.tags():
                if str(addr_tag).lower() == tag:
                    return True

        #try to match tags in host
        host = psconfig.host(address.host_ref())
        if not host:
            return False
        
        if host.tags():
            for host_tag in host.tags():
                if str(host_tag).lower() == tag:
                    return True

        return False

        