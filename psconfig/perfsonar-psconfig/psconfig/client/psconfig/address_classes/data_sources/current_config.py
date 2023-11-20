from .base_data_source import BaseDataSource

class CurrentConfig(BaseDataSource):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.type = 'current-config'
        self.data['type'] = 'current-config'
        

    def fetch(self, psconfig):

        #make sure we have a config
        if not psconfig:
            return None
        
        return psconfig.addresses()
