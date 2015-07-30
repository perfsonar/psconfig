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

use perfSONAR_PS::MeshConfig::Config::HostClassDataSources::CurrentMesh;
use perfSONAR_PS::MeshConfig::Config::HostClassDataSources::RequestingAgent;

use perfSONAR_PS::MeshConfig::Config::HostClassFilters::AddressType;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::And;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::HostClass;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::Netmask;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::Not;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::Organization;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::Or;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::Site;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::Tag;

extends 'perfSONAR_PS::MeshConfig::Config::Base';

has 'name'                => (is => 'rw', isa => 'Str');

has 'data_sources'        => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassDataSources::Base]', default => sub { [] });
has 'match_filters'       => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::Base]', default => sub { [] });
has 'exclude_filters'     => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::Base]', default => sub { [] });

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
    foreach my $address (@addresses) {
        my $matches = 0;

        # An empty match filters means match everything
        if (scalar(@{ $self->match_filters }) == 0 or
            $self->check_filters(address => $address, filters => $self->match_filters)) {
            $matches = 1;
        }

        next unless $matches;

        # An empty exclude filters means don't exclude anything
        if (scalar(@{ $self->exclude_filters }) > 0 and
            $self->check_filters(address => $address, filters => $self->exclude_filters)) {
            $matches = 0;
        }

        push @filtered_addresses, $address if $matches;
    }

    @addresses = @filtered_addresses;

    return \@addresses;
}

sub check_filters {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { filters => 1, address => 1 });
    my $filters = $parameters->{filters};
    my $address = $parameters->{address};

    my %filters_by_type = ();
    foreach my $filter (@$filters) {
        my $type = $filter->type;
        $filters_by_type{$type} = [] unless ($filters_by_type{$type});

        push @{ $filters_by_type{$type} }, $filter;
    }

    my @filter_sets = values %filters_by_type;

    # The semantics we're going for are that it must match all the different
    # types of filters, but may match any filter of each type. i.e. AND between
    # different filter types, OR between different filters of the same type.
    my $address_matches = 1;

    foreach my $filter_set (@filter_sets) {
        my $filter_set_matches;

        foreach my $filter (@$filter_set) {
            if ($filter->check_address(host_class => $self, address => $address)) {
                $filter_set_matches = 1;
                last;
            }
        }

        unless ($filter_set_matches) {
            $address_matches = 0;
            last;
        }
    }

    return $address_matches;
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
