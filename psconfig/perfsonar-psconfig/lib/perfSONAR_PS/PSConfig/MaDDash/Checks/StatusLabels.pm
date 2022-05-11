package perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabels;

use Mouse;      

use perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabelsExtra;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

=item ok()

Gets/sets the ok

=cut

sub ok {
    my ($self, $val) = @_;
    return $self->_field('ok', $val);
}

=item warning()

Gets/sets the warning

=cut

sub warning {
    my ($self, $val) = @_;
    return $self->_field('warning', $val);
}

=item critical()

Gets/sets the critical

=cut

sub critical {
    my ($self, $val) = @_;
    return $self->_field('critical', $val);
}

=item notrun()

Gets/sets the notrun

=cut

sub notrun {
    my ($self, $val) = @_;
    return $self->_field('notrun', $val);
}

=item unknown()

Gets/sets the unknown

=cut

sub unknown {
    my ($self, $val) = @_;
    return $self->_field('unknown', $val);
}

=item extra()

Gets/sets extra

=cut

sub extra {
    my ($self, $val) = @_;
    return $self->_field_class_list('extra', 'perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabelsExtra', $val);
}

=item extra_label()

Gets/sets the an individual value from extra

=cut

sub extra_label {
    my ($self, $index, $val) = @_;
    return $self->_field_class_list_item('extra', $index, 'perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabelsExtra', $val);
}


__PACKAGE__->meta->make_immutable;

1;
