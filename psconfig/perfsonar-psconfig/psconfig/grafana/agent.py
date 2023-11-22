'''Agent that loads config and submits to Grafana
'''
from ..client.psconfig.parsers.task_generator import TaskGenerator
from .config_connect import ConfigConnect
from ..base_agent import BaseAgent
import time
import logging
from ..utilities.logging_utils import LoggingUtils

class Agent(BaseAgent):
    '''Agent that loads config and submits to Grafana'''

    def __init__(self, **kwargs):
        super(Agent, self).__init__(**kwargs)
        self.logf = kwargs.get('logf', LoggingUtils())
        self.logger = logging.getLogger(__name__)
        self.task_logger = logging.getLogger('TaskLogger')
        self.transaction_logger = logging.getLogger('TransactionLogger')
    
    def _agent_name(self):
        return 'grafana'
    
    def _config_client(self):
        return ConfigConnect()
    
    def _init(self, agent_conf):
        print(agent_conf.display_names())

    def _run_start(self, agent_conf):
        ##
        # Set defaults for config values

        # Set cache directory per agent. Will not work to share since agents may
        #  have different permissions
        if not agent_conf.cache_directory():
            default = "/var/lib/perfsonar/psconfig/grafana_template_cache"
            self.logger.debug(self.logf.format("No cache-dir specified. Defaulting to {}".format(default)))
            agent_conf.cache_directory(default)

        return True
    
    def _run_handle_psconfig(self, psconfig, agent_conf, remote=None):
        pass

    def _run_end(self, agent_conf):
        pass

