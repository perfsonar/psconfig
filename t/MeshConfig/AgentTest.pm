package MeshConfig::AgentTest;

use base qw(Test::Unit::TestCase);

use perfSONAR_PS::MeshConfig::Agent;
 
sub new {
 	my $self = shift()->SUPER::new(@_);
	return $self;
}

sub test_agent {
	
	my $self = shift;
	my $agent = perfSONAR_PS::MeshConfig::Agent->new();

	$self->assert_not_null($agent);
	#$self->assert_equals('expected result', $obj->foo);
	#$self->assert(qr/pattern/, $obj->foobar);
	
}

1;	
