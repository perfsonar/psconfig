package perfSONAR_PS::PSConfig::CLI::Lookup::Query;

use Mouse;
use perfSONAR_PS::PSConfig::CLI::Lookup::Output;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';
        
=item ls_urls()

Get/set record-type

=cut

sub record_type{
    my ($self, $val) = @_;
    return $self->_field('record-type', $val);
}

=item filters()

Sets/gets filters map

=cut

sub filters{
    my ($self, $val) = @_;
    
    return $self->_field_map('filters', $val);
}

=item filter()

Get/sets filter at specified field

=cut

sub filter{
    my ($self, $field, $val) = @_;
    
    return $self->_field_map_item('filters', $field, $val);
}

=item filter_names()

Gets keys of filters HashRef

=cut

sub filter_names{
    my ($self) = @_;
    return $self->_get_map_names("filters");
} 

=item remove_filter()

Removes filter at specified field

=cut

sub remove_filter {
    my ($self, $field) = @_;
    $self->_remove_map_item('filters', $field);
}

=item output()

Gets/sets output

=cut

sub output{
    my ($self, $val) = @_;
    return $self->_field_class('output', 'perfSONAR_PS::PSConfig::CLI::Lookup::Output', $val);
}

__PACKAGE__->meta->make_immutable;

1;
