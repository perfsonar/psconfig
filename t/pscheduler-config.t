use strict;
use warnings;

our $VERSION = 4.1;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;
use Data::Dumper;

use perfSONAR_PS::PSConfig::PScheduler::Config;
use perfSONAR_PS::PSConfig::Remote;

##
# Run with PERL_DL_NONLAZY=1 PERL5OPT=-MDevel::Cover /usr/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" t/pscheduler-config.t
###

########
#Create initial config
########
my $pscconfig;
ok($pscconfig = new perfSONAR_PS::PSConfig::PScheduler::Config());
is($pscconfig->json(), '{}');

##add remotes
is(@{$pscconfig->remotes()}, 0);
my $remote1;
ok($remote1 = new perfSONAR_PS::PSConfig::Remote());
is($remote1->url("foo.bar"), undef);
is($remote1->url("ftp://foo.bar"), undef);
is($remote1->url('file:///tmp/tmp'), 'file:///tmp/tmp');
is($remote1->url('http://&1'), undef);
is($remote1->url("https://127.0.0.1/example.json"), "https://127.0.0.1/example.json");
is($remote1->configure_archives(1), 1);
is($remote1->ssl_validate_certificate(1), 1);
is($remote1->ssl_ca_file('path/to/ca'), 'path/to/ca');
is($remote1->ssl_ca_path('path/to/ca'), 'path/to/ca');
is($remote1->transform({'script'=> 'foo.jq'})->{'script'}, 'foo.jq');
ok($pscconfig->add_remote($remote1));
is($pscconfig->remote(0)->url(), "https://127.0.0.1/example.json");
is($pscconfig->pscheduler_assist_server("127.0.0.1"), "127.0.0.1");
is($pscconfig->pscheduler_fail_attempts(5), 5);
is($pscconfig->match_addresses(), undef);
is($pscconfig->match_addresses("foo"), undef);
is($pscconfig->match_addresses(['&1']), undef);
ok($pscconfig->add_match_address('9.0.0.1'));
is($pscconfig->match_addresses(['10.0.0.1'])->[0], '10.0.0.1');
is($pscconfig->match_address(), undef);
is($pscconfig->match_address(0), '10.0.0.1');
is($pscconfig->match_address(1), undef);
is($pscconfig->match_address(0, '&1'), undef);
is($pscconfig->match_address(0, '11.0.0.1'), '11.0.0.1');
is($pscconfig->add_match_address(), undef);
is($pscconfig->add_match_address('&1'), undef);
ok($pscconfig->add_match_address("fe80::1"), "fe80::1");
is(@{$pscconfig->match_addresses()}, 2);
is($pscconfig->match_address(1), "fe80::1");
is($pscconfig->include_directory('/etc/psconfig/pscheduler.d'), '/etc/psconfig/pscheduler.d');
is($pscconfig->archive_directory('/etc/psconfig/archives.d'), '/etc/psconfig/archives.d');
is($pscconfig->requesting_agent_file('/etc/psconfig/requesting_agent.json'), '/etc/psconfig/requesting_agent.json');
is($pscconfig->client_uuid_file('/var/lib/psconfig/client_uuid'), '/var/lib/psconfig/client_uuid');
is($pscconfig->pscheduler_tracker_file('/var/lib/psconfig/psc_tracker'), '/var/lib/psconfig/psc_tracker');
is($pscconfig->check_interval('PT1H'), 'PT1H');
is($pscconfig->check_config_interval('PT60S'), 'PT60S');
is($pscconfig->task_min_ttl('P1D'), 'P1D');
is($pscconfig->task_min_runs(2), 2);
is($pscconfig->task_renewal_fudge_factor(.25), .25);
is($pscconfig->task_renewal_fudge_factor(), .25);
is($pscconfig->task_renewal_fudge_factor(-1), undef);
is($pscconfig->task_renewal_fudge_factor(1.1), undef);

########
#validate
########
is($pscconfig->validate(), 0); #no validation errors

########
#finish testing
########
done_testing();
