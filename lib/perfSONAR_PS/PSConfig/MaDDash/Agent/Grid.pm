package perfSONAR_PS::PSConfig::MaDDash::Agent::Grid;

use Mouse;

use perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig;
use perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;
use perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

=item selector()

Sets/gets selector object

=cut

sub selector{
    my ($self, $val) = @_;
    return $self->_field_class('selector', 'perfSONAR_PS::PSConfig::MaDDash::TaskSelector', $val);
}

=item check()

Sets/gets check object

=cut

sub check{
    my ($self, $index, $val) = @_;
    return $self->_field_class('check', 'perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig', $val);
}

=item visualization()

Sets/gets visualization object

=cut

sub visualization{
    my ($self, $index, $val) = @_;
    return $self->_field_class('visualization', 'perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig', $val);
}

=item priority()

Sets/gets priority object

=cut

sub priority{
    my ($self, $index, $val) = @_;
    return $self->_field_class('priority', 'perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority', $val);
}


__PACKAGE__->meta->make_immutable;

1;
