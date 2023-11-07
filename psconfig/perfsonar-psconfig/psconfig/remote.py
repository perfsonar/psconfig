from .client.psconfig.jq_transform import JQTransform
from .client.psconfig.base_node import BaseNode

class Remote(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def url(self, val=None):
        ''' Gets/ sets the URL of the json file to download'''
        return self._field_url('url', val)
    
    def configure_archives(self, val=None):
        ''' Gets/sets whether archives should be used from this remote file. Must be 0 or 1'''
        return self._field_bool_default_true('configure-archives', val)

    def bind_address(self, val=None):
        ''' Gets/ sets the local address (as string) to use when connecting to remote url'''
        return self._field_host('bind-address', val)
    
    def ssl_ca_file(self, val=None):
        ''' Gets/sets the typical certificate authority (CA) file found on BSD. Used to verify server SSL certificate when using https'''
        return self._field('ssl-ca-file', val)
    
    def transform(self, val=None):
        ''' Gets/sets JQTransform object with jq for transforming json before processing'''
        return self._field_class('transform', JQTransform, val)
