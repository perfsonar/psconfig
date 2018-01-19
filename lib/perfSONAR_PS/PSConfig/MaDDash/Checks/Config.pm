package perfSONAR_PS::PSConfig::MaDDash::Checks::Config;

use Mouse;
use JSON::Validator;

use perfSONAR_PS::Client::PSConfig::JQTransform;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;
use perfSONAR_PS::PSConfig::MaDDash::Checks::CheckDefaults
use perfSONAR_PS::PSConfig::MaDDash::Checks::CommandOpt;
use perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabels;

use perfSONAR_PS::PSConfig::MaDDash::Checks::Schema qw(psconfig_maddash_check_json_schema);

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');

=item type()

Gets/sets the type

=cut

sub type {
    my ($self, $val) = @_;
    return $self->_field('type', $val);
}

=item name()

Gets/sets the name

=cut

sub name {
    my ($self, $val) = @_;
    return $self->_field('name', $val);
}

=item description()

Gets/sets the description

=cut

sub description {
    my ($self, $val) = @_;
    return $self->_field('description', $val);
}

=item requires()

Sets/gets requires object

=cut

sub requires{
    my ($self, $val) = @_;
    return $self->_field_class('requires', 'perfSONAR_PS::PSConfig::MaDDash::TaskSelector', $val);
}

=item status_labels()

Sets/gets status-labels object

=cut

sub status_labels{
    my ($self, $val) = @_;
    return $self->_field_class('status-labels', 'perfSONAR_PS::PSConfig::MaDDash::Checks::StatusLabels', $val);
}

=item defaults()

Sets/gets defaults object

=cut

sub defaults{
    my ($self, $val) = @_;
    return $self->_field_class('defaults', 'perfSONAR_PS::PSConfig::MaDDash::Checks::CheckDefaults', $val);
}

=item vars()

Sets/gets vars map

=cut

sub vars{
    my ($self, $val) = @_;
    
    return $self->_field_class_map('vars', 'perfSONAR_PS::Client::PSConfig::JQTransform', $val);
}

=item var()

Get/sets var at specified field

=cut

sub var{
    my ($self, $field, $val) = @_;
    
    return $self->_field_class_map_item('vars', $field, 'perfSONAR_PS::Client::PSConfig::JQTransform', $val);
}

=item var_names()

Gets keys of vars HashRef

=cut

sub var_names{
    my ($self) = @_;
    return $self->_get_map_names("vars");
} 

=item remove_var()

Removes var at specified field

=cut

sub remove_var {
    my ($self, $field) = @_;
    $self->_remove_map_item('vars', $field);
}

=item command()

Gets/sets the command

=cut

sub command {
    my ($self, $val) = @_;
    return $self->_field('command', $val);
}

=item command_opts()

Sets/gets command-opts map

=cut

sub command_opts{
    my ($self, $val) = @_;
    
    return $self->_field_class_map('command-opts', 'perfSONAR_PS::PSConfig::MaDDash::Checks::CommandOpt', $val);
}

=item command_opt()

Get/sets command-opt at specified field

=cut

sub command_opt{
    my ($self, $field, $val) = @_;
    
    return $self->_field_class_map_item('command-opts', $field, 'perfSONAR_PS::PSConfig::MaDDash::Checks::CommandOpt', $val);
}

=item command_opt_names()

Gets keys of command-opts HashRef

=cut

sub command_opt_names{
    my ($self) = @_;
    return $self->_get_map_names("command-opts");
} 

=item remove_command_opt()

Removes command-opt at specified field

=cut

sub remove_command_opt {
    my ($self, $field) = @_;
    $self->_remove_map_item('command-opts', $field);
}


=item command_args()

Getter/Setter for command-args as ArrayRef

=cut

sub command_args {
    my ($self, $val) = @_;
    return $self->_field_list('command-args', $val);
}

=item add_command_arg()

Adds command-arg to list

=cut

sub add_command_arg {
    my ($self, $val) = @_;
    return $self->_add_list_item('command-args', $val);
}

=item validate()

Validates this object against JSON schema. Returns error messages of a 0 length array if valid. 

=cut

sub validate {
    my $self = shift;
    my $validator = new JSON::Validator();
    $validator->schema(psconfig_maddash_check_json_schema());

    return $validator->validate($self->data());
}


__PACKAGE__->meta->make_immutable;

1;
