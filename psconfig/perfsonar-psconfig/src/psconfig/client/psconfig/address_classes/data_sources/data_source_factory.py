from .current_config import CurrentConfig
from .requesting_agent import RequestingAgent

from ...base_node import BaseNode

class DataSourceFactory(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def build(self, data):
        '''Creates a data source based on the 'type' field of the given HshRef'''

        if (data and data.get('type')):
            if data['type'] == 'current-config':
                return CurrentConfig(data=data)
            elif data['type'] == 'requesting-agent':
                return RequestingAgent(data=data)

        return None
