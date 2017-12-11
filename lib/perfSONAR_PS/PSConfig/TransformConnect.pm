package perfSONAR_PS::PSConfig::TransformConnect;

=head1 NAME

perfSONAR_PS::PSConfig::TransformConnect - A client for reading in JQTransform files

=head1 DESCRIPTION

A client for reading in JQTransform files

=cut

use Mouse;
use perfSONAR_PS::Client::PSConfig::BaseConnect;
use perfSONAR_PS::PSConfig::JQTransform;

extends 'perfSONAR_PS::Client::PSConfig::BaseConnect';

our $VERSION = 4.1;

sub config_obj {
    #return a perfSONAR_PS::Client::PSConfig::JQTransform object
    return new perfSONAR_PS::PSConfig::JQTransform();
}


__PACKAGE__->meta->make_immutable;

1;