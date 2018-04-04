package perfSONAR_PS::PSConfig::MaDDash::Visualization::Config;

use Mouse;
use JSON::Validator;

use perfSONAR_PS::Client::PSConfig::JQTransform;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::VizDefaults;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::HttpGetOpt;

use perfSONAR_PS::PSConfig::MaDDash::Visualization::Schema qw(psconfig_maddash_viz_json_schema);

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');

=item type()

Gets/sets the type

=cut

sub type {
    my ($self, $val) = @_;
    return $self->_field('type', $val);
}

=item requires()

Sets/gets requires object

=cut

sub requires{
    my ($self, $val) = @_;
    return $self->_field_class('requires', 'perfSONAR_PS::PSConfig::MaDDash::TaskSelector', $val);
}

=item defaults()

Sets/gets defaults object

=cut

sub defaults{
    my ($self, $val) = @_;
    return $self->_field_class('defaults', 'perfSONAR_PS::PSConfig::MaDDash::Visualization::VizDefaults', $val);
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

=item http_get_opts()

Sets/gets http-get-opts map

=cut

sub http_get_opts{
    my ($self, $val) = @_;
    
    return $self->_field_class_map('http-get-opts', 'perfSONAR_PS::PSConfig::MaDDash::Visualization::HttpGetOpt', $val);
}

=item http_get_opt()

Get/sets http-get-opt at specified field

=cut

sub http_get_opt{
    my ($self, $field, $val) = @_;
    
    return $self->_field_class_map_item('http-get-opts', $field, 'perfSONAR_PS::PSConfig::MaDDash::Visualization::HttpGetOpt', $val);
}

=item http_get_opt_names()

Gets keys of http-get-opts HashRef

=cut

sub http_get_opt_names{
    my ($self) = @_;
    return $self->_get_map_names("http-get-opts");
} 

=item remove_http_get_opt()

Removes http-get-opt at specified field

=cut

sub remove_http_get_opt {
    my ($self, $field) = @_;
    $self->_remove_map_item('http-get-opts', $field);
}

=item validate()

Validates this object against JSON schema. Returns error messages of a 0 length array if valid. 

=cut

sub validate {
    my $self = shift;
    my $validator = new JSON::Validator();
    $validator->schema(psconfig_maddash_viz_json_schema());

    return $validator->validate($self->data());
}

=item expand_vars()

Expands the vars section and returns as key/val HashRef based on given object
=cut

sub expand_vars {
    my ($self, $jq_obj) = @_;
    my $expanded = {};
    
    #reset error
    $self->_set_error('');
     
    #expand
    foreach my $var_name(@{$self->var_names()}){
        my $jq = $self->var($var_name);    
        $expanded->{$var_name} = $jq->apply($jq_obj);
        if($jq->error()){
            $self->_set_error($jq->error());
            return;
        }
    }
    
    return $expanded;
}



__PACKAGE__->meta->make_immutable;

1;
