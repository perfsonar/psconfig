package perfSONAR_PS::PSConfig::PScheduler::ConfigConnect;

=head1 NAME

perfSONAR_PS::Client::PSConfig::ConfigConnect - A client for interacting pSConfig pScheduler agent configuration file

=head1 DESCRIPTION

A client for interacting pSConfig pScheduler agent configuration file

=cut

use Mouse;
use perfSONAR_PS::Client::PSConfig::BaseConnect;
use perfSONAR_PS::PSConfig::PScheduler::Config;

extends 'perfSONAR_PS::Client::PSConfig::BaseConnect';

our $VERSION = 4.1;

sub config_obj {
    #return a perfSONAR_PS::Client::PSConfig::Config object
    return new perfSONAR_PS::PSConfig::PScheduler::Config();
}


__PACKAGE__->meta->make_immutable;

1;