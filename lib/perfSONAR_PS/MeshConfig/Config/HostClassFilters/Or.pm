package perfSONAR_PS::MeshConfig::Config::HostClassFilters::Or;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;
use Params::Validate qw(:all);

=head1 NAME

perfSONAR_PS::MeshConfig::Config::HostClassFilters::Or;

=head1 DESCRIPTION

=head1 API

=cut

use perfSONAR_PS::MeshConfig::Config::HostClassFilters::OperandBase;

extends 'perfSONAR_PS::MeshConfig::Config::HostClassFilters::OperandBase';

override 'type' => sub { "or" };

sub check_address {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { host_class => 1, address => 1 });
    my $host_class = $parameters->{host_class};
    my $address    = $parameters->{address};

    my $matches = 0;

    foreach my $filter (@{ $self->filters }) {
        if (not $filter->check_address(host_class => $host_class, address => $address)) {
            $matches = 1;
            last;
        }
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
