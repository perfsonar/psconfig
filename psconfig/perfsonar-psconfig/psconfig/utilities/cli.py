'''
Provides common utilities for CLI clients
'''
import psconfig.pscheduler.config_connect
import psconfig.transform_connect
import sys

PSCONFIG_CLI_AGENTS = [
    {
        'name': 'pScheduler',
        'config_file': '/etc/perfsonar/psconfig/pscheduler-agent.json',
        'command': '/usr/lib/perfsonar/psconfig/bin/psconfig_pscheduler_agent',
        'client_class': psconfig.pscheduler.config_connect.ConfigConnect,
        'agentctl_ignore': {
            "remotes": 1
        },
        'default_cache_dir': '/var/lib/perfsonar/psconfig/template_cache'
    }
]

class CLIUtil:

    def __init__(self, quiet=False):
        self.quiet = quiet

    '''
    helper method for printing argument errors not caught by argparse
    while still respecting --quiet
    '''
    def handle_arg_error(self, msg, parser, code=2):
        if self.quiet:
            sys.exit(code)
        else:
            parser.error(msg)

    def print_msg(self, msg):
        if not self.quiet:
            print(msg)

    def print_error(self, msg):
        if not self.quiet:
            print(msg, file=sys.stderr)

    def load_transform_config(self, config_file):
        transform_client = psconfig.transform_connect.TransformConnect()
        transform_client.url = config_file
        transform = transform_client.get_config()
        if(transform_client.error):
            self.print_error("Error reading default transform file: {}".format(transform_client.error))
            return

        transform_client_errors = transform.validate() 
        if transform_client_errors:
            err = "{} is not valid. The following errors were encountered: ".format(config_file)
            for error in transform_client_errors:
                err += "    JSON Path: " + error.path + '\n' 
                err += "    Error: " + error.message + '\n\n'   
            self.print_error(err)
            return
        
        return transform

    def load_agent_config(self, config_file, agent_conf_client):
        ##
        #Load config file
        agent_conf_client.url = config_file
        agent_conf_client.save_filename = config_file
        agent_conf = agent_conf_client.get_config() 
        if agent_conf_client.error:
            self.print_error("Error parsing {}: {}".format(config_file, agent_conf_client.error))
            return

        agent_conf_errors = agent_conf.validate() 
        if agent_conf_errors:
            err = "{} is not valid. The following errors were encountered: ".format(config_file)
            for error in agent_conf_errors:
                err += "    JSON Path: " + error.path + '\n' 
                err += "    Error: " + error.message + '\n\n'   
            self.print_error(err)
            return

        return agent_conf