package perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig;

use Mouse;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';


=item type()

Gets/sets the type

=cut

sub type {
    my ($self, $val) = @_;
    return $self->_field('type', $val);
}

=item base_url()

Gets/sets the base-url

=cut

sub base_url {
    my ($self, $val) = @_;
    return $self->_field('base-url', $val);
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
