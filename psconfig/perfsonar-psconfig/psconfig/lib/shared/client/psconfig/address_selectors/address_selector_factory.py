from .name_label import NameLabel
from .field_class import FieldClass
from ..base_node import BaseNode

class AddressSelectorFactory(BaseNode):

    def build(self, data=None):
        '''Creates an address selector based on the 'type' field of the given dictionary'''
        if data:
            if data.get('name'):
                return NameLabel(data=data)
            elif data.get('class'):
                return FieldClass(data=data)
        
        return None

