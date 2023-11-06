from ...base_node import BaseNode

class BaseFilter(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.type = None #override this
        
    def matches(self, address, psconfig):
        '''Return False or True depending on if given address and Config object match this filter'''

        #given address object and config, return whether matches filter
        raise Exception('override this')
