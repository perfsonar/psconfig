package perfSONAR_PS::MeshConfig::Config::Address;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;
use Params::Validate qw(:all);

=head1 NAME

perfSONAR_PS::MeshConfig::Config::Host;

=head1 DESCRIPTION

=head1 API

=cut

extends 'perfSONAR_PS::MeshConfig::Config::Base';

has 'address'             => (is => 'rw', isa => 'Str');
has 'tags'                => (is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] });

has 'parent'              => (is => 'rw', isa => 'perfSONAR_PS::MeshConfig::Config::Host');

override 'parse' => sub {
    my ($class, $description, $strict) = @_;

    # For backwards compatibility, convert it to an object if it's just a
    # string
    unless (ref($description)) { 
        $description = { address => $description };
    }

    return $class->SUPER::parse($description, $strict);
};

override 'unparse' => sub {
    my ($self) = @_;

    my $object = super();

   # For backwards compatibility, convert it from an object to a string if
   # it doesn't use any of the properties of the object other than 'address'
   if (scalar(keys %$object) == 1 and $object->{address}) {
        $object = $object->{address};
    }

    return $object;
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
