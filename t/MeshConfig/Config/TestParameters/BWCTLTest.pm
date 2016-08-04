package MeshConfig::Config::TestParameters::BWCTLTest;
=head1 NAME

	MeshConfig::Config::TestParameters::BWCTLTest
	
=head1 DESCRIPTION

	Check the PerfSONARBUOYBwctl class
	
=cut
	
use base qw(Test::Unit::TestCase);
use JSON;
use Cwd 'abs_path';

use perfSONAR_PS::MeshConfig::Config::TestParameters::PerfSONARBUOYBwctl;
use perfSONAR_PS::MeshConfig::Utils qw(load_mesh);

my $mesh_file = "json/mesh-with-time-slot.json";

sub new {
        my $self = shift()->SUPER::new(@_);
        my ($status, $res) = load_mesh({ configuration_url => "file://". abs_path($mesh_file) });
		if ($status != 0) {
			die;
		}
		$self->{meshes} = $res;
        return $self;
}

sub set_up{
	my $self = shift;
	my @time_slots = ('01:00', '05:00');
	$self->{description} = ();
	$self->{description}{protocol} = 'tcp';
	$self->{description}{tool} = 'bwctl/iperf3';
	$self->{description}{type} = 'perfsonarbuoy/bwctl';
	$self->{description}{duration} = '20';
	$self->{description}{interval} = '14400';
	$self->{description}{time_slots} = \@time_slots;
	
	$self->{object} = perfSONAR_PS::MeshConfig::Config::TestParameters::PerfSONARBUOYBwctl->parse($self->{description});
}

=head2 Test : test_init_object

        Check the object creation of class
        
=cut
sub test_init_object {
	my  $self = shift;
	$self->assert_not_null($self->{object});
}

=head2 Test : test_parameters

	Check all parameters if set correct
	
=cut
sub test_parameters{
	my $self = shift;
	
	$self->assert_equals($self->{object}->duration(), 20);
	$self->assert_equals($self->{object}->duration(), 20);
	$self->assert_equals($self->{object}->tool(), 'bwctl/iperf3');
	$self->assert_equals($self->{object}->protocol(), 'tcp');
	$self->assert_equals($self->{object}->type(), 'perfsonarbuoy/bwctl');
	$self->assert_equals($self->{object}->interval(), 14400);
}

=head2 Test : test_parameters

	Check if field time_slot is correct set as ArrayRef.

=cut
sub test_time_slot{
	my $self = shift;
	my $time_slots = $self->{object}->time_slots();
	$self->assert_not_null(@{$time_slots}, "The parameter time_slot is not set.");
	$self->assert_equals("01:00", grep(/^01:00/, @{$time_slots}));
	$self->assert_equals("05:00", grep(/^05:00/, @{$time_slots}));
}

=head2 Test : test_time_slots_set_from_json

	In the example json file the time_slot parameter is set to:
	 "time_slots" : [
               "01:25",
               "07:15",
               "*:25"
            ],
	this test checks if this value parsed correctly.
	
=cut
sub test_time_slots_set_from_json{
	my $self = shift;
	my $mesh = @{$self->{meshes}}[0];
	my $test = @{$mesh->tests}[0]; #json file has only one test
	my $parameters = $test->parameters();
	my $time_slots = $parameters->time_slots();
	$self->assert_equals("01:25", grep(/^01:25/, @{$time_slots}));
	$self->assert_equals("07:15", grep(/^07:15/, @{$time_slots}));
	$self->assert_equals("*:25", grep(/^\*:25/, @{$time_slots}));
}

1;


