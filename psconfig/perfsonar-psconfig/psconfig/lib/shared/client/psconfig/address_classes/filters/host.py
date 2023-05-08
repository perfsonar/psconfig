from ...jq_transform import JQTransform
from .base_filter import BaseFilter

class Host(BaseFilter):

    def __init__(self):
        self.type = 'host'
        self.data['type'] = 'host'
    
    def tag(self, val=None):
        '''Gets/sets tag'''
        return self._field('tag', val)
    
    def no_agent(self, val=None):
        '''Gets/sets no-agent'''
        return self._field_bool('no-agent', val)
    
    def jq(self, val=None):
        '''Gets/sets JQTransform object for matching host properties'''
        return self._field_class('jq', JQTransform, val)

    def matches(self, address=None, psconfig=None):
        '''Return False or True depending on if given address and config object match this host definition'''

        #can't do anything unless address is defined
        if not (address and psconfig):
            return False
        
        #get the host, return False if can't find it
        host = psconfig.host(address.host_ref())
        if not host:
            return False
        
        #check tags, if defined
        if self.tag():
            if host.tags():
                tag_match = False
                for host_tag in host.tags():
                    if str(host_tag).lower() == str(self.tag()).lower():
                        tag_match = True
                        break
                if not tag_match:
                    return False
            else:
                #no tags so no match
                return False
        
        #no_agent always defined (default false), so normalize booleans and compare
        if self.no_agent():
            filter_no_agent = True
        else:
            filter_no_agent = False
        
        if host.no_agent():
            host_no_agent = True
        else:
            host_no_agent = False

        if not (filter_no_agent == host_no_agent):
            return False

        #check jq
        jq = self.jq()

        if jq:
            #try to apply transformation
            jq_result = jq.apply(host.data)
            if not jq_result:
                return False
        
        return True
        