from hashlib import md5
from base64 import b64encode
from .base_node import BaseNode

class BaseMetaNode(BaseNode):
    def __init__(self, **kwargs):
        self.data = kwargs.get('data', {})
    
    def psconfig_meta(self, val=None):
        '''Gets/sets _meta'''
        return self._field_anyobj('_meta', val)
    
    def psconfig_meta_param(self, field, val=None):
        '''Gets/sets _meta parameter to a given field'''
        return self._field_anyobj_param('_meta', field, val)
    
    def remove_psconfig_meta(self):
        '''Removes _meta'''
        self._remove_map('_meta')