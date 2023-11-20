
base_operand_filter = __import__("base_operand_filter", globals(), locals(), fromlist=['BaseOperandFilter'], level=1)
BaseOperandFilter = base_operand_filter.BaseOperandFilter

class OperandAnd(BaseOperandFilter):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.type = 'and'
        self.data['type'] = 'and'
        
    def matches(self, address, psconfig):
        '''Return False and True if all filters evaluate to true'''

        #Get filters
        filters = self.filters()

        #can't do anything unless address is defined
        if not address:
            return False
        
        #if something does not match, then exit. if no filters then will be true
        for filter in filters:
            if not filter.matches(address, psconfig):
                return False
        
        return True
        