package MeshConfig::StatisticTest;

use base qw(Test::Unit::TestCase);

use Cwd 'abs_path';	
use perfSONAR_PS::MeshConfig::Statistic;
 
sub new {
 	my $self = shift()->SUPER::new(@_);
	return $self;
}

sub set_up{
	my $self = shift;
	my $mesh_file = "json/my-devel-mesh.json";
	$self->{mesh_abs_path} = abs_path($mesh_file);
	$self->{statistic_obj} = perfSONAR_PS::MeshConfig::Statistic->new();
	$self->{statistic_obj}->init(configuration_file => $self->{mesh_abs_path});	
}

=head2 Test : test_statistic_not_null
	This is a generic test. It checks if init of statistic object. 
=cut
sub test_statistic_not_null {	
	my $self = shift;
	$self->assert_not_null($self->{statistic_obj});
}

=head2 Test : test_load_mesh_json_file
	Check if load of json file was successfully. 
=cut
sub test_load_mesh_json_file {
	my $self = shift;
	my $num_of_meshes = scalar (@{$self->{statistic_obj}->meshes});
	my $expected_meshes = 1; #The test mesh json includes only 1 mesh
	$self->assert_equals($expected_meshes, $num_of_meshes);
}

=head2 Test : test_build_statistic
	The test json file has 3 addresses defined  for tests. Check if the build of the statistic hash
	was successfully. 
=cut
sub test_build_statistic {
	my $self = shift;
	$self->{statistic_obj}->build_statistics();
	my %statistics_tree = %{$self->{statistic_obj}->statistics_tree};
	my $current_addresses = keys %statistics_tree;
	my $expected_addresses = 3;
	$self->assert_equals($expected_addresses, $current_addresses);
}



1;