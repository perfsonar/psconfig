package MeshConfigSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'Mesh config test suite' }

sub include_tests { qw(
						MeshConfig::Config::MeshTest
						MeshConfig::StatisticTest
						)
}

1;
