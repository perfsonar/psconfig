from ...base_node import BaseNode

class BaseFilter(BaseNode):

    def __init__(self, **kwargs):
        self.type = None #override this
        super().__init__(**kwargs)

    def matches(self, address, psconfig):
        '''Return False or True depending on if given address and Config object match this filter'''

        #given address object and config, return whether matches filter
        raise Exception('override this')
