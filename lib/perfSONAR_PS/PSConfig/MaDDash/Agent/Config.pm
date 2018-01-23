package perfSONAR_PS::PSConfig::MaDDash::Agent::Config;

use Mouse;
use JSON::Validator;
use perfSONAR_PS::PSConfig::Remote;
use perfSONAR_PS::PSConfig::MaDDash::Agent::Schema qw(psconfig_maddash_agent_json_schema);

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');

=item remotes()

Sets/gets list of Remote objects

=cut

sub remotes{
    my ($self, $val) = @_;
    return $self->_field_class_list('remotes', 'perfSONAR_PS::PSConfig::Remote', $val);
}

=item remote()

Sets/gets Remote object at give index

=cut

sub remote{
    my ($self, $index, $val) = @_;
    return $self->_field_class_list_item('remotes', $index, 'perfSONAR_PS::PSConfig::Remote', $val);
}

=item add_remote()

Adds Remote object to remotes list

=cut

sub add_remote{
    my ($self, $val) = @_;
    $self->_add_field_class('remotes', 'perfSONAR_PS::PSConfig::Remote', $val);
}

=item include_directory()

Gets/sets the directory where local configuration files live

=cut

sub include_directory {
    my ($self, $val) = @_;
    return $self->_field('include-directory', $val);
}

=item archive_directory()

Gets/sets the directory where local archiver definitions live

=cut

sub archive_directory {
    my ($self, $val) = @_;
    return $self->_field('archive-directory', $val);
}

=item transform_directory()

Gets/sets the directory where local transform scripts live

=cut

sub transform_directory {
    my ($self, $val) = @_;
    return $self->_field('transform-directory', $val);
}

=item check_plugin_directory()

Gets/sets the directory where check plugins live

=cut

sub check_plugin_directory {
    my ($self, $val) = @_;
    return $self->_field('check-plugin-directory', $val);
}

=item visualization_plugin_directory()

Gets/sets the directory where visualization plugins live

=cut

sub visualization_plugin_directory {
    my ($self, $val) = @_;
    return $self->_field('visualization-plugin-directory', $val);
}

=item pscheduler_assist_server()

Sets/gets the pscheduler-assist-server field as a host with optional port in form HOST:PORT

=cut

sub pscheduler_assist_server {
    my ($self, $val) = @_;
    return $self->_field_urlhostport('pscheduler-assist-server', $val);
}

=item maddash_yaml_file()

Sets/gets the maddash-yaml-file

=cut

sub maddash_yaml_file {
    my ($self, $val) = @_;
    return $self->_field('maddash-yaml-file', $val);
}

=item requesting_agent_file()

Gets/sets the location of a file with the requesting agent definition

=cut

sub requesting_agent_file {
    my ($self, $val) = @_;
    return $self->_field('requesting-agent-file', $val);
}

=item check_interval()

Gets/sets how often to check for changes to remote configuation files. Formatted as IS8601
duration.

=cut

sub check_interval {
    my ($self, $val) = @_;
    return $self->_field_duration('check-interval', $val);
}

=item check_config_interval()

Gets/sets how often to check for changes to local configuation files. Formatted as IS8601
duration.

=cut

sub check_config_interval {
    my ($self, $val) = @_;
    return $self->_field_duration('check-config-interval', $val);
}

=item grids()

Get/sets grids as HashRef

=cut

sub grids{
    my ($self, $val) = @_;
    
    return $self->_field_class_map('grids', 'perfSONAR_PS::PSConfig::MaDDash::Agent::Grid', $val);
}

=item grid()

Get/sets grid at specified field

=cut

sub grid{
    my ($self, $field, $val) = @_;
    
    return $self->_field_class_map_item('grids', $field, 'perfSONAR_PS::PSConfig::MaDDash::Agent::Grid', $val);
}

=item grid_names()

Gets keys of grids HashRef

=cut

sub grid_names{
    my ($self) = @_;
    return $self->_get_map_names("grids");
} 

=item remove_grid()

Removes grid at specified field

=cut

sub remove_grid {
    my ($self, $field) = @_;
    $self->_remove_map_item('grids', $field);
}

=item validate()

Validates this object against JSON schema. Returns error messages of a 0 length array if valid. 

=cut

sub validate {
    my $self = shift;
    my $validator = new JSON::Validator();
    $validator->schema(psconfig_maddash_agent_json_schema());

    return $validator->validate($self->data());
}


__PACKAGE__->meta->make_immutable;

1;
