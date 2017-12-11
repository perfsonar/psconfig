package perfSONAR_PS::PSConfig::JQTransform;

use Mouse;
use JSON::Validator;
use perfSONAR_PS::PSConfig::PScheduler::Schema qw( psconfig_pscheduler_json_schema );
use perfSONAR_PS::Utils::JQ qw( jq );

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'error' => (is => 'ro', isa => 'Str|Undef', writer => '_set_error');

sub script {
    my ($self, $val) = @_;
    return $self->_field('script', $val);
}

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
