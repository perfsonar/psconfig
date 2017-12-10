package perfSONAR_PS::PSConfig::PScheduler::Config;

use Mouse;
use JSON::Validator;
use perfSONAR_PS::PSConfig::Remote;
use perfSONAR_PS::PSConfig::PScheduler::Schema qw(psconfig_pscheduler_json_schema);

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');

sub remotes{
    my ($self, $val) = @_;
    return $self->_field_class_list('remotes', 'perfSONAR_PS::PSConfig::Remote', $val);
}

sub remote{
    my ($self, $index, $val) = @_;
    return $self->_field_class_list_item('remotes', $index, 'perfSONAR_PS::PSConfig::Remote', $val);
}

sub add_remote{
    my ($self, $val) = @_;
    $self->_add_field_class('remotes', 'perfSONAR_PS::PSConfig::Remote', $val);
}

sub pscheduler_assist_server {
    my ($self, $val) = @_;
    return $self->_field_urlhostport('pscheduler-assist-server', $val);
}

sub pscheduler_fail_attempts {
    my ($self, $val) = @_;
    return $self->_field_cardinal('pscheduler-fail-attempts', $val);
}

sub match_addresses {
    my ($self, $val) = @_;
    return $self->_field_host_list('match-addresses', $val);
}

sub match_address {
    my ($self, $index, $val) = @_;
    return $self->_field_host_list_item('match-addresses', $index, $val);
}

sub add_match_address {
    my ($self, $val) = @_;
    return $self->_add_field_host('match-addresses', $val);
}

sub include_directory {
    my ($self, $val) = @_;
    return $self->_field('include-directory', $val);
}

sub archive_directory {
    my ($self, $val) = @_;
    return $self->_field('archive-directory', $val);
}

sub requesting_agent_file {
    my ($self, $val) = @_;
    return $self->_field('requesting-agent-file', $val);
}

sub client_uuid_file {
    my ($self, $val) = @_;
    return $self->_field('client-uuid-file', $val);
}

sub pscheduler_tracker_file {
    my ($self, $val) = @_;
    return $self->_field('pscheduler-tracker-file', $val);
}

sub check_interval {
    my ($self, $val) = @_;
    return $self->_field_duration('check-interval', $val);
}

sub check_config_interval {
    my ($self, $val) = @_;
    return $self->_field_duration('check-config-interval', $val);
}

sub task_min_ttl {
    my ($self, $val) = @_;
    return $self->_field_duration('task-min-ttl', $val);
}

sub task_min_runs {
    my ($self, $val) = @_;
    return $self->_field_cardinal('task-min-runs', $val);
}

sub task_renewal_fudge_factor {
    my ($self, $val) = @_;
    return $self->_field_probability('task-renewal-fudge-factor', $val);
}

sub validate {
    my $self = shift;
    my $validator = new JSON::Validator();
    $validator->schema(psconfig_pscheduler_json_schema());

    return $validator->validate($self->data());
}


__PACKAGE__->meta->make_immutable;

1;
