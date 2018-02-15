package perfSONAR_PS::PSConfig::CLI::Constants;


use strict;
use warnings;

use constant {
    CLI_AGENTS => [
        {
            name => 'pScheduler',
            config_file => '/etc/perfsonar/psconfig/pscheduler-agent.json',
            command => '/usr/lib/perfsonar/psconfig/bin/psconfig_pscheduler_agent',
            client_class => 'perfSONAR_PS::PSConfig::PScheduler::ConfigConnect'
        },
        {
            name => 'MaDDash',
            config_file => '/etc/perfsonar/psconfig/maddash-agent.json',
            command => '/usr/lib/perfsonar/psconfig/bin/psconfig_maddash_agent',
            client_class => 'perfSONAR_PS::PSConfig::MaDDash::Agent::ConfigConnect'
        }
    ]
};

1;