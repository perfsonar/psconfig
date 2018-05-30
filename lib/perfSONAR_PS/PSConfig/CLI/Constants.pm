package perfSONAR_PS::PSConfig::CLI::Constants;


use strict;
use warnings;

##
# Add this ro make sure imports happen in correct order on Debian 8 and Ubuntu 14.
# If we don't add this then some command will complain about handling boolean values.
use perfSONAR_PS::Client::Utils;

use constant {
    CLI_AGENTS => [
        {
            name => 'pScheduler',
            config_file => '/etc/perfsonar/psconfig/pscheduler-agent.json',
            command => '/usr/lib/perfsonar/bin/psconfig_pscheduler_agent',
            client_class => 'perfSONAR_PS::PSConfig::PScheduler::ConfigConnect'
        },
        {
            name => 'MaDDash',
            config_file => '/etc/perfsonar/psconfig/maddash-agent.json',
            command => '/usr/lib/perfsonar/bin/psconfig_maddash_agent',
            client_class => 'perfSONAR_PS::PSConfig::MaDDash::Agent::ConfigConnect'
        }
    ]
};

1;