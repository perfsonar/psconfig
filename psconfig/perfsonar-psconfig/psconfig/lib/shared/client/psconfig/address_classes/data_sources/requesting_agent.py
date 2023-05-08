from .base_data_source import BaseDataSource

class RequestingAgent(BaseDataSource):

    def __init__(self):
        self.type = 'requesting-agent'
        self.data['type'] = 'requesting-agent'

    
    def fetch(self, psconfig):
        '''Accepts a config object and return HashRef of Address objects from requesting agent'''

        #make sure we have a config
        if not psconfig:
            return None

        return psconfig.requesting_agent_addresses()
