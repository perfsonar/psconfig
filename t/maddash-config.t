use strict;
use warnings;

our $VERSION = 4.1;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;
use Data::Dumper;

use perfSONAR_PS::PSConfig::JQTransform;
use perfSONAR_PS::PSConfig::MaDDash::Agent::Config;
use perfSONAR_PS::PSConfig::MaDDash::Agent::Grid;
use perfSONAR_PS::PSConfig::Remote;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;
use perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig;
use perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig;
use perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority;

##
# Run with PERL_DL_NONLAZY=1 PERL5OPT=-MDevel::Cover /usr/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" t/maddash-config.t
###

########
#Create initial config
########
my $pscconfig;
ok($pscconfig = new perfSONAR_PS::PSConfig::MaDDash::Agent::Config());
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
is($remote1->bind_address('10.0.0.1'), '10.0.0.1');
is($remote1->configure_archives(1), 1);
is($remote1->ssl_ca_file('path/to/ca'), 'path/to/ca');
my $transform;
ok($transform = new perfSONAR_PS::PSConfig::JQTransform());
is($transform->script(['junk;jq'])->[0], 'junk;jq');
is($transform->apply({"foo" => "bar"}), undef);
ok($transform->error());
is($transform->script('.foo')->[0], '.foo');
is($transform->script()->[0], '.foo');
is($transform->apply({"foo" => "bar"}), "bar");
is($transform->validate(), 0);
is($remote1->transform($transform)->checksum(), $transform->checksum());
ok($pscconfig->add_remote($remote1));
is($pscconfig->remote(0)->url(), "https://127.0.0.1/example.json");

## try other properties
is($pscconfig->check_plugin_directory('/usr/lib/perfsonar/psconfig/checks'), '/usr/lib/perfsonar/psconfig/checks');
is($pscconfig->visualization_plugin_directory('/usr/lib/perfsonar/psconfig/visualizations'), '/usr/lib/perfsonar/psconfig/visualizations');
is($pscconfig->maddash_yaml_file('/etc/maddash/maddash-server/maddash.yaml'), '/etc/maddash/maddash-server/maddash.yaml');
is($pscconfig->pscheduler_assist_server("127.0.0.1"), "127.0.0.1");
is($pscconfig->include_directory('/etc/perfsonar/psconfig/maddash.d'), '/etc/perfsonar/psconfig/maddash.d');
is($pscconfig->archive_directory('/etc/perfsonar/psconfig/archives.d'), '/etc/perfsonar/psconfig/archives.d');
is($pscconfig->transform_directory('/etc/perfsonar/psconfig/transforms.d'), '/etc/perfsonar/psconfig/transforms.d');
is($pscconfig->requesting_agent_file('/etc/perfsonar/psconfig/requesting_agent.json'), '/etc/perfsonar/psconfig/requesting_agent.json');
is($pscconfig->check_interval('PT1H'), 'PT1H');
is($pscconfig->check_config_interval('PT60S'), 'PT60S');

## grids
my $grid1;
ok($grid1 = new perfSONAR_PS::PSConfig::MaDDash::Agent::Grid());
#empty cases
is(keys %{$pscconfig->grids()}, 0);
is(keys %{$pscconfig->grids({})}, 0);
is($pscconfig->grid('blah'), undef);
is(@{$pscconfig->grid_names()}, 0);
is($pscconfig->remove_grid('blah'), undef);

## add a grid
is($grid1->display_name("Example Grid"), "Example Grid");
is($pscconfig->grid('example', $grid1)->checksum(), $grid1->checksum());
### task selector
my $task_sel;
ok($task_sel = new perfSONAR_PS::PSConfig::MaDDash::TaskSelector());
#### test type
is($task_sel->matches({}), 1);
ok($task_sel->test_type([]));
is($task_sel->matches({}), 1);
is($task_sel->test_type("throughput")->[0], "throughput");
ok($task_sel->add_test_type("latencybg"));
is($task_sel->test_type()->[1], "latencybg");
is(@{$task_sel->test_type()}, 2);
is($task_sel->matches({'test' => {}}), undef);
is($task_sel->matches({'test' => {'type' => 'rtt'}}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput'}}), 1);
#### task name
ok($task_sel->task_name([]));
is($task_sel->matches({'test' => {'type' => 'throughput'}}), 1);
is($task_sel->task_name("task1")->[0], "task1");
ok($task_sel->add_task_name("task2"));
is($task_sel->task_name()->[1], "task2");
is(@{$task_sel->task_name()}, 2);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'blah'}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name'=> 'task1'}), 1);
#### archive type
ok($task_sel->archive_type([]));
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name'=> 'task1'}), 1);
is($task_sel->archive_type("esmond")->[0], "esmond");
ok($task_sel->add_archive_type("rabbitmq"));
is($task_sel->archive_type()->[1], "rabbitmq");
is(@{$task_sel->archive_type()}, 2);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'task1', 'archives' => []}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'task1', 'archives' => [{}]}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'task1', 'archives' => [{"archiver"=> 'blah'}]}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'task1', 'archives' => [{"archiver"=> 'rabbitmq'}]}), 1);
#### jq
my $task_sel_jq;
ok($task_sel_jq = new perfSONAR_PS::PSConfig::JQTransform());
ok($task_sel_jq->script('.test._meta.foo'));
is($task_sel->jq($task_sel_jq)->checksum(), $task_sel_jq->checksum());
is($grid1->selector($task_sel)->checksum(), $task_sel->checksum());
#### task selector matches testing - make sure everthing works once we have full shebang
is($task_sel->matches(), undef);
is($task_sel->matches({}), undef);
is($task_sel->matches({'test' => {'type' => 'rtt'}}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput'}}), undef);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'blah'}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'task1'}), undef);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'task1', 'archives' => [{"archiver"=> 'blah'}]}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput'}, 'task-name' => 'task1', 'archives' => [{"archiver"=> 'rabbitmq'}]}), 0);
is($task_sel->matches({'test' => {'type' => 'throughput', '_meta'=>{'foo' => 'bar'}}, 'task-name' => 'task1', 'archives' => [{"archiver"=> 'rabbitmq'}]}), 1);

### check config
my $check_config;
ok($check_config = new perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig());
is($check_config->type("ps-nagios-throughput"), "ps-nagios-throughput");
my $archive_sel;
ok($archive_sel = new perfSONAR_PS::PSConfig::JQTransform());
ok($archive_sel->script('.'));
is($check_config->archive_selector($archive_sel)->checksum(), $archive_sel->checksum());
is($check_config->check_interval("PT4H"), "PT4H");
is($check_config->warning_threshold("1"), "1");
is($check_config->critical_threshold(".5"), ".5");
is($check_config->report_yaml_file("file.yaml"), "file.yaml");
is($check_config->retry_interval("PT5M"), "PT5M");
is($check_config->retry_attempts(1), 1);
is($check_config->timeout("PT60S"), "PT60S");
is($check_config->params({'tool' => 'iperf3'})->{'tool'}, 'iperf3');
is($check_config->param('tool'), 'iperf3');
is($grid1->check($check_config)->checksum(), $check_config->checksum());
### viz config
my $viz_config;
ok($viz_config = new perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig());
is($viz_config->type("ps-graphs"), "ps-graphs");
is($viz_config->base_url("http://blah"), "http://blah");
is($viz_config->params({'tool' => 'iperf3'})->{'tool'}, 'iperf3');
is($viz_config->param('tool'), 'iperf3');
is($grid1->visualization($viz_config)->checksum(), $viz_config->checksum());
### priority
my $grid_prio;
ok($grid_prio = new perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority());
is($grid_prio->level(1), 1);
is($grid_prio->group("examplegrp"), "examplegrp");
is($grid1->priority($grid_prio)->checksum(), $grid_prio->checksum());


########
#validate
########
is($pscconfig->validate(), 0); #no validation errors

########
#finish testing
########
done_testing();
