'''
Provides common utilities for CLI clients
'''
import psconfig.pscheduler.config_connect
import psconfig.transform_connect
import sys
from tqdm import tqdm
from jsonschema import ValidationError

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
            self.print_error("{} is not valid. The following errors were encountered: ".format(config_file))
            self.print_validation_error(transform_client_errors)
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
            self.print_error("{} is not valid. The following errors were encountered: ".format(config_file))
            self.print_validation_error(agent_conf_errors)
            return

        return agent_conf

    def print_validation_error(self, errors):
        for error in errors:
            if isinstance(error, ValidationError):
                if error.path:
                    self.print_error("\n    JSON Path: {}".format("/".join(error.path)))
                self.print_error("    Error: {}".format(error.message))
            else:
                self.print_error("\n    {}".format(str(error)))


'''
Progress Bar for CLIs. Disabled in quiet mode.
Wrap tqdm - see https://tqdm.github.io/docs/tqdm
'''
class CLIProgressBar:

    def __init__(self, msg="", total=100, quiet=False, bar_format="{l_bar}{bar}[{elapsed}<{remaining}]"):
        self.quiet = quiet
        if not quiet:
            self.pb = tqdm(desc=msg, total=total, bar_format=bar_format)
        else:
            self.pb = None

    def update(self, n):
        if self.pb:
            self.pb.update(n)

    def close(self):
        if self.pb:
            self.pb.close()

'''
Common colors and style characters used on the terminal
'''
class CLITextStyles:
    OKGREEN = '\033[92m'
    FAIL = '\033[91m'
    BOLD = '\033[1m'
    RESET = '\033[0m'

'''
Displays result of a stage as a row
Example: MESSGAGE ..... STATUS
'''
class CLIStatusRow:

    def __init__(self, msg="", quiet=False, separator=" ...... "):
        self.quiet = quiet
        if not quiet:
            print("{}{}".format(msg, separator), end="")

    def ok(self):
        if not self.quiet:
            print("{}{}OK{}".format(CLITextStyles.BOLD, CLITextStyles.OKGREEN, CLITextStyles.RESET))

    def fail(self):
        if not self.quiet:
            print("{}{}FAIL{}".format(CLITextStyles.BOLD, CLITextStyles.FAIL, CLITextStyles.RESET))