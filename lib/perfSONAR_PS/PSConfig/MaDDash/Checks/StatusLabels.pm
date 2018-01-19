package perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabels;

use Mouse;

"ok": { "type": "string" },
                "warning": { "type": "string" },
                "critical": { "type": "string" },
                "notrun": { "type": "string" },
                "unknown": { "type": "string" },
                "custom": { 
                    "$ref": "StatusLabelCustom" 
                }
                

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

=item custom()

Gets/sets the custom

=cut

sub custom {
    my ($self, $val) = @_;
    return $self->_field_map('custom', $val);
}

=item custom_label()

Gets/sets the an individual value from custom

=cut

sub custom_label {
    my ($self, $val) = @_;
    return $self->_field_map('custom', $field, $val);
}


__PACKAGE__->meta->make_immutable;

1;
