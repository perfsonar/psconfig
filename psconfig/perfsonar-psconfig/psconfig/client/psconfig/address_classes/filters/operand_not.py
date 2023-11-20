from .base_filter import BaseFilter

class OperandNot(BaseFilter):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.type = 'not'
        self.data['type'] = 'not'
    
    def filter(self, val=None):
        '''Gets/sets filter'''
        filter_factory = __import__("filter_factory", globals(), locals(), fromlist=['FilterFactory'], level=1)
        FilterFactory = filter_factory.FilterFactory
        return self._field_class_factory('filter',
        BaseFilter, FilterFactory, val)
    
    def matches(self, address, psconfig):
        '''Return False or True depending on if given address and config object does not match given filter'''

        #return match if no filter defined
        filter = self.filter()
        if not filter:
            return True
        
        #can't do anything unless address is defined
        if not address:
            return False
        
        if filter.matches(address, psconfig):
            return False
        else:
            return True