from .address_class import AddressClass
#from .operand_and import OperandAnd

operand_and = __import__("operand_and", globals(), locals(), fromlist=['OperandAnd'], level=1)
OperandAnd = operand_and.OperandAnd

from .host import Host
from .ip_version import IPVersion
from .jq import JQ
from .netmask import NetMask
from .operand_not import OperandNot
from .operand_or import OperandOr
from .tag import Tag
from ...base_node import BaseNode

class FilterFactory(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def build(self, data):
        '''creates a filter based on the 'type' field of the given dictionary'''

        if (data and data.get('type')):
            if data['type'] == 'address-class':
                return AddressClass(data=data)
            elif data['type'] == 'and':
                return OperandAnd(data=data)
            elif data['type'] == 'host':
                return Host(data=data)
            elif data['type'] == 'ip-version':
                return IPVersion(data=data)
            elif data['type'] == 'jq':
                return JQ(data=data)
            elif data['type'] == 'netmask':
                return NetMask(data=data)
            elif data['type'] == 'not':
                return OperandNot(data=data)
            elif data['type'] == 'or':
                return OperandOr(data=data)
            elif data['type'] == 'tag':
                return Tag(data=data)
        
        return None
