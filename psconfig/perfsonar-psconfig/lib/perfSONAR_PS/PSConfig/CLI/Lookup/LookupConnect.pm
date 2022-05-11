package perfSONAR_PS::PSConfig::CLI::Lookup::LookupConnect;

=head1 NAME

perfSONAR_PS::PSConfig::CLI::Lookup::LookupConnect - A client for reading in pSConfig lookup files

=head1 DESCRIPTION

A client for reading in pSConfig lookup files

=cut

use Mouse;
use perfSONAR_PS::Client::PSConfig::BaseConnect;
use perfSONAR_PS::PSConfig::CLI::Lookup::LookupConfig;

extends 'perfSONAR_PS::Client::PSConfig::BaseConnect';

our $VERSION = 4.1;

sub config_obj {
    #return a perfSONAR_PS::PSConfig::CLI::LookupConfig object
    return new perfSONAR_PS::PSConfig::CLI::Lookup::LookupConfig();
}


__PACKAGE__->meta->make_immutable;

1;