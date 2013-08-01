package perfSONAR_PS::Utils::HTTPS;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Utils::HTTPS

=head1 DESCRIPTION

A module that provides simple functions for retrieving HTTPS URLs that validate
the certificate.

=head1 API

=cut

use base 'Exporter';
use Params::Validate qw(:all);
use Net::SSL;
use LWP::UserAgent;
use LWP::Protocol::https;
use HTTP::Request;
use Log::Log4perl qw(get_logger);

our @EXPORT_OK = qw( https_get );

my $logger = get_logger(__PACKAGE__);

=head2 https_get()

=cut

sub https_get {
    my $parameters = validate( @_, { url => 1,
                                     verify_hostname => 0,
                                     verify_certificate => 0,
                                     ca_certificate_path  => 0,
                                     ca_certificate_file => 0,
                                     max_redirects => 0,
                                   });
    my $url = $parameters->{url};
    my $verify_certificate = $parameters->{verify_certificate};
    my $verify_hostname = $parameters->{verify_hostname};
    my $ca_certificate_path = $parameters->{ca_certificate_path};
    my $ca_certificate_file = $parameters->{ca_certificate_file};
    my $max_redirects = $parameters->{max_redirects};

    my $uri = URI->new($url);
    unless ($uri->scheme) {
        return (-1, "Invalid url: $url");
    }

    my %existing_env = %ENV;

    if (lc($uri->scheme) eq "https") {
        $ENV{HTTPS_DEBUG} = 1;

        $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "Net::SSL";
        $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 1;

        if ($verify_certificate) {
            unless ($ENV{HTTPS_CA_FILE} or $ca_certificate_file or $ca_certificate_path) {
                $ca_certificate_file = "/etc/pki/tls/bundle.crt";
            }
            $ENV{HTTPS_CA_FILE} = $ca_certificate_file if $ca_certificate_file;;
            $ENV{HTTPS_CA_DIR}  = $ca_certificate_path if $ca_certificate_path;
        }

        if ($ENV{HTTPS_PROXY}) {
            $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
        }
    }

    my $ua = LWP::UserAgent->new(env_proxy => 1, timeout => 10, max_redirects => $max_redirects);
    if ($verify_hostname) {
        $ua->default_header("If-SSL-Cert-Subject"=>"CN=".$uri->host);
    }

    my $req = HTTP::Request->new(GET => $url);
    my $response = $ua->request($req);

    %ENV = %existing_env;

    if ($response->is_success) {
        my $results = $response->decoded_content?$response->decoded_content:$response->content;

        return (0, $results);
    }
    else {
        my $msg = "Problem retrieving $url: ".$response->status_line;
        $logger->debug($msg);
        return (-1, $msg);
    }
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Host.pm 5139 2012-06-01 15:48:46Z aaron $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
