use strict;
use warnings;

our $VERSION = 4.1;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;
use Data::Dumper;

use perfSONAR_PS::PSConfig::JQTransform;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::Config;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::VizDefaults;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::HttpGetOpt;

##
# Run with PERL_DL_NONLAZY=1 PERL5OPT=-MDevel::Cover /usr/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" t/maddash-viz-config.t
###

########
#Create initial config
########
my $vizconfig;
ok($vizconfig = new perfSONAR_PS::PSConfig::MaDDash::Visualization::Config());
is($vizconfig->json(), '{}');

## Set basic properties
is($vizconfig->type('ps-graphs'), 'ps-graphs');

## requires
my $requires;
ok($requires = new perfSONAR_PS::PSConfig::MaDDash::TaskSelector());
is($requires->test_type("throughput")->[0], "throughput");
is($vizconfig->requires($requires)->checksum(), $requires->checksum());

## defaults
my $viz_defaults;
ok($viz_defaults = new perfSONAR_PS::PSConfig::MaDDash::Visualization::VizDefaults());
is($viz_defaults->base_url("https://blah"), "https://blah");
is($viz_defaults->params({'tool' => 'iperf3'})->{'tool'}, 'iperf3');
is($viz_defaults->param('tool'), 'iperf3');
is($vizconfig->defaults($viz_defaults)->checksum(), $viz_defaults->checksum());

## vars
my $var1;
ok($var1 = new perfSONAR_PS::PSConfig::JQTransform());
ok($var1->script('.foo'));
my $var2;
ok($var2 = new perfSONAR_PS::PSConfig::JQTransform());
ok($var2->script('.bar'));
is($vizconfig->vars({'var1' => $var1})->{'var1'}->checksum(), $var1->checksum());
is($vizconfig->var('var1')->checksum(), $var1->checksum());
is($vizconfig->var('var2', $var2)->checksum(), $var2->checksum());
is(@{$vizconfig->var_names()}, 2);
ok($vizconfig->remove_var('var1'));
is(@{$vizconfig->var_names()}, 1);
### test variable expansion
is($vizconfig->expand_vars({})->{'var2'}, undef);
ok($var2->script('!!!')); #invalid
is($vizconfig->expand_vars({'bar' => 'soap'}), undef);
ok($vizconfig->error());
ok($var2->script('.bar'));
is($vizconfig->expand_vars({'bar' => 'soap'})->{'var2'}, 'soap');
ok(!$vizconfig->error());


## command_opts
my $getopt1;
ok($getopt1 = new perfSONAR_PS::PSConfig::MaDDash::Visualization::HttpGetOpt());
is($getopt1->condition('{% var1 %}'), '{% var1 %}');
is($getopt1->arg('{% var1 %}'), '{% var1 %}');
is($getopt1->required(1), 1);
my $getopt2;
ok($getopt2 = new perfSONAR_PS::PSConfig::MaDDash::Visualization::HttpGetOpt());
is($getopt2->condition('{% var2 %}'), '{% var2 %}');
is($getopt2->arg('{% var2 %}'), '{% var2 %}');
is($getopt2->required(0), 0);
is($vizconfig->http_get_opts({'v1' => $getopt1})->{'v1'}->checksum(), $getopt1->checksum());
is($vizconfig->http_get_opt('v1')->checksum(), $getopt1->checksum());
is($vizconfig->http_get_opt('v2', $getopt2)->checksum(), $getopt2->checksum());
is(@{$vizconfig->http_get_opt_names()}, 2);
ok($vizconfig->remove_http_get_opt('v1'));
is(@{$vizconfig->http_get_opt_names()}, 1);


########
#validate
########
is($vizconfig->validate(), 0); #no validation errors

########
#finish testing
########
done_testing();
