package perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting;
use strict;
use warnings;

our $VERSION = 3.1;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);
use Encode qw(encode);

use utf8;

use perfSONAR_PS::MeshConfig::Generators::Base;

use perfSONAR_PS::RegularTesting::Utils::ConfigFile qw( parse_file save_string );

use perfSONAR_PS::RegularTesting::Config;
use perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondLatency;
use perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondThroughput;
use perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondTraceroute;
use perfSONAR_PS::RegularTesting::Test;
use perfSONAR_PS::RegularTesting::Schedulers::Streaming;
use perfSONAR_PS::RegularTesting::Tests::Powstream;
use perfSONAR_PS::RegularTesting::Schedulers::RegularInterval;
use perfSONAR_PS::RegularTesting::Tests::Bwctl;
use perfSONAR_PS::RegularTesting::Tests::Bwctl2;
use perfSONAR_PS::RegularTesting::Tests::Bwtraceroute;
use perfSONAR_PS::RegularTesting::Tests::Bwtraceroute2;
use perfSONAR_PS::RegularTesting::Tests::Bwping;
use perfSONAR_PS::RegularTesting::Tests::Bwping2;
use perfSONAR_PS::RegularTesting::Tests::BwpingOwamp;
use perfSONAR_PS::RegularTesting::Tests::Bwping2Owamp;

use Moose;

extends 'perfSONAR_PS::MeshConfig::Generators::Base';

has 'regular_testing_conf'   => (is => 'rw', isa => 'perfSONAR_PS::RegularTesting::Config');
has 'force_bwctl_owamp'      => (is => 'rw', isa => 'Bool');
has 'use_bwctl2'             => (is => 'rw', isa => 'Bool');
has 'configure_archives'     => (is => 'rw', isa => 'Bool');

=head1 NAME

perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting;

=head1 DESCRIPTION

=head1 API

=cut

my $logger = get_logger(__PACKAGE__);
my $default_summaries = {
    "throughput" => [
        {"event_type" => 'throughput', "summary_type" => 'average', "summary_window" => 86400},
    ],
    "latency" => [
        {"event_type" => 'packet-loss-rate', "summary_type" => 'aggregation', "summary_window" => 300},
        {"event_type" => 'histogram-owdelay', "summary_type" => 'aggregation', "summary_window" => 300},
        {"event_type" => 'histogram-owdelay', "summary_type" => 'statistics', "summary_window" => 300},
        {"event_type" => 'packet-loss-rate', "summary_type" => 'aggregation', "summary_window" => 3600},
        {"event_type" => 'packet-loss-rate-bidir', "summary_type" => 'aggregation', "summary_window" => 3600},
        {"event_type" => 'histogram-owdelay', "summary_type" => 'aggregation', "summary_window" => 3600},
        {"event_type" => 'histogram-rtt', "summary_type" => 'aggregation', "summary_window" => 3600},
        {"event_type" => 'histogram-owdelay', "summary_type" => 'statistics', "summary_window" => 3600},
        {"event_type" => 'histogram-rtt', "summary_type" => 'statistics', "summary_window" => 3600},
        {"event_type" => 'packet-loss-rate', "summary_type" => 'aggregation', "summary_window" => 86400},
        {"event_type" => 'packet-loss-rate-bidir', "summary_type" => 'aggregation', "summary_window" => 86400},
        {"event_type" => 'histogram-owdelay', "summary_type" => 'aggregation', "summary_window" => 86400},
        {"event_type" => 'histogram-rtt', "summary_type" => 'aggregation', "summary_window" => 86400},
        {"event_type" => 'histogram-owdelay', "summary_type" => 'statistics', "summary_window" => 86400},
        {"event_type" => 'histogram-rtt', "summary_type" => 'statistics', "summary_window" => 86400},
    ]
};


sub init {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         config_file     => 1,
                                         skip_duplicates => 1,
                                         force_bwctl_owamp => 0,
                                         use_bwctl2 => 0,
                                         configure_archives => 0,
                                      });

    my $config_file       = $parameters->{config_file};
    my $skip_duplicates   = $parameters->{skip_duplicates};
    my $force_bwctl_owamp = $parameters->{force_bwctl_owamp};
    my $use_bwctl2 = $parameters->{use_bwctl2};
    my $configure_archives = $parameters->{configure_archives};
    
    $self->SUPER::init({ config_file => $config_file, skip_duplicates => $skip_duplicates });

    my $config;
    eval {
        my ($status, $res) = parse_file(file => $config_file);
        if ($status != 0) {
            $logger->error("Problem parsing configuration file: $res");
            exit(-1);
        }

        my $conf = $res;

        $config = perfSONAR_PS::RegularTesting::Config->parse($res);

        # Remove the existing tests that were added by the mesh configuration
        my @new_tests = ();
        foreach my $test (@{ $config->tests }) {
            next if ($test->added_by_mesh);

            push @new_tests, $test;
        }

        $config->tests(\@new_tests);
        
         # Remove the existing archives that were added by the mesh configuration
        my @new_archives = ();
        foreach my $archive (@{ $config->measurement_archives }) {
            next if ($archive->added_by_mesh);

            push @new_archives, $archive;
        }

        $config->measurement_archives(\@new_archives);
    };
    if ($@) {
        my $msg = "Problem initializing pinger landmarks: ".$@;
        $logger->error($msg);
        return (-1, $msg);
    }

    $self->regular_testing_conf($config);
    $self->force_bwctl_owamp($force_bwctl_owamp) if defined $force_bwctl_owamp;
    $self->use_bwctl2($use_bwctl2) if defined $use_bwctl2;
    $self->configure_archives($configure_archives) if defined $configure_archives;
    
    return (0, "");
}

sub add_mesh_tests {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { mesh => 1, tests => 1, addresses => 1, local_host => 1 } );
    my $mesh   = $parameters->{mesh};
    my $tests  = $parameters->{tests};
    my $addresses = $parameters->{addresses};
    my $local_host = $parameters->{local_host};
    
    my %host_addresses = map { $_ => 1 } @$addresses;

    my %addresses_added = ();

    my $mesh_id = $mesh->description;
    $mesh_id =~ s/[^A-Za-z0-9_-]/_/g;

    my @tests = ();
    my %test_types = ();
    foreach my $test (@$tests) {
        if ($test->disabled) {
            $logger->debug("Skipping disabled test: ".$test->description);
            next;
        }

        $logger->debug("Adding: ".$test->description);

        if ($test->has_unknown_attributes) {
            die("Test '".$test->description."' has unknown attributes: ".join(", ", keys %{ $test->get_unknown_attributes }));
        }

        if ($test->parameters->has_unknown_attributes) {
            die("Test '".$test->description."' has unknown test parameters: ".join(", ", keys %{ $test->parameters->get_unknown_attributes }));
        }

        eval {
            my %sender_targets = ();
            my %receiver_targets = ();

            foreach my $pair (@{ $test->members->source_destination_pairs }) {
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
                    my %duplicate_params = %{$test->parameters->unparse()};
                    $duplicate_params{source} = $pair->{source}->{address};
                    $duplicate_params{destination} = $pair->{destination}->{address};
                    my $already_added = $self->__add_test_if_not_added(\%duplicate_params);

                    if ($already_added) {
                        $logger->debug("Test between ".$pair->{source}->{address}." to ".$pair->{destination}->{address}." already exists. Not re-adding");
                        next;
                    }
                }

                if ($host_addresses{$sender->{address}}) {
                    # We're the sender. We send in 3 cases:
                    #   1) We're doing ping/traceroute (since the far side might not have bwctl running, we set those up sender-side)
                    #   2) the far side is no_agent and won't be performing this test.
                    #   3) the force_bidirectional flag is set so we perform both send and receive
                    if ($receiver->{no_agent} or
                        ($test->parameters->can("force_bidirectional") and $test->parameters->force_bidirectional) or
                        ($test->parameters->type eq "traceroute" or $test->parameters->type eq "ping")) {

                        $receiver_targets{$sender->{address}} = [] unless $receiver_targets{$sender->{address}};
                        push @{ $receiver_targets{$sender->{address}} }, $receiver->{address};
                    }
                }
                else {
                    # We're the receiver. We receive in 3 cases:
                    #   1) We're not doing ping/traceroute (since the far side might not have bwctl running, we set those up sender-side)
                    #   2) the far side is no_agent and won't be performing this test.
                    #   3) the force_bidirectional flag is set so we perform both send and receive
                    if ($receiver->{no_agent} or
                        ($test->parameters->can("force_bidirectional") and $test->parameters->force_bidirectional) or
                        ($test->parameters->type ne "traceroute" or $test->parameters->type ne "ping")) {
                            $sender_targets{$receiver->{address}} = [] unless $sender_targets{$receiver->{address}};
                            push @{ $sender_targets{$receiver->{address}} }, $sender->{address};
                    }
                }
            }
    
            # Produce a nicer looking config file if the sender and receiver set are the same
            my $same_targets = 1;
            foreach my $target (keys %receiver_targets) {
                next if $sender_targets{$target};

                $same_targets = 0;
                last;
            }

            foreach my $target (keys %sender_targets) {
                next if $receiver_targets{$target};

                $same_targets = 0;
                last;
            }

            if ($same_targets) {
                my ($status, $res) = $self->__build_tests({ test => $test, targets => \%receiver_targets, target_receives => 1, target_sends => 1 });
                if ($status != 0) {
                    die("Problem creating tests: ".$res);
                }

                push @tests, @$res;
            }
            else {
                my ($status, $res) = $self->__build_tests({ test => $test, targets => \%receiver_targets, target_receives => 1 });
                if ($status != 0) {
                    die("Problem creating tests: ".$res);
                }

                push @tests, @$res;

                ($status, $res) = $self->__build_tests({ test => $test, targets => \%sender_targets, target_sends => 1 });
                if ($status != 0) {
                    die("Problem creating tests: ".$res);
                }
    
                push @tests, @$res;
            }
            
            #track test types
            $test_types{$test->parameters->type} = 1;

        };
        if ($@) {
            die("Problem adding test ".$test->description.": ".$@);
        }
    }
    
    #add measurement archives
    if($self->configure_archives()){
        my $has_latency_ma = 0;
        foreach my $test_type(keys %test_types){
            my $archive = $local_host->lookup_measurement_archive({ type => $test_type, recursive => 1 });
            if(!$archive){
                die("Unable to find measurement archive of type $test_type");
            }
            my $archive_obj;
            if ($test_type eq "pinger" || $test_type eq "perfsonarbuoy/owamp") {
                next if $has_latency_ma;
                $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondLatency();
                foreach my $summ(@{$default_summaries->{'latency'}}){
                    push @{$archive_obj->summary}, $archive_obj->create_summary_config(%{$summ});
                }
                $has_latency_ma = 1;
            }elsif ($test_type eq "traceroute") {
                $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondTraceroute();
            }elsif ($test_type eq "perfsonarbuoy/bwctl") {
                $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondThroughput();
                foreach my $summ(@{$default_summaries->{'throughput'}}){
                    push @{$archive_obj->summary}, $archive_obj->create_summary_config(%{$summ});
                }
            }
            $archive_obj->database($archive->write_url());
            $archive_obj->added_by_mesh(1);
            push @{ $self->regular_testing_conf->measurement_archives }, $archive_obj;
        }
        
    }

    push @{ $self->regular_testing_conf->tests }, @tests;

    return;
}

sub __build_tests {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { test => 1, targets => 1, target_sends => 0, target_receives => 0 });
    my $test = $parameters->{test};
    my $targets = $parameters->{targets};
    my $target_sends = $parameters->{target_sends};
    my $target_receives = $parameters->{target_receives};

    my @tests = ();
    foreach my $local_address (keys %{ $targets }) {
        my $test_obj = perfSONAR_PS::RegularTesting::Test->new();
        $test_obj->added_by_mesh(1);
        $test_obj->description($test->description) if $test->description;
        $test_obj->local_address($local_address);

        my @targets = ();
        foreach my $target (@{ $targets->{$local_address} }) {
            my $target_obj = perfSONAR_PS::RegularTesting::Target->new();
            $target_obj->address($target);
            push @targets, $target_obj;
        }
        $test_obj->targets(\@targets);

        my ($schedule, $parameters);

        if ($test->parameters->type eq "pinger") {
            if($self->use_bwctl2){
                $parameters = perfSONAR_PS::RegularTesting::Tests::Bwping2->new();
            }else{
                $parameters = perfSONAR_PS::RegularTesting::Tests::Bwping->new();
            }

            $parameters->packet_count($test->parameters->packet_count) if $test->parameters->packet_count;
            $parameters->packet_length($test->parameters->packet_size) if $test->parameters->packet_size;
            $parameters->packet_ttl($test->parameters->packet_ttl) if $test->parameters->packet_ttl;
            $parameters->inter_packet_time($test->parameters->packet_interval) if $test->parameters->packet_interval;
            $parameters->force_ipv4($test->parameters->ipv4_only) if $test->parameters->ipv4_only;
            $parameters->force_ipv6($test->parameters->ipv6_only) if $test->parameters->ipv6_only;

            $schedule   = perfSONAR_PS::RegularTesting::Schedulers::RegularInterval->new();
            $schedule->interval($test->parameters->test_interval);
            $schedule->random_start_percentage($test->parameters->random_start_percentage) if(defined $test->parameters->random_start_percentage);
        }
        elsif ($test->parameters->type eq "traceroute") {
            if($self->use_bwctl2){
                $parameters = perfSONAR_PS::RegularTesting::Tests::Bwtraceroute2->new();
            }else{
                $parameters = perfSONAR_PS::RegularTesting::Tests::Bwtraceroute->new();
            }

            $parameters->packet_length($test->parameters->packet_size) if $test->parameters->packet_size;
            $parameters->packet_first_ttl($test->parameters->first_ttl) if $test->parameters->first_ttl;
            $parameters->packet_max_ttl($test->parameters->max_ttl) if $test->parameters->max_ttl;
            $parameters->force_ipv4($test->parameters->ipv4_only) if $test->parameters->ipv4_only;
            $parameters->force_ipv6($test->parameters->ipv6_only) if $test->parameters->ipv6_only;

            $parameters->tool($test->parameters->tool) if $test->parameters->tool;

            $schedule   = perfSONAR_PS::RegularTesting::Schedulers::RegularInterval->new();
            $schedule->interval($test->parameters->test_interval) if $test->parameters->test_interval;
            $schedule->random_start_percentage($test->parameters->random_start_percentage) if(defined $test->parameters->random_start_percentage);
        }
        elsif ($test->parameters->type eq "perfsonarbuoy/bwctl") {
            if($self->use_bwctl2){
                $parameters = perfSONAR_PS::RegularTesting::Tests::Bwctl2->new();
            }else{
                $parameters = perfSONAR_PS::RegularTesting::Tests::Bwctl->new();
            }
            
            if($test->parameters->tool){
                my $tool = $test->parameters->tool;
                $tool =~ s/^bwctl\///;
                $parameters->tool($tool) ;
            }
            $parameters->use_udp($test->parameters->protocol eq "udp"?1:0);
            # $test{parameters}->{streams}  = $test->parameters->streams; # XXX: needs to support streams
            $parameters->duration($test->parameters->duration) if $test->parameters->duration;
            $parameters->omit_interval($test->parameters->omit_interval) if $test->parameters->omit_interval;
            $parameters->udp_bandwidth($test->parameters->udp_bandwidth) if $test->parameters->udp_bandwidth;
            $parameters->buffer_length($test->parameters->buffer_length) if $test->parameters->buffer_length;
            $parameters->packet_tos_bits($test->parameters->tos_bits) if $test->parameters->tos_bits;
            $parameters->streams($test->parameters->streams) if $test->parameters->streams;
            $parameters->window_size($test->parameters->window_size) if $test->parameters->window_size;
            $parameters->latest_time($test->parameters->latest_time) if $test->parameters->latest_time;
            $parameters->force_ipv4($test->parameters->ipv4_only) if $test->parameters->ipv4_only;
            $parameters->force_ipv6($test->parameters->ipv6_only) if $test->parameters->ipv6_only;

            $schedule   = perfSONAR_PS::RegularTesting::Schedulers::RegularInterval->new();
            $schedule->interval($test->parameters->interval) if $test->parameters->interval;
            $schedule->random_start_percentage($test->parameters->random_start_percentage) if(defined $test->parameters->random_start_percentage);
        }
        elsif ($test->parameters->type eq "perfsonarbuoy/owamp") {
            if ($self->force_bwctl_owamp) {
                if($self->use_bwctl2){
                    $parameters = perfSONAR_PS::RegularTesting::Tests::BwpingOwamp2->new();
                }else{
                    $parameters = perfSONAR_PS::RegularTesting::Tests::BwpingOwamp->new();
                }
                # Default to 25 second tests (could use sample_count, but the
                # 300 number might push those into the deny category)
                $parameters->packet_count(25/$test->parameters->packet_interval);
            }
            else {
                $parameters = perfSONAR_PS::RegularTesting::Tests::Powstream->new();
                $parameters->resolution($test->parameters->sample_count * $test->parameters->packet_interval) if $test->parameters->sample_count * $test->parameters->packet_interval;
            }
            $parameters->inter_packet_time($test->parameters->packet_interval);
            $parameters->packet_length($test->parameters->packet_padding);
            $parameters->force_ipv4($test->parameters->ipv4_only) if $test->parameters->ipv4_only;
            $parameters->force_ipv6($test->parameters->ipv6_only) if $test->parameters->ipv6_only;

            $schedule = perfSONAR_PS::RegularTesting::Schedulers::Streaming->new();
        }

        if ($target_sends and not $target_receives) {
            $parameters->send_only(1);
        }

        if ($target_receives and not $target_sends) {
            $parameters->receive_only(1);
        }

        $test_obj->parameters($parameters);
        $test_obj->schedule($schedule);

        push @tests, $test_obj;
    }

    return (0, \@tests);
}

sub get_config {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { });

    # Generate a Config::General version
    my ($status, $res) = save_string(config => $self->regular_testing_conf->unparse());

    return $res;
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
