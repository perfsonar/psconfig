package perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting;
use strict;
use warnings;

our $VERSION = 3.1;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);
use Config::General;
use Encode qw(encode);

use utf8;

use perfSONAR_PS::MeshConfig::Generators::Base;

use Moose;

extends 'perfSONAR_PS::MeshConfig::Generators::Base';

has 'regular_testing_conf'   => (is => 'rw', isa => 'HashRef');

=head1 NAME

perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting;

=head1 DESCRIPTION

=head1 API

=cut

my $logger = get_logger(__PACKAGE__);

sub init {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         config_file     => 1,
                                         skip_duplicates => 1,
                                      });

    my $config_file     = $parameters->{config_file};
    my $skip_duplicates = $parameters->{skip_duplicates};

    $self->SUPER::init({ config_file => $config_file, skip_duplicates => $skip_duplicates });

    my $config;
    eval {
        my $conf_general = Config::General->new(-ConfigFile => $self->config_file);
        my %conf_general = $conf_general->getall();

        $config = $self->__parse_regular_testing({ existing_configuration => \%conf_general });
    };
    if ($@) {
        my $msg = "Problem initializing pinger landmarks: ".$@;
        $logger->error($msg);
        return (-1, $msg);
    }

    $self->regular_testing_conf($config);

    return (0, "");
}

sub add_mesh_tests {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { mesh => 1, tests => 1, host => 1 } );
    my $mesh  = $parameters->{mesh};
    my $tests = $parameters->{tests};
    my $host  = $parameters->{host};

    my %host_addresses = map { $_ => 1 } @{ $host->addresses };

    my %addresses_added = ();

    my $mesh_id = $mesh->description;
    $mesh_id =~ s/[^A-Za-z0-9_-]/_/g;

    my @tests = ();
    foreach my $test (@$tests) {
        if ($test->disabled) {
            $logger->debug("Skipping disabled test: ".$test->description);
            next;
        }

        $logger->debug("Adding: ".$test->description);

        eval {
            my %sender_targets = ();
            my %receiver_targets = ();

            foreach my $pair (@{ $test->members->source_destination_pairs }) {
                my $matching_hosts = $mesh->lookup_hosts({ addresses => [ $pair->{destination}->{address} ] });
                my $host_properties = $matching_hosts->[0];

                my $sender = $pair->{"source"};
                my $receiver = $pair->{"destination"};

                # skip if we're not a sender or receiver.
                next unless ($host_addresses{$sender->{address}} or $host_addresses{$receiver->{address}});

                # skip if it's a loopback test.
                next if ($host_addresses{$sender->{address}} and $host_addresses{$receiver->{address}});

                # skip if we're 'no_agent'
                next if (($host_addresses{$sender->{address}} and $sender->{no_agent}) or
                           ($host_addresses{$receiver->{address}} and $receiver->{no_agent}));

                if ($self->skip_duplicates) {
                    # Check if a specific test (i.e. same
                    # source/destination/test parameters) has been added
                    # before, and if so, don't add it.
                    my $already_added = $self->__add_test_if_not_added({ 
                                                                         source             => $pair->{source}->{address},
                                                                         destination        => $pair->{destination}->{address},
                                                                         parameters         => $test->parameters,
                                                                     });

                    if ($already_added) {
                        $logger->debug("Test between ".$pair->{source}->{address}." to ".$pair->{destination}->{address}." already exists. Not re-adding");
                        next;
                    }
                }

                if ($host_addresses{$pair->{source}->{address}}) {
                    $receiver_targets{$pair->{source}->{address}} = [] unless $receiver_targets{$pair->{source}->{address}};
                    push @{ $receiver_targets{$pair->{source}->{address}} }, $pair->{destination}->{address};
                }

                if ($host_addresses{$pair->{destination}->{address}}) {
                    $sender_targets{$pair->{destination}->{address}} = [] unless $receiver_targets{$pair->{destination}->{address}};
                    push @{ $sender_targets{$pair->{destination}->{address}} }, $pair->{source}->{address};
                }
            }

            my ($status, $res) = $self->__build_tests({ test => $test, targets => \%receiver_targets, is_sender => 1 });
            if ($status != 0) {
                die("Problem creating tests: ".$res);
            }

            push @tests, @$res;

            ($status, $res) = $self->__build_tests({ test => $test, targets => \%sender_targets,   is_sender => 0 });
            if ($status != 0) {
                die("Problem creating tests: ".$res);
            }

            push @tests, @$res;

        };
        if ($@) {
            die("Problem adding test ".$test->description.": ".$@);
        }
    }

    push @{ $self->regular_testing_conf->{test} }, @tests;

    return;
}

sub __build_tests {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { test => 1, targets => 1, is_sender => 1 });
    my $test = $parameters->{test};
    my $targets = $parameters->{targets};
    my $is_sender = $parameters->{is_sender};

    my @tests = ();
    foreach my $local_address (keys %{ $targets }) {
        my %test = ();
        $test{added_by_mesh} = 1;
        $test{description} = $test->description;
        $test{local_address} = $local_address;
        $test{target} = $targets->{$local_address};

        $test{parameters} = {};
        $test{schedule}   = {};

        if ($test->parameters->type eq "pinger") {
            $test{parameters}->{type} = "bwping";
            $test{parameters}->{packet_count} = $test->parameters->packet_count;
            $test{parameters}->{packet_length} = $test->parameters->packet_size;
            $test{parameters}->{packet_ttl} = $test->parameters->packet_ttl;
            $test{parameters}->{inter_packet_time} = $test->parameters->inter_packet_time;
            $test{parameters}->{force_ipv4} = $test->parameters->ipv4_only;
            $test{parameters}->{force_ipv6} = $test->parameters->ipv6_only;

            $test{schedule}->{type} = "regular_intervals";
            $test{schedule}->{interval} = $test->parameters->test_interval;
        }
        elsif ($test->parameters->type eq "traceroute") {
            $test{parameters}->{type} = "bwtraceroute";
            $test{parameters}->{packet_length} = $test->parameters->packet_size;
            $test{parameters}->{packet_first_ttl} = $test->parameters->first_ttl;
            $test{parameters}->{packet_last_ttl} = $test->parameters->max_ttl;
            $test{parameters}->{force_ipv4} = $test->parameters->ipv4_only;
            $test{parameters}->{force_ipv6} = $test->parameters->ipv6_only;

            $test{schedule}->{type} = "regular_intervals";
            $test{schedule}->{interval} = $test->parameters->test_interval;
        }
        elsif ($test->parameters->type eq "perfsonarbuoy/bwctl") {
            $test{parameters}->{type} = "bwctl";
            $test{parameters}->{use_udp} = $test->parameters->protocol eq "udp"?1:0;
            # $test{parameters}->{streams}  = $test->parameters->streams; # XXX: needs to support streams
            $test{parameters}->{duration} = $test->parameters->duration;
            $test{parameters}->{udp_bandwidth} = $test->parameters->udp_bandwidth;
            $test{parameters}->{buffer_length} = $test->parameters->buffer_length;
            $test{parameters}->{force_ipv4} = $test->parameters->ipv4_only;
            $test{parameters}->{force_ipv6} = $test->parameters->ipv6_only;

            $test{schedule}->{type} = "regular_intervals";
            $test{schedule}->{interval} = $test->parameters->test_interval;
        }
        elsif ($test->parameters->type eq "perfsonarbuoy/owamp") {
            $test{parameters}->{type} = "powstream";
            $test{parameters}->{resolution} = $test->parameters->sample_count * $test->parameters->packet_interval;
            $test{parameters}->{inter_packet_time} = $test->parameters->packet_interval;
            $test{parameters}->{force_ipv4} = $test->parameters->ipv4_only;
            $test{parameters}->{force_ipv6} = $test->parameters->ipv6_only;

            $test{schedule}->{type} = "streaming";
        }

        if ($is_sender) {
            $test{parameters}->{send_only} = 1;
        }
        else {
            $test{parameters}->{receiver_only} = 1;
        }

        push @tests, \%test;
    }

    use Data::Dumper;
    print STDERR "Running: ".Dumper(\@tests)."\n";

    return (0, \@tests);
}

sub get_regular_testing_conf {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { });

    my $output;

    return $self->__generate_config_general(undef, $self->regular_testing_conf, 0);
}

sub __generate_config_general {
   my ($self, $key, $value, $depth) = @_;

   return unless defined $value;

   my $output = "";

   my $spacer = "";
   for(my $i = 0; $i < $depth; $i++) {
       $spacer .= "\t"
   }

   if (ref($value) eq "HASH") {
       $output .= $spacer."<".$key.">\n" if ($key);
       foreach my $hash_key (keys %$value) {
           my $res = $self->__generate_config_general($hash_key, $value->{$hash_key}, $depth + 1);
           $output .= $res if $res;
       }
       $output .= $spacer."</".$key.">\n" if ($key);
   }
   elsif (ref($value) eq "ARRAY") {
       foreach my $array_elm (@$value) {
           $output .= $self->__generate_config_general($key, $array_elm, $depth);
       }
   }
   else {
       $output .= $spacer."$key\t\t$value\n";
   }

   return $output;
}

sub __parse_regular_testing {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { existing_configuration => 1 });
    my $existing_configuration = $parameters->{existing_configuration};

    return $self->__strip_added_by_mesh({ value => $existing_configuration });
}

sub __strip_added_by_mesh {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { value => 1 });
    my $value = $parameters->{value};

    if (ref($value) eq "HASH") {
        my %new_hash = ();

        return if ($value->{added_by_mesh});

        foreach my $key (keys %$value) {
            my $hash_value = $value->{$key};

            $new_hash{$key} = $self->__strip_added_by_mesh({ value => $hash_value });
        }

        return \%new_hash;
    }
    elsif (ref($value) eq "ARRAY") {
        my @new_array = ();
        foreach my $array_elm (@$value) {
            my $new_value = $self->__strip_added_by_mesh({ value => $array_elm });
            push @new_array, $new_value if defined $new_value;
        }
        return \@new_array;
    }
    else {
        return $value;
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
