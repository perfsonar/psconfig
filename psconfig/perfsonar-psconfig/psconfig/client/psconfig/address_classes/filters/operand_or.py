from .base_operand_filter import BaseOperandFilter

class OperandOr(BaseOperandFilter):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.type = 'or'
        self.data['type'] = 'or'
        
    
    def matches(self, address=None, psconfig=None):
        '''return False or True depending on if given address and config object matches any of the filters'''

        #return match if no filters defined
        filters = self.filters()

        #can't do anything unless address is defined
        if not address:
            return False
        
        #if any match, then success
        for filter in filters:
            if filter.matches(address, psconfig):
                return True
        
        return False