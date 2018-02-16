use strict;
use warnings;

our $VERSION = 4.1;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;
use Data::Dumper;

use perfSONAR_PS::PSConfig::JQTransform;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;
use perfSONAR_PS::PSConfig::MaDDash::Checks::Config;
use perfSONAR_PS::PSConfig::MaDDash::Checks::CheckDefaults;
use perfSONAR_PS::PSConfig::MaDDash::Checks::CommandOpt;
use perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabels;
use perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabelsExtra;

##
# Run with PERL_DL_NONLAZY=1 PERL5OPT=-MDevel::Cover /usr/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" t/maddash-check-config.t
###

########
#Create initial config
########
my $chkconfig;
ok($chkconfig = new perfSONAR_PS::PSConfig::MaDDash::Checks::Config());
is($chkconfig->json(), '{}');

## Set basic properties
is($chkconfig->type('ps-nagios-throughput'), 'ps-nagios-throughput');
is($chkconfig->name('Throughput'), 'Throughput');
is($chkconfig->description("Finds some throughput y'all"), "Finds some throughput y'all");
is($chkconfig->command("/path/check_throughput.pl"), "/path/check_throughput.pl");
is($chkconfig->command("/path/check_throughput.pl"), "/path/check_throughput.pl");
is($chkconfig->command_args(["arg1"])->[0], "arg1");
ok($chkconfig->add_command_arg("arg2"));
is($chkconfig->command_args()->[1], "arg2");
is(@{$chkconfig->command_args()}, 2);

## requires
my $requires;
ok($requires = new perfSONAR_PS::PSConfig::MaDDash::TaskSelector());
is($requires->test_type("throughput")->[0], "throughput");
is($chkconfig->requires($requires)->checksum(), $requires->checksum());

## archive_accessor
my $archive_accessor;
ok($archive_accessor = new perfSONAR_PS::PSConfig::JQTransform());
ok($archive_accessor->script('.url'));
is($chkconfig->archive_accessor($archive_accessor)->checksum(), $archive_accessor->checksum());

## status labels
my $status_labels;
ok($status_labels = new perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabels());
is($status_labels->ok("Yeah"), "Yeah");
is($status_labels->warning("Uhh"), "Uhh");
is($status_labels->critical("Ahhh"), "Ahhh");
is($status_labels->notrun("Meh"), "Meh");
is($status_labels->unknown("Huh"), "Huh");
my $extra;
ok($extra = new perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabelsExtra());
is($extra->value(7), 7);
is($extra->short_name('Ugh'), 'Ugh');
is($extra->description('Ugggghhhhh'), 'Ugggghhhhh');
is($status_labels->extra([$extra])->[0]->checksum(), $extra->checksum());
is($status_labels->extra_label(0)->checksum(), $extra->checksum());
is($chkconfig->status_labels($status_labels)->checksum(), $status_labels->checksum());

## defaults
my $check_defaults;
ok($check_defaults = new perfSONAR_PS::PSConfig::MaDDash::Checks::CheckDefaults());
is($check_defaults->check_interval("PT4H"), "PT4H");
is($check_defaults->warning_threshold("1"), "1");
is($check_defaults->critical_threshold(".5"), ".5");
is($check_defaults->report_yaml_file("file.yaml"), "file.yaml");
is($check_defaults->retry_interval("PT5M"), "PT5M");
is($check_defaults->retry_attempts(1), 1);
is($check_defaults->timeout("PT60S"), "PT60S");
is($check_defaults->params({'tool' => 'iperf3'})->{'tool'}, 'iperf3');
is($check_defaults->param('tool'), 'iperf3');
is($chkconfig->defaults($check_defaults)->checksum(), $check_defaults->checksum());

## vars
my $var1;
ok($var1 = new perfSONAR_PS::PSConfig::JQTransform());
ok($var1->script('.foo'));
my $var2;
ok($var2 = new perfSONAR_PS::PSConfig::JQTransform());
ok($var2->script('.bar'));
is($chkconfig->vars({'var1' => $var1})->{'var1'}->checksum(), $var1->checksum());
is($chkconfig->var('var1')->checksum(), $var1->checksum());
is($chkconfig->var('var2', $var2)->checksum(), $var2->checksum());
is(@{$chkconfig->var_names()}, 2);
ok($chkconfig->remove_var('var1'));
is(@{$chkconfig->var_names()}, 1);
### test variable expansion
is($chkconfig->expand_vars({})->{'var2'}, undef);
ok($var2->script('!!!')); #invalid
is($chkconfig->expand_vars({'bar' => 'soap'}), undef);
ok($chkconfig->error());
ok($var2->script('.bar'));
is($chkconfig->expand_vars({'bar' => 'soap'})->{'var2'}, 'soap');
ok(!$chkconfig->error());

## command_opts
my $cmdopt1;
ok($cmdopt1 = new perfSONAR_PS::PSConfig::MaDDash::Checks::CommandOpt());
is($cmdopt1->condition('{% var1 %}'), '{% var1 %}');
is($cmdopt1->arg('{% var1 %}'), '{% var1 %}');
is($cmdopt1->required(1), 1);
my $cmdopt2;
ok($cmdopt2 = new perfSONAR_PS::PSConfig::MaDDash::Checks::CommandOpt());
is($cmdopt2->condition('{% var2 %}'), '{% var2 %}');
is($cmdopt2->required(0), 0);
is($chkconfig->command_opts({'--v1' => $cmdopt1})->{'--v1'}->checksum(), $cmdopt1->checksum());
is($chkconfig->command_opt('--v1')->checksum(), $cmdopt1->checksum());
is($chkconfig->command_opt('--v2', $cmdopt2)->checksum(), $cmdopt2->checksum());
is(@{$chkconfig->command_opt_names()}, 2);
ok($chkconfig->remove_command_opt('--v1'));
is(@{$chkconfig->command_opt_names()}, 1);


########
#validate
########
is($chkconfig->validate(), 0); #no validation errors

########
#finish testing
########
done_testing();
