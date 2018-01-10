package perfSONAR_PS::PSConfig::JQTransform;

use Mouse;
use JSON::Validator;
use perfSONAR_PS::PSConfig::PScheduler::Schema qw( psconfig_pscheduler_json_schema );
use perfSONAR_PS::Utils::JQ qw( jq );

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'error' => (is => 'ro', isa => 'Str|Undef', writer => '_set_error');

=item script()

Getter/Setter for JQ script. Can be string or array of strings where each item in list
is a line of the JQ script

=cut

sub script {
    my ($self, $val) = @_;
    return $self->_field_list('script', $val);
}

=item apply()

Applies JQ script to provided object

=cut

sub apply {
    my ($self, $json_obj) = @_;
    
    #reset error
    $self->_set_error(undef);
    
    #apply script
    my $transformed;
    eval{ $transformed = jq($self->script(), $json_obj); };
    if($@){
         $self->_set_error($@);
         return;
    }
    
    return $transformed;
}

=item validate()

Validates this object against JSON schema. Returns any errors found. Valid if list is empty.

=cut

sub validate {
    my $self = shift;
    my $validator = new JSON::Validator();
    my $schema = psconfig_pscheduler_json_schema();
    #tweak it so we just look at JQTransformSpecification
    $schema->{'properties'} = {
        'transform' => { 
            '$ref' => '#/pSConfig/JQTransformSpecification',
            'description' => 'JQ script to transform downloaded pSConfig JSON'
        }
    };
    $schema->{'required'} = [ 'transform' ];
    $validator->schema($schema);
    
    #plug-in archive in a way that will validate
    return $validator->validate({'transform' =>  $self->data()});
}


__PACKAGE__->meta->make_immutable;

1;
