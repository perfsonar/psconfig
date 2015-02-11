package perfSONAR_PS::MeshConfig::Config::HostClassDataSources::RequestingAgent;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;
use Params::Validate qw(:all);

=head1 NAME

perfSONAR_PS::MeshConfig::Config::HostClassDataSources::RequestingAgent;

=head1 DESCRIPTION

=head1 API

=cut

use perfSONAR_PS::Utils::Host qw(get_ips);

extends 'perfSONAR_PS::MeshConfig::Config::HostClassDataSource';

sub BUILD {
    my ($self) = @_;
    $self->type("requesting_agent");
}

sub get_addresses {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { } );

    my $host_class = $self->parent;

    my $host;

    if ($host_class->host_properties) {
        # Duplicate the host properties
        $host = perfSONAR_PS::MeshConfig::Config::Host->parse($host->unparse);
    }
    else {
        $host = perfSONAR_PS::MeshConfig::Config::Host->new();
    }

    # Fill in the local IPs on the host
    my @addresses = ();
    foreach my $ip (get_ips()) {
        my $addr = perfSONAR_PS::MeshConfig::Config::Address->new();
        $addr->address($ip);
        $addr->parent($host);
        push @addresses, $addr;
    }

    $host->addresses(\@addresses);

    return \@addresses;
};

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS git repository is located at:

  https://code.google.com/p/perfsonar-ps/

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Base.pm 3658 2009-08-28 11:40:19Z aaron $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
