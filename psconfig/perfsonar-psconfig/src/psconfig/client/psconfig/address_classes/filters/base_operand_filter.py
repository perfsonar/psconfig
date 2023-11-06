

from .base_filter import BaseFilter

class BaseOperandFilter(BaseFilter):
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def filters(self, val=None):
        '''Gets/sets filters as list'''

        filter_factory = __import__("filter_factory", globals(), locals(), fromlist=['FilterFactory'], level=1)
        FilterFactory = filter_factory.FilterFactory

        return self._field_class_factory_list('filters',
        BaseFilter, FilterFactory,
        val)
    
    def filter(self, index, val=None):
        '''Gets/sets filter at given index. returns filter object'''
        filter_factory = __import__("filter_factory", globals(), locals(), fromlist=['FilterFactory'], level=1)
        FilterFactory = filter_factory.FilterFactory
        return self._field_class_factory_list_item('filters', index,
        BaseFilter, FilterFactory, val)
    
    def add_filter(self, val=None):
        '''adds filter to list'''
        self._add_field_class('filters', BaseFilter, val)
