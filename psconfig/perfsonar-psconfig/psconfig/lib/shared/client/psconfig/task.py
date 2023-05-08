from .base_meta_node import BaseMetaNode

class Task(BaseMetaNode):

    def scheduled_by(self, val=None):
        '''Gets/sets scheduled-by'''
        return self._field_intzero('scheduled-by', val)
    
    def group_ref(self, val=None):
        '''Gets/sets group ref'''
        return self._field_name('group', val)
    
    def test_ref(self, val=None):
        '''Gets/sets test ref'''
        return self._field_name('test', val)
    
    def schedule_ref(self, val=None):
        '''Gets/sets schedule ref'''
        return self._field_name('schedule', val)
    
    def archive_refs(self, val=None):
        '''Gets/sets archive_refs as a list'''
        return self._field_refs('archives', val)
    
    def add_archive_ref(self, val=None):
        '''Adds archive to list'''
        self._add_field_ref('archives', val)
    
    def tools(self, val=None):
        '''Gets/sets tools as a list'''
        return self._field('tools', val)
    
    def add_tool(self, val=None):
        '''Add tool to the list'''
        self._add_list_item('tools', val)
    
    def subtask_refs(self, val=None):
        '''Gets/sets subtasks as a list'''
        return self._field_refs('subtasks', val)
    
    def add_subtask_ref(self, val=None):
        '''Adds subtask to list'''
        self._add_field_ref('subtasks', val)
    
    def priority(self, val=None):
        '''Gets/sets priority'''
        return self._field_int('priority', val)
    
    def reference(self, val=None):
        '''Gets/sets reference as a dictionary'''
        return self._field_anyobj('reference', val)
    
    def reference_param(self, field, val=None):
        '''Gets/sets reference parameter specified by field'''
        return self._field_anyobj_param('reference', field, val)
    
    def disabled(self, val=None):
        '''Gets/sets disabled'''
        return self._field_bool('disabled', val)
