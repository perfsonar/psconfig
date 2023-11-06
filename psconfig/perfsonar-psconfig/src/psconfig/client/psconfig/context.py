from .base_meta_node import BaseMetaNode

class Context(BaseMetaNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
    def context(self, val=None):
        '''Sets/gets context type'''
        return self._field('context', val)

    def context_data(self, val=None):
        '''Sets/gets context data'''
        return self._field_anyobj('data', val)
    
    def context_data_param(self, field, val=None):
        '''Sets/gets context parameter specified by field in data'''
        return self._field_anyobj_param('data', field, val)
