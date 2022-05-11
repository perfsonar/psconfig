package perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabelsExtra;

use Mouse;      

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

=item value()

Gets/sets the value

=cut

sub value {
    my ($self, $val) = @_;
    return $self->_field_intzero('value', $val);
}

=item short_name()

Gets/sets the short-name

=cut

sub short_name {
    my ($self, $val) = @_;
    return $self->_field('short-name', $val);
}

=item description()

Gets/sets the description

=cut

sub description {
    my ($self, $val) = @_;
    return $self->_field('description', $val);
}

__PACKAGE__->meta->make_immutable;

1;
