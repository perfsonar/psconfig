package perfSONAR_PS::PSConfig::CLI::Lookup::LookupConfig;

use Mouse;
use JSON::Validator;
use perfSONAR_PS::PSConfig::CLI::Lookup::Query;
use perfSONAR_PS::PSConfig::CLI::Lookup::Schema qw(psconfig_lookup_json_schema);

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');

=item ls_urls()

Get/set LS URLs

=cut

sub ls_urls{
    my ($self, $val) = @_;
    return $self->_field_list('ls-urls', $val);
}

=item add_ls_url()

Adds LS URL to list

=cut

sub add_ls_url{
    my ($self, $val) = @_;
    $self->_add_list_item('ls-urls', $val);
}

=item queries()

Sets/gets queries map

=cut

sub queries{
    my ($self, $val) = @_;
    
    return $self->_field_class_map('queries', 'perfSONAR_PS::PSConfig::CLI::Lookup::Query', $val);
}

=item query()

Get/sets query at specified field

=cut

sub query{
    my ($self, $field, $val) = @_;
    
    return $self->_field_class_map_item('queries', $field, 'perfSONAR_PS::PSConfig::CLI::Lookup::Query', $val);
}

=item query_names()

Gets keys of queries HashRef

=cut

sub query_names{
    my ($self) = @_;
    return $self->_get_map_names("queries");
} 

=item remove_query()

Removes query at specified field

=cut

sub remove_query {
    my ($self, $field) = @_;
    $self->_remove_map_item('queries', $field);
}


sub validate {
    my $self = shift;
    my $validator = new JSON::Validator();
    $validator->schema(psconfig_lookup_json_schema());
    
    #plug-in archive in a way that will validate
    return $validator->validate($self->data());
}


__PACKAGE__->meta->make_immutable;

1;
