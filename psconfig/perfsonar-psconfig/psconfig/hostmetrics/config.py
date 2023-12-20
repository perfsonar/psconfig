from .schema import Schema
from ..base_agent import BaseAgentNode

class Config(BaseAgentNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.error = ''

    def schema(self):
        '''Returns the JSON schema for this config'''
        return Schema().psconfig_hostmetrics_json_schema()

    def address_pattern(self, val=None):
        return self._field('address-pattern', val)

    def node_exporter_url_format(self, val=None):
        return self._field('node-exporter-url-format', val)

    def pshost_exporter_url_format(self, val=None):
        return self._field('pshost-exporter-url-format', val)
    
    def template_file(self, val=None):
        return self._field('template-file', val)

    def output_file(self, val=None):
        return self._field('output-file', val)

    def restart_service(self, val=None):
        return self._field('restart-service', val)