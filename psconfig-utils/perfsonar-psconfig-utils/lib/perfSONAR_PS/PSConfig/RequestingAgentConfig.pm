package perfSONAR_PS::PSConfig::RequestingAgentConfig;

use Mouse;
use JSON::Validator;
use perfSONAR_PS::Client::PSConfig::Addresses::Address;
use perfSONAR_PS::Client::PSConfig::Schema qw(psconfig_json_schema);

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');

sub address{
    my ($self, $field, $val) = @_;
    
    return $self->_field_class($field, 'perfSONAR_PS::Client::PSConfig::Addresses::Address', $val);
}

sub address_names{
    my ($self) = @_;
    my @names = keys %{$self->data()};
    return \@names;
} 

sub remove_address {
    my ($self, $field) = @_;
    unless(exists $self->data()->{$field}){
        return;
    }
    
    delete $self->data()->{$field};
}

sub validate {
    my $self = shift;
    my $validator = new JSON::Validator();
    my $schema = psconfig_json_schema();
    #tweak it so we just look at ArchiveSpecification
    $schema->{'required'} = [ 'addresses' ];
    $validator->schema($schema);
    
    #plug-in archive in a way that will validate
    return $validator->validate({'addresses' => $self->data()});
}


__PACKAGE__->meta->make_immutable;

1;
