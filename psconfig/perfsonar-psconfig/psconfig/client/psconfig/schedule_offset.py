from .base_node import BaseNode

class ScheduleOffset(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def type(self, val=None):
        '''Gets/sets type'''
        return self._field_enum('type', val, {'start': True, 'end': True})

    def relation(self, val=None):
        '''Gets/sets relation'''
        return self._field_enum('relation', val, {'before': True, 'after': True})
    
    def offset(self, val=None):
        '''Gets/sets offset'''
        return self._field_duration('offset', val)
