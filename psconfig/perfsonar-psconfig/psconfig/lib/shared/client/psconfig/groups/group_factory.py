from .disjoint import Disjoint
from .mesh import Mesh
from .field_list import FieldList

from ..base_node import BaseNode

class GroupFactory(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def build(self, data):
        '''Creates a group based on the 'type' field of the given dictionary'''

        if (data and data.get('type')):
            if (data['type'] == 'disjoint'):
                return Disjoint(data=data)
            elif (data['type'] == 'mesh'):
                return Mesh(data=data)
            elif (data['type'] == 'list'):
                return FieldList(data=data)

        return None

        