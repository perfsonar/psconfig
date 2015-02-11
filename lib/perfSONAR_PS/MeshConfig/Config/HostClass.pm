package perfSONAR_PS::MeshConfig::Config::HostClass;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;
use Params::Validate qw(:all);

=head1 NAME

perfSONAR_PS::MeshConfig::Config::HostClass;

=head1 DESCRIPTION

=head1 API

=cut

use perfSONAR_PS::MeshConfig::Config::HostClassDataSource;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters;

extends 'perfSONAR_PS::MeshConfig::Config::Base';

has 'name'                => (is => 'rw', isa => 'Str');

has 'data_sources'        => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassDataSource]', default => sub { [] });
has 'match_filters'       => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters]', default => sub { [] });
has 'exclude_filters'     => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters]', default => sub { [] });

has 'host_properties'     => (is => 'rw', isa => 'perfSONAR_PS::MeshConfig::Config::Host');

has 'parent'              => (is => 'rw', isa => 'perfSONAR_PS::MeshConfig::Config::Mesh');

sub get_addresses {
    my ($self) = @_;

    # Grab all the addresses from our data sources
    my @addresses = ();
    foreach my $data_source (@{ $self->data_sources }) {
        push @addresses, @{ $data_source->get_addresses };
    }

    # Select only those addresses that match the match filters
    my @filtered_addresses = ();
    foreach my $addr (@addresses) {
        my $matches = 1;

        foreach my $filter (@{ $self->match_filters }) {
            unless ($filter->check_address(address => $addr)) {
                $matches = 0;
                last;
            }
        }

        push @filtered_addresses, $addr if $matches;
    }

    @addresses = @filtered_addresses;

    # Remove any addresses that should be filtered
    @filtered_addresses = ();
    foreach my $addr (@addresses) {
        my $excluded = 0;

        foreach my $filter (@{ $self->exclude_filters }) {
            if ($filter->check_address(address => $addr)) {
                $excluded = 1;
                last;
            }
        }

        push @filtered_addresses, $addr unless $excluded;
    }

    @addresses = @filtered_addresses;

    return \@addresses;
}

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
