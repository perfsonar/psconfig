from .base_meta_node import BaseMetaNode

class Test(BaseMetaNode):

    def type(self, val=None):
        return self._field('type', val)
    
    def spec(self, val=None):
        return self._field_anyobj('spec', val)
    
    def spec_param(self, field, val=None):
        return self._field_anyobj_param('spec', field, val)

