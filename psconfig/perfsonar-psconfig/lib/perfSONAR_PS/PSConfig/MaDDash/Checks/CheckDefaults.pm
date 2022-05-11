package perfSONAR_PS::PSConfig::MaDDash::Checks::CheckDefaults;

use Mouse;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

=item check_interval()

Gets/sets the check-interval

=cut

sub check_interval {
    my ($self, $val) = @_;
    return $self->_field_duration('check-interval', $val);
}

=item warning_threshold()

Gets/sets the warning-threshold

=cut

sub warning_threshold {
    my ($self, $val) = @_;
    return $self->_field('warning-threshold', $val);
}

=item critical_threshold()

Gets/sets the critical-threshold

=cut

sub critical_threshold {
    my ($self, $val) = @_;
    return $self->_field('critical-threshold', $val);
}

=item report_yaml_file()

Gets/sets the report-yaml-file

=cut

sub report_yaml_file {
    my ($self, $val) = @_;
    return $self->_field('report-yaml-file', $val);
}

=item retry_interval()

Gets/sets the retry-interval

=cut

sub retry_interval {
    my ($self, $val) = @_;
    return $self->_field_duration('retry-interval', $val);
}

=item retry_attempts()

Gets/sets the retry-attempts

=cut

sub retry_attempts {
    my ($self, $val) = @_;
    return $self->_field_intzero('retry-attempts', $val);
}

=item timeout()

Gets/sets the timeout

=cut

sub timeout {
    my ($self, $val) = @_;
    return $self->_field_duration('timeout', $val);
}

=item params()

Gets/sets param

=cut

sub params{
    my ($self, $val) = @_;
    return $self->_field_anyobj('params', $val);
}

=item param()

Gets/sets param parameter at given field

=cut

sub param{
    my ($self, $field, $val) = @_;    
    return $self->_field_anyobj_param('params', $field, $val);
}



__PACKAGE__->meta->make_immutable;

1;
