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

    def _run_start(self, agent_conf):
        ##
        # This runs at the beginning of each iteration before pulling down pSConfig templates

        ## Set defaults
        if agent_conf.grafana_url() and not (agent_conf.grafana_token() or (agent_conf.grafana_user() and agent_conf.grafana_password())):
            default = "https://localhost/grafana"
            self.logger.warn(self.logf.format("No grafana-token or grafana-user/grafana-password specified. Unless your grafana instance does not require authentication, then your attempts to create dashboards may fail ".format(default)))

        if not agent_conf.grafana_url():
            default = "https://localhost/grafana"
            self.logger.debug(self.logf.format("No grafana-url specified. Defaulting to {}".format(default)))
            agent_conf.grafana_url(default)
        self.grafana_url = agent_conf.grafana_url()
        self.grafana_token = agent_conf.grafana_token()
        self.grafana_user = agent_conf.grafana_user()
        self.grafana_password = agent_conf.grafana_password()

        if not agent_conf.grafana_folder():
            default = "General"
            self.logger.debug(self.logf.format("No grafana-folder specified. Defaulting to {}".format(default)))
            agent_conf.grafana_folder(default)
        self.grafana_folder = agent_conf.grafana_folder()

        if not agent_conf.grafana_matrix_url():
            #This is the standard endpoint pair dashboard
            default = "/grafana/d/c5ce2fcb-e7f9-4aaf-b16d-0bc008a6e6f9/esnet-endpoint-pair-explorer?orgId=1"
            self.logger.debug(self.logf.format("No grafana-matrix-url specified. Defaulting to {}".format(default)))
            agent_conf.grafana_matrix_url(default)
        self.grafana_matrix_url = agent_conf.grafana_matrix_url()

        if not agent_conf.grafana_matrix_url_var1():
            #This is the standard endpoint pair dashboard
            default = "source"
            self.logger.debug(self.logf.format("No grafana-matrix-url-var1 specified. Defaulting to {}".format(default)))
            agent_conf.grafana_matrix_url_var1(default)
        self.grafana_matrix_url_var1 = agent_conf.grafana_matrix_url_var1()

        if not agent_conf.grafana_matrix_url_var2():
            #This is the standard endpoint pair dashboard
            default = "target"
            self.logger.debug(self.logf.format("No grafana-matrix-url-var2 specified. Defaulting to {}".format(default)))
            agent_conf.grafana_matrix_url_var2(default)
        self.grafana_matrix_url_var2 = agent_conf.grafana_matrix_url_var2()

        if not agent_conf.grafana_datasource_type():
            #This is the standard endpoint pair dashboard
            default = "grafana-opensearch-datasource"
            self.logger.debug(self.logf.format("No grafana-datasource-type specified. Defaulting to {}".format(default)))
            agent_conf.grafana_datasource_type(default)
        self.grafana_datasource_type = agent_conf.grafana_datasource_type()
        self.grafana_datasource_create = agent_conf.grafana_datasource_create()

        #  Set cache directory per agent. Will not work to share since agents may
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

