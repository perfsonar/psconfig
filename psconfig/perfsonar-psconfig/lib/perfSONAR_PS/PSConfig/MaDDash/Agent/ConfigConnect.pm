package perfSONAR_PS::PSConfig::MaDDash::Agent::ConfigConnect;

=head1 NAME

perfSONAR_PS::PSConfig::MaDDash::Agent::ConfigConnect - A client for interacting pSConfig MaDDash agent configuration file

=head1 DESCRIPTION

A client for interacting pSConfig MaDDash agent configuration file

=cut

use Mouse;
use perfSONAR_PS::Client::PSConfig::BaseConnect;
use perfSONAR_PS::PSConfig::MaDDash::Agent::Config;

extends 'perfSONAR_PS::Client::PSConfig::BaseConnect';

our $VERSION = 4.1;

=item config_obj()

Overridden method that returns perfSONAR_PS::PSConfig::MaDDash::Agent::Config instance

=cut

sub config_obj {
    return new perfSONAR_PS::PSConfig::MaDDash::Agent::Config();
}


__PACKAGE__->meta->make_immutable;

1;