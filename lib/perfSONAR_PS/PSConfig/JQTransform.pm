package perfSONAR_PS::PSConfig::JQTransform;

use Mouse;
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


__PACKAGE__->meta->make_immutable;

1;
