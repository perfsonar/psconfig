from .disjoint import Disjoint
from .mesh import Mesh
from .field_list import FieldList

from ..base_node import BaseNode

class GroupFactory(BaseNode):

    def build(self, data):
        '''Creates a group based on the 'type' field of the given dictionary'''

        if (data and data.get('type')):
            if (isinstance(data['type'], Disjoint)):
                return Disjoint(data=data)
            elif (isinstance(data['type'], Mesh)):
                return Mesh(data=data)
            elif (isinstance(data['type'], FieldList)):
                return FieldList(data=data)

        return None

        