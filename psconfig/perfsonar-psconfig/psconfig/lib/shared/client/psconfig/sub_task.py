from .schedule_offset import ScheduleOffset
from .base_meta_node import BaseMetaNode

class SubTask(BaseMetaNode):

    def test_ref(self, val=None):
        '''Gets/sets test as list'''
        return self._field_name('test', val)
    
    def schedule_offset(self, val=None):
        '''Gets/sets schedule-offset'''
        return self._field_class('schedule-offset', ScheduleOffset, val)
    
    def archive_refs(self, val=None):
        '''Gets/sets archives as list'''
        return self._field_refs('archives', val)
    
    def add_archive_ref(self, val):
        '''Add archive'''
        self._add_field_ref('archives', val)
    
    def tools(self, val=None):
        '''Gets/sets tools as list'''
        return self._field('tools', val)
    
    def add_tool(self, val=None):
        '''Add tool'''
        self._add_list_item('tools', val)
    
    def reference(self, val=None):
        '''Gets/sets reference as list'''
        return self._field_anyobj('reference', val)
    
    def reference_param(self, field, val):
        '''Gets/sets reference param'''
        return self._field_anyobj_param('reference', field, val)
    
    def disabled(self, val=None):
        '''Gets/sets disabled'''
        return self._field_bool('disabled', val)
    