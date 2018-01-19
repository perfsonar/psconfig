package perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority;

use Mouse;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';


=item group()

Gets/sets the group

=cut

sub group {
    my ($self, $val) = @_;
    return $self->_field('group', $val);
}

=item level()

Gets/sets the level

=cut

sub level {
    my ($self, $val) = @_;
    return $self->_field_intzero('level', $val);
}

__PACKAGE__->meta->make_immutable;

1;
