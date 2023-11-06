from .maintainer import Maintainer
from .base_node import BaseNode

class Test(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def name(self, val=None):
        if val is not None:
            self.data['name'] = val
        
        return self.data.get('name', None)
    
    def version(self, val=None):
        if val is not None:
            self.data['version'] = val
        return self.data.get('version', None)
    
    def description(self, val=None):
        if val is not None:
            self.data['description'] = val
        return self.data.get('description', None)
    
    def maintainer(self, val=None):
        if val is not None:
            self.data['maintainer'] = {}
            self.data['maintainer']['href'] = val.href 
            self.data['maintainer']['name'] = val.name
            self.data['maintainer']['email'] = val.email

        if 'maintainer' not in self.data:
            return None
        
        return Maintainer(href=self.data['maintainer'].get('href'),\
            email=self.data['maintainer'].get('email'),\
                name=self.data['maintainer'].get('name'))  
    
    def scheduling_class(self, val=None):
        if val is not None:
            self.data['scheduling_class'] = val
        
        return self.data.get('scheduling_class', None)
    

            

