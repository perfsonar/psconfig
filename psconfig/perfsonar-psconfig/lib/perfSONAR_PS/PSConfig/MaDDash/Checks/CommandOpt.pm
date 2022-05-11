package perfSONAR_PS::PSConfig::MaDDash::Checks::CommandOpt;

use Mouse;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';


=item condition()

Gets/sets the condition

=cut

sub condition {
    my ($self, $val) = @_;
    return $self->_field('condition', $val);
}

=item arg()

Gets/sets the arg

=cut

sub arg {
    my ($self, $val) = @_;
    return $self->_field('arg', $val);
}

=item required()

Gets/sets the required

=cut

sub required {
    my ($self, $val) = @_;
    return $self->_field_bool('required', $val);
}


__PACKAGE__->meta->make_immutable;

1;
