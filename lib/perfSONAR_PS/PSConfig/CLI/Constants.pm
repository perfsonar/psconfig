package perfSONAR_PS::PSConfig::CLI::Constants;


use strict;
use warnings;

use perfSONAR_PS::PSConfig::PScheduler::ConfigConnect;
use perfSONAR_PS::PSConfig::MaDDash::Agent::ConfigConnect;

use constant {
    CLI_AGENTS => [
        {
            name => 'pScheduler',
            config_file => '/etc/perfsonar/psconfig/pscheduler-agent.json',
            client_class => 'perfSONAR_PS::PSConfig::PScheduler::ConfigConnect'
        },
        {
            name => 'MaDDash',
            config_file => '/etc/perfsonar/psconfig/maddash-agent.json',
            client_class => 'perfSONAR_PS::PSConfig::MaDDash::Agent::ConfigConnect'
        }
    ]
};

1;