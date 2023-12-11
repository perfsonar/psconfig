'''
A client for interacting with psconfig
'''

from .base_connect import BaseConnect
from .config import Config as PSConfig
from .translators.mesh_config.config import Config

class ApiConnect(BaseConnect):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def config_obj(self):
        '''
        Return a client.psconfig.Config object
        '''
        return PSConfig()
    
    def translators(self):
        '''
        Returns a list of possible translators
        '''
        return [Config(use_force_bidirectional=True)]
    
    def needs_translation(self, json_obj):
        '''Indicates needs translation unless there is an addresses field or includes'''
        # optimization that looks for simple required field
        # proper way would be to validate, but expensive to do for just the MeshConfig
        if not (json_obj.get('addresses') or json_obj.get('includes')):
            return True
        
        return False
