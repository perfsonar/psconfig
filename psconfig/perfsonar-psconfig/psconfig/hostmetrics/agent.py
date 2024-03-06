'''Agent that loads config and submits to Grafana
'''
import logging
import hashlib
import os
import re
import subprocess
from .config_connect import ConfigConnect
from ..base_agent import BaseAgent
from ..utilities.logging_utils import LoggingUtils
from jinja2 import Environment, FileSystemLoader


class Agent(BaseAgent):
    '''Agent that loads config and generates logstash config'''
    
    PSCONFIG_KEY_NODE_EXPORTER_URL = "node-exporter-url"
    PSCONFIG_KEY_PSHOST_EXPORTER_URL = "pshost-exporter-url"
    DEFAULT_NODE_EXPORTER_URL_FORMAT = "https://{}/node_exporter/metrics"
    DEFAULT_HOST_METRIC_EXPORTER_URL_FORMAT = "https://{}/perfsonar_host_exporter"

    def __init__(self, **kwargs):
        super(Agent, self).__init__(**kwargs)
        self.logf = kwargs.get('logf', LoggingUtils())
        self.logger = logging.getLogger(__name__)

    def _agent_name(self):
        return 'hostmetrics'
    
    def _config_client(self):
        return ConfigConnect()

    def _run_start(self, agent_conf):
        ##
        # This runs at the beginning of each iteration before pulling down pSConfig templates

        ## Set defaults

        ##
        #  Set cache directory per agent. Will not work to share since agents may
        #  have different permissions
        if not agent_conf.cache_directory():
            default = "/var/lib/perfsonar/psconfig/hostmetrics_template_cache"
            self.logger.debug(self.logf.format("No cache-dir specified. Defaulting to {}".format(default)))
            agent_conf.cache_directory(default)

        ##
        # Set defaults
        if not agent_conf.node_exporter_url_format():
            default = self.DEFAULT_NODE_EXPORTER_URL_FORMAT
            self.logger.debug(self.logf.format("No node-exporter-url-format specified. Defaulting to {}".format(default)))
            agent_conf.node_exporter_url_format(default)
        if not agent_conf.pshost_exporter_url_format():
            default = self.DEFAULT_HOST_METRIC_EXPORTER_URL_FORMAT
            self.logger.debug(self.logf.format("No pshost-exporter-url-format specified. Defaulting to {}".format(default)))
            agent_conf.pshost_exporter_url_format(default)

        ##
        # Build regex 
        self.address_regex = None
        if agent_conf.address_pattern():
            try:
                self.address_regex = re.compile(agent_conf.address_pattern())
            except:
                self.logger.error(self.logf.format("Unable to parse regex of address pattern {}".format(agent_conf.address_pattern())))
                return False

        ##
        # Load jinja template
        if not agent_conf.template_file():
            self.logger.error(self.logf.format("No template-file specified. Unable to build config without template."))
            return False
        j2_environment = Environment(loader=FileSystemLoader(os.path.dirname(agent_conf.template_file())))            
        self.template = j2_environment.get_template(os.path.basename(agent_conf.template_file()))


        # Init state used for building address list
        self.host_map = {}
        self.matching_addr_map = {}

        return True
    
    def _run_handle_psconfig(self, psconfig, agent_conf, remote=None):
        
        for addr_name in psconfig.address_names():
            addr_obj = psconfig.address(addr_name)
            address = addr_obj.address()
            #Skip no-agent
            if addr_obj.no_agent():
                continue
            #already seen address then skip
            if self.matching_addr_map.get(address, None):
                continue
            #already seen host then skip
            if addr_obj.host_ref() and self.host_map.get(addr_obj.host_ref(), None):
                continue
            #check address pattern
            if self.address_regex and not self.address_regex.search(address):
                continue
            
            
            #Determine url to exporters
            node_exporter_url = addr_obj.psconfig_meta_param(self.PSCONFIG_KEY_NODE_EXPORTER_URL)
            pshost_exporter_url = addr_obj.psconfig_meta_param(self.PSCONFIG_KEY_PSHOST_EXPORTER_URL)
            if not node_exporter_url:
                node_exporter_url = agent_conf.node_exporter_url_format().format(address)
            if not pshost_exporter_url:
                pshost_exporter_url = agent_conf.pshost_exporter_url_format().format(address)
            
            #save address
            self.matching_addr_map[address] = {
                "address": address,
                "node_exporter_url": node_exporter_url,
                "pshost_exporter_url": pshost_exporter_url
            }
            if addr_obj.host_ref():
                self.host_map[addr_obj.host_ref()] = address

    def _run_end(self, agent_conf):
        '''
        Runs when done processing all pSConfig files
        '''
        # Build jinja template
        rendered_content = self.template.render({
            "addresses": self.matching_addr_map
        })
        
        # Calculate file checksums
        new_file_checksum = hashlib.md5(rendered_content.encode('utf-8')).hexdigest()
        old_file_checksum = ""
        if os.path.exists(agent_conf.output_file()):
            with open(agent_conf.output_file(), 'r') as old_file:
                old_content = old_file.read()  
                old_file_checksum = hashlib.md5(old_content.encode('utf-8')).hexdigest()
        #Save file if different
        if not old_file_checksum or new_file_checksum != old_file_checksum:
            with open(agent_conf.output_file(), 'w') as output_file:
                output_file.write(rendered_content)
            self.logger.debug(self.logf.format("File saved", {
                "old_file_checksum": old_file_checksum,
                "new_file_checksum": new_file_checksum,
                "output_file": agent_conf.output_file()
            }))
            # Restart service
            if agent_conf.restart_service():
                restart_result = subprocess.run(["sudo", "systemctl", "restart", agent_conf.restart_service()])
                if restart_result.returncode == 0:
                    self.logger.debug(self.logf.format("Service {} restarted".format(agent_conf.restart_service())))
                else:
                    self.logger.warn(self.logf.format("Service {} restart attempt failed".format(agent_conf.restart_service())))
        else:
            self.logger.debug(self.logf.format("No changes so file not updated.", {
                "old_file_checksum": old_file_checksum,
                "new_file_checksum": new_file_checksum,
                "output_file": agent_conf.output_file()
            }))