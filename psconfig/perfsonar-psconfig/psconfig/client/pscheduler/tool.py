from .maintainer import Maintainer
from .base_node import BaseNode

class Tool(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
    def name(self, val=None):
        if val is not None:
            self.data['name'] = val
        return self.data.get('name', None)
    
    def version(self, val=None):
        if val is not None:
            self.data['version'] =val
        return self.data.get('version', None)
    
    def description(self, val=None):
        if val is not None:
            self.data['description'] = val
        return self.data.get('description', None)
    
    def preference(self, val=None):
        if val is not None:
            self.data['preference'] = val
        return self.data.get('preference', None)
    
    def test_names(self, val=None):
        if val is not None:
            self.data['tests'] = val
        return self.data.get('tests', None)
    
    def maintainer(self, val=None):
        if val is not None:
            self.data['maintainer'] = {}
            self.data['maintainer']['href'] = val.href 
            self.data['maintainer']['name'] = val.name
            self.data['maintainer']['email'] = val.email
        
        try:
            return Maintainer(
                href=self.data['maintainer']['href'],
                email=self.data['maintainer']['email'],
                name=self.data['maintainer']['name']
            )
        except KeyError:
            return None
