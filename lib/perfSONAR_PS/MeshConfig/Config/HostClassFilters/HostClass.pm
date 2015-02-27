package perfSONAR_PS::MeshConfig::Config::HostClassFilters::HostClass;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;
use Params::Validate qw(:all);

=head1 NAME

perfSONAR_PS::MeshConfig::Config::HostClassFilters::HostClass;

=head1 DESCRIPTION

=head1 API

=cut

extends 'perfSONAR_PS::MeshConfig::Config::HostClassFilters::Base';

override 'type' => sub { "host_class" };

has 'class'        => (is => 'rw', isa => 'Str');

sub check_address {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { host_class => 1, address => 1 });
    my $host_class = $parameters->{host_class};
    my $address    = $parameters->{address};

    my $mesh = $host_class->parent;

    my $matches;

    foreach my $curr_class (@{ $mesh->host_classes }) {
        # Skip this host class because we can't answer that question.
        next if ($curr_class->name eq $host_class->name); 

        # Skip this host class if it's not the one we're checking
        next if ($self->class ne "any" and $curr_class->name ne $self->class); 

        foreach my $curr_addr (@{ $curr_class->get_addresses }) {
            if ($curr_addr->address eq $address->address) {
                $matches = 1;
                last;
            }
        }

        last if $matches;
    }

    return $matches;
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
