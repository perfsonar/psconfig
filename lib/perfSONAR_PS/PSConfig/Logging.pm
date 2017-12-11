package perfSONAR_PS::PSConfig::Logging;

=head1 NAME

perfSONAR_PS::PSConfig::Logging - Utility to help with formatting log messages

=head1 DESCRIPTION

A client for reading in JQTransform files

=cut

use Mouse;
use JSON qw( to_json );

our $VERSION = 4.1;

has 'log4perl_format' => (is => 'ro', isa => 'Str', default => sub{ { '%d %p pid=%P prog=%M line=%L %m%n' } });
has 'global_context' => (is => 'rw', isa => 'HashRef', default => sub{ {} });


sub format {
    my($self, $msg, $local_context) = @_;
    
    #init msg
    my $m = "";
    
    #add global context variables
    foreach my $ctx(keys %{$self->global_context()}){
        $m .= $self->_append_msg($ctx, $self->global_context()->{$ctx}, $m);
    }
    
    #add local context variables
    if($local_context){
        foreach my $ctx(keys %{$local_context}){
            $m .= $self->_append_msg($ctx, $local_context->{$ctx}, $m);
        }
    }
        
    #add message
    $m .= $self->_append_msg('msg', $msg, $m);
    
    return $m;
}

sub _append_msg {
    my($self, $k, $v, $msg) = @_;
    
    my $m;
    $m .= ' ' if($msg);
    my $val = $v;
    if(ref $val eq 'HASH' || ref $val eq 'ARRAY'){
        $val = to_json($val);
    }
    $m .= "$k=$val";
    
    return $m;
}


__PACKAGE__->meta->make_immutable;

1;