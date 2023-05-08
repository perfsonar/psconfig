from .base_node import BaseNode

class ArchiveJqTransform(BaseNode):
    def script(self, val=None):
        '''Getter/ setter for jq script. Can be string or list of strings where each item in list
        is a line of the JQ script
        '''
        return self._field_list('script', val)
    
    def output_raw(self, val=None):
        '''Tells pscheduler to output in raw format instead of JSON'''
        return self._field_bool('output-raw', val)
    
    def args(self, val=None):
        '''Additional args pscheduler will pass to jq parser'''
        return self._field_anyobj('args', val)
