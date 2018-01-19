package perfSONAR_PS::PSConfig::MaDDash::Agent::TaskSelector;

use Mouse;

use perfSONAR_PS::PSConfig::JQTransform;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

==item test_type()

Get/sets test-type as ArrayRef

=cut

sub test_type{
    my ($self, $val) = @_;
    return $self->_field_list('test-type', $val);
}

=item add_test_type()

Adds test-type to list

=cut

sub add_test_type{
    my ($self, $val) = @_;
    $self->_add_list_item('test-type', $val);
}

==item task_name()

Get/sets task-name as ArrayRef

=cut

sub task_name{
    my ($self, $val) = @_;
    return $self->_field_list('task-name', $val);
}

=item add_task_name()

Adds task-name to list

=cut

sub add_task_name{
    my ($self, $val) = @_;
    $self->_add_list_item('task-name', $val);
}

==item archive_type()

Get/sets archive-type as ArrayRef

=cut

sub archive_type{
    my ($self, $val) = @_;
    return $self->_field_list('archive-type', $val);
}

=item add_archive_type()

Adds archive-type to list

=cut

sub add_archive_type{
    my ($self, $val) = @_;
    $self->_add_list_item('archive-type', $val);
}

=item jq()

Get/sets JQTransform object for selecting tasks

=cut

sub jq {
    my ($self, $val) = @_;
    return $self->_field_class('jq', 'perfSONAR_PS::PSConfig::JQTransform', $val);
}



__PACKAGE__->meta->make_immutable;

1;
