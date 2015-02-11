package perfSONAR_PS::MeshConfig::Config::HostClassDataSource;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;

use perfSONAR_PS::MeshConfig::Config::HostClassDataSources::Mesh;
use perfSONAR_PS::MeshConfig::Config::HostClassDataSources::CurrentMesh;
use perfSONAR_PS::MeshConfig::Config::HostClassDataSources::RequestingAgent;

=head1 NAME

perfSONAR_PS::MeshConfig::Config::TestParameters;

=head1 DESCRIPTION

=head1 API

=cut

extends 'perfSONAR_PS::MeshConfig::Config::Base';

has 'type'                => (is => 'rw', isa => 'Str');

has 'parent'                   => (is => 'rw', isa => 'perfSONAR_PS::MeshConfig::Config::HostClass');

override 'parse' => sub {
    my ($class, $description, $strict) = @_;

    if ($class eq __PACKAGE__) {
        unless ($description->{type}) {
            die("Unspecified test parameters type");
        }

        if ($description->{type} eq "mesh") {
            return perfSONAR_PS::MeshConfig::Config::HostClassDataSources::Mesh->parse($description, $strict);
        }
        elsif ($description->{type} eq "current_mesh") {
            return perfSONAR_PS::MeshConfig::Config::HostClassDataSources::CurrentMesh->parse($description, $strict);
        }
        elsif ($description->{type} eq "requesting_agent") {
            return perfSONAR_PS::MeshConfig::Config::HostClassDataSources::RequestingAgent->parse($description, $strict);
        }
        else {
            die("Unknown host class data source type: ".$description->{type});
        }
    }
    else {
        return super($class, $description, $strict);
    }
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
