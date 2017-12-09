package perfSONAR_PS::PSConfig::ArchiveConnect;

=head1 NAME

perfSONAR_PS::PSConfig::ArchiveConnect - A client for reading in archiver files

=head1 DESCRIPTION

A client for reading in archiver files

=cut

use Mouse;
use perfSONAR_PS::Client::PSConfig::BaseConnect;
use perfSONAR_PS::Client::PSConfig::Archive;

extends 'perfSONAR_PS::Client::PSConfig::BaseConnect';

our $VERSION = 4.1;

sub config_obj {
    #return a perfSONAR_PS::Client::PSConfig::Archive object
    return new perfSONAR_PS::Client::PSConfig::Archive();
}


__PACKAGE__->meta->make_immutable;

1;