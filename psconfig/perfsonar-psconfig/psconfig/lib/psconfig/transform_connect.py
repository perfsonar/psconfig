'''
A client for reading in JQTransform files
'''

from ..shared.client.psconfig.base_connect import BaseConnect
from ..shared.client.psconfig.jq_transform import JQTransform

class TransformConnect(BaseConnect):

    def config_obj(self):
        '''return jqtransform object'''
        return JQTransform()
