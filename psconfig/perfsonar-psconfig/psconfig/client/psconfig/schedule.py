from .base_meta_node import BaseMetaNode

class Schedule(BaseMetaNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def start(self, val=None):
        '''Gets/sets start'''
        return self._field_timestampabsrel('start', val)

    def slip(self, val=None):
        '''Gets/sets slip'''
        return self._field_duration('slip', val)
    
    def slip_rand(self, val=None):
        '''Gets/sets sliprand'''
        return self._field_bool('sliprand', val)
    
    def repeat(self, val=None):
        '''Gets/sets repeat'''
        return self._field_duration('repeat', val)
    
    def until(self, val=None):
        '''Gets/sets until'''
        return self._field_timestampabsrel('until', val)
    
    def max_runs(self, val=None):
        '''Gets/sets max-runs'''
        return self._field_cardinal('max-runs', val)
