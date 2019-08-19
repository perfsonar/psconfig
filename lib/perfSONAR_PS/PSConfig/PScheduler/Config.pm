package perfSONAR_PS::PSConfig::PScheduler::Config;

use Mouse;

use JSON::Validator;
#Ignore warning related to re-defining host verification method used by JSON::Validator
no warnings 'redefine';
use Data::Validate::Domain;

use perfSONAR_PS::PSConfig::Remote;
use perfSONAR_PS::PSConfig::PScheduler::Schema qw(psconfig_pscheduler_json_schema);

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

=item pscheduler_assist_server()

Sets/gets the pscheduler-assist-server field as a host with optional port in form HOST:PORT

=cut

sub pscheduler_assist_server {
    my ($self, $val) = @_;
    return $self->_field_urlhostport('pscheduler-assist-server', $val);
}

=item pscheduler_bind_map()

Sets/gets HasRef used in binding to pscheduler servers. The key is the remote host and the
value is the local address to use for binding

=cut

sub pscheduler_bind_map{
    my ($self, $val) = @_;
    
    return $self->_field_anyobj('pscheduler-bind-map', $val);
}

=item pscheduler_fail_attempts()

The number of times to try to connect to pscheduler assist server before giving up

=cut

sub pscheduler_fail_attempts {
    my ($self, $val) = @_;
    return $self->_field_cardinal('pscheduler-fail-attempts', $val);
}

=item match_addresses()

Sets/gets list of addresses (as strings) for which the agent is responsible for creating tests

=cut

sub match_addresses {
    my ($self, $val) = @_;
    return $self->_field_host_list('match-addresses', $val);
}

=item match_address()

Sets/gets an addresses (as string) at the given index

=cut

sub match_address {
    my ($self, $index, $val) = @_;
    return $self->_field_host_list_item('match-addresses', $index, $val);
}


=item add_match_address()

Adds a match address to the list of match-addresses

=cut

sub add_match_address {
    my ($self, $val) = @_;
    return $self->_add_field_host('match-addresses', $val);
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

=item requesting_agent_file()

Gets/sets the location of a file with the requesting agent definition

=cut

sub requesting_agent_file {
    my ($self, $val) = @_;
    return $self->_field('requesting-agent-file', $val);
}

=item client_uuid_file()

Gets/sets the location of a the file containing the UUID used by this agent

=cut

sub client_uuid_file {
    my ($self, $val) = @_;
    return $self->_field('client-uuid-file', $val);
}

=item pscheduler_tracker_file()

Gets/sets the location of the file used to track previously talked to pscheduler servers

=cut

sub pscheduler_tracker_file {
    my ($self, $val) = @_;
    return $self->_field('pscheduler-tracker-file', $val);
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

=item task_min_ttl()

The minimum amount of time before a created task expires. Formatted as IS8601
duration.

=cut

sub task_min_ttl {
    my ($self, $val) = @_;
    return $self->_field_duration('task-min-ttl', $val);
}

=item task_min_runs()

The minimum number of runs that must be scheduled for a task.

=cut

sub task_min_runs {
    my ($self, $val) = @_;
    return $self->_field_cardinal('task-min-runs', $val);
}

=item task_renewal_fudge_factor()

The percentage of time before expiration to renew a task. 

=cut

sub task_renewal_fudge_factor {
    my ($self, $val) = @_;
    return $self->_field_probability('task-renewal-fudge-factor', $val);
}

=item use_cache()

Gets/sets whether templates should be cached

=cut

sub disable_cache {
    my ($self, $val) = @_;
    return $self->_field_bool('disable-cache', $val);
}

=item cache_directory()

Gets/sets the directory where cached templates live

=cut

sub cache_directory {
    my ($self, $val) = @_;
    return $self->_field('cache-directory', $val);
}

=item cache_expires()

Gets/sets how long to keep templates cached.

=cut

sub cache_expires {
    my ($self, $val) = @_;
    return $self->_field_duration('cache-expires', $val);
}

=item validate()

Validates this object against JSON schema. Returns error messages of a 0 length array if valid. 

=cut

sub validate {
    my $self = shift;
    my $validator = new JSON::Validator();
    ##NOTE: Below works around the strict TLD requirements of JSON::Validator
    local *Data::Validate::Domain::is_domain = \&Data::Validate::Domain::is_hostname;
    $validator->schema($self->schema());

    return $validator->validate($self->data());
}

=item schema()

Returns the JSON schema for this config

=cut

sub schema {
    my $self = shift;
    return psconfig_pscheduler_json_schema();
}


__PACKAGE__->meta->make_immutable;

1;
