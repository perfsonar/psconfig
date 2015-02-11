package perfSONAR_PS::MeshConfig::Config::HostClassFilters;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;

use Params::Validate qw(:all);

use perfSONAR_PS::MeshConfig::Config::HostClassFilters::Netmask;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::OrganizationName;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::SiteName;
use perfSONAR_PS::MeshConfig::Config::HostClassFilters::AddressType;
#use perfSONAR_PS::MeshConfig::Config::HostClassFilters::InterfaceSpeed;
#use perfSONAR_PS::MeshConfig::Config::HostClassFilters::HostClass;

=head1 NAME

perfSONAR_PS::MeshConfig::Config::TestParameters;

=head1 DESCRIPTION

=head1 API

=cut

extends 'perfSONAR_PS::MeshConfig::Config::Base';

has 'type'                     => (is => 'rw', isa => 'Str');
has 'netmask_filters'          => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::Netmask]');
has 'organization_filters'     => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::OrganizationName]');
has 'site_filters'             => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::SiteName]');
has 'address_type_filters'     => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::AddressType]');
has 'interface_speed_filters'  => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::InterfaceSpeed]');
has 'interface_mtu_filters'    => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::InterfaceMTU]');
has 'host_class_filters'       => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClassFilters::HostClass]');

has 'parent'                   => (is => 'rw', isa => 'perfSONAR_PS::MeshConfig::Config::HostClass');

sub check_address {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { address => 0 });
    my $address = $parameters->{address};

    my @filter_sets = ();

    # Automagically grab the set of filters from the attributes (to avoid
    # duplicating the list of names).
    my $meta = $self->meta;
    for my $attribute ( map { $meta->get_attribute($_) } sort $meta->get_attribute_list ) {
        my $variable = $attribute->name;
        my $reader   = $attribute->get_read_method;

        next unless $variable =~ /_filters$/;

        my $filters = $self->$reader();

        next unless $filters;

        push @filter_sets, $filters;
    }

    # The semantics we're going for are that it must match all the different
    # types of filters, but may match any filter of each type. i.e. AND between
    # different filter types, OR between different filters of the same type.
    my $address_matches = 1;

    foreach my $filter_set (@filter_sets) {
        my $filter_set_matches;

        foreach my $filter (@$filter_set) {
            if ($filter->check_address(host_class => $self->parent, address => $address)) {
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
