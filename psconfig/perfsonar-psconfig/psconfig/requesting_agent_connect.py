'''
A client for reading in requesting agent files
'''

from .client.psconfig.base_connect import BaseConnect
from .requesting_agent_config import RequestingAgentConfig

class RequestingAgentConnect(BaseConnect):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def config_obj(self):
        #return requesting agent config object
        return RequestingAgentConfig()

