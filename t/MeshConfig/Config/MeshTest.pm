package MeshConfig::Config::MeshTest;

use base qw(Test::Unit::TestCase);

use Cwd 'abs_path';
use Data::Dumper qw(Dumper);
use perfSONAR_PS::MeshConfig::Utils qw(load_mesh);
 
 my $mesh_file = "json/my-devel-mesh.json";
 
sub new {
 	my $self = shift()->SUPER::new(@_);
	return $self;
}

sub set_up{
	my $self = shift;
	my ($status, $res) = load_mesh({ configuration_url => "file://". abs_path($mesh_file) });
	if ($status != 0) {
		die;
	}
	$self->{meshes} = $res;
}

=head2 Test : test_has_mesh
	The test json file has one mesh. 
=cut
sub test_has_mesh {
	my $self = shift;
	my $num_meshes = scalar(@{$self->{meshes}});
	my $expected_num_meshes = 1;
	$self->assert_equals($expected_num_meshes, $num_meshes);		
}

=head2 Test : test_mesh_has_tests_definition
	The test json file has 4 test definitions. 
=cut
sub test_mesh_has_tests_definition {
	my $self = shift;
	my $mesh = @{$self->{meshes}}[0];
	my $num_tests = scalar(@{$mesh->tests});
	my $expected_num_tests = 4;
	$self->assert_equals($expected_num_tests, $num_tests);
}


=head2 Test : test_mesh_has_one_organization
	The test json file has only one organizations. 
=cut
sub test_mesh_has_one_organization {
	my $self = shift;
	my $mesh = @{$self->{meshes}}[0];
	my $num_organizations = scalar(@{$mesh->organizations});
	my $expected_num_organizations = 1;
	$self->assert_equals($expected_num_organizations, $num_organizations);	
}
	