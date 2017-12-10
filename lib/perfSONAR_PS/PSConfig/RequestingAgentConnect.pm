package perfSONAR_PS::PSConfig::RequestingAgentConnect;

=head1 NAME

perfSONAR_PS::PSConfig::RequestingAgentConnect - A client for reading in requesting agent files

=head1 DESCRIPTION

A client for reading in requesting agent files

=cut

use Mouse;
use perfSONAR_PS::Client::PSConfig::BaseConnect;
use perfSONAR_PS::PSConfig::RequestingAgentConfig;

extends 'perfSONAR_PS::Client::PSConfig::BaseConnect';

our $VERSION = 4.1;

sub config_obj {
    #return a perfSONAR_PS::PSConfig::RequestingAgentConfig object
    return new perfSONAR_PS::PSConfig::RequestingAgentConfig();
}


__PACKAGE__->meta->make_immutable;

1;