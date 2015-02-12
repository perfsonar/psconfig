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
    my $mesh = $host_class->parent;

    my $host = perfSONAR_PS::MeshConfig::Config::Host->new();
    my $host_parent;

    my @local_ips = get_ips();

    # Merge a matching host block
    my $hosts = $mesh->lookup_hosts({ addresses => \@local_ips });
    if ($hosts and scalar(@$hosts) > 0) {
        if (scalar(@$hosts) > 1) {
            die("Multiple definitions for host with addresses: ".join(", ", @local_ips));
        }
        $host_parent = $hosts->[0]->parent; # Save the existing host parent since it may get used later...

        $host = $host->merge(other => $hosts->[0]);
    }

    if ($host_class->host_properties) {
        # Duplicate the host properties
        $host = $host->merge(other => $host_class->host_properties);
    }

    # Reset the parent object if we found it in the "lookup_hosts" case. Since
    # we're building a new host object based on the criteria here, this will be
    # a one-way pointer...
    $host->parent($host_parent) if $host_parent;

    # Fill in any new local IPs for the host
    my %existing_addresses = ();
    foreach my $addr (@{ $host->addresses }) {
        $existing_addresses{$addr->address} = $addr;
    }

    my @addresses = ();
    foreach my $ip (@local_ips) {
        if ($existing_addresses{$ip}) {
            push @addresses, $existing_addresses{$ip};
        }
        else {
            my $addr = perfSONAR_PS::MeshConfig::Config::Address->new();
            $addr->address($ip);
            $addr->parent($host);
            push @addresses, $addr;
        }
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
