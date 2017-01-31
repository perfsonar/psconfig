package perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting;
use strict;
use warnings;

our $VERSION = 3.1;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);
use Encode qw(encode);
use Data::Dumper qw(Dumper);
use utf8;

use perfSONAR_PS::MeshConfig::Generators::Base;

use perfSONAR_PS::RegularTesting::Utils::ConfigFile qw( parse_file save_string );

use perfSONAR_PS::RegularTesting::Config;
use perfSONAR_PS::RegularTesting::CreatedBy;
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
my $default_summaries = {};


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
            die("Problem parsing configuration file: $res");
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
    my $parameters = validate( @args, { mesh => 1, mesh_url => 1, tests => 1, addresses => 1, local_host => 1, host_classes => 1, requesting_agent => 1, configure_archives => 0 } );
    my $mesh   = $parameters->{mesh};
    my $mesh_url   = $parameters->{mesh_url};
    my $tests  = $parameters->{tests};
    my $addresses = $parameters->{addresses};
    my $local_host = $parameters->{local_host};
    my $host_classes = $parameters->{host_classes};
    my $requesting_agent = $parameters->{requesting_agent};
    my $configure_archives = ($parameters->{configure_archives} || (!defined $parameters->{configure_archives} && $self->configure_archives()));
    
    #set created-by
    my $created_by = new perfSONAR_PS::RegularTesting::CreatedBy({
        'agent_type' => "remote-mesh",
        'name' => $mesh->description,
        'uri' => $mesh_url,
    });
    
    my %host_addresses = map { $_ => 1 } @$addresses;

    my %addresses_added = ();

    my $mesh_id = $mesh->description;
    $mesh_id =~ s/[^A-Za-z0-9_-]/_/g if($mesh_id);
    
    #add measurement archives that apply to all tests setup by the mesh
    my $ma_map = {
            "pinger" => {}, 
            "perfsonarbuoy/owamp" => {}, 
            "perfsonarbuoy/bwctl" => {}, 
            "traceroute" => {},
            "simplestream" => {},
            };
    if($configure_archives){
        foreach my $test_type(keys %{$ma_map}){
            #lookup archive in explicit hosts and host classes. Append them all together if multiple match
            my @archives = ();
            if($local_host){
                my $host_archives = $local_host->lookup_measurement_archives({ type => $test_type, recursive => 1 });
                push @archives, @{$host_archives} if($host_archives);
            }
            #lookup archives in host classes
            foreach my $host_class(@{$host_classes}){
                if($host_class->host_properties){
                    my $hc_archives = $host_class->host_properties->lookup_measurement_archives({ type => $test_type, recursive => 1 });
                    push @archives, @{$hc_archives} if($hc_archives);
                }
            }
            #lookup archives in requesting agent
            if($requesting_agent){
                 my $agent_archives = $requesting_agent->lookup_measurement_archives({ type => $test_type, recursive => 1 });
                 push @archives, @{$agent_archives} if($agent_archives);
            }
            
            #iterate through archives skipping duplicates (same URL + same type)
            foreach my $archive(@archives){
                next if $ma_map->{$test_type}->{$archive->write_url()};
                $ma_map->{$test_type}->{$archive->write_url()} = $self->__build_archive(test_type => $test_type, archive => $archive);
            }
        }
        
    }
    
    #define tests
    my @tests = ();
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

                #figure out mapped addresses 
                my $sender_address   = $self->__lookup_mapped_address(address_map_field => $test->members->address_map_field, local_addr_maps => $sender->{addr_obj}->maps, local_address => $sender->{address}, remote_address => $receiver->{address}, exclude_unmapped => $test->members->exclude_unmapped);
                my $receiver_address = $self->__lookup_mapped_address(address_map_field => $test->members->address_map_field, local_addr_maps => $receiver->{addr_obj}->maps, local_address => $receiver->{address}, remote_address => $sender->{address}, exclude_unmapped => $test->members->exclude_unmapped);
                #skip this test - this means that i don't have a mapping for one or more hosts and exclude_unmapped was enabled
                next unless($sender_address && $receiver_address);
                 
                if ($self->skip_duplicates) {
                    # Check if a specific test (i.e. same
                    # source/destination/test parameters) has been added
                    # before, and if so, don't add it.
                    my %duplicate_params = %{$test->parameters->unparse()};
                    $duplicate_params{source} = $sender_address ;
                    $duplicate_params{destination} = $receiver_address;
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

                        $receiver_targets{$sender_address} = [] unless $receiver_targets{$sender_address};
                        push @{ $receiver_targets{$sender_address} }, $receiver_address;
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
                            $sender_targets{$receiver_address} = [] unless $sender_targets{$receiver_address};
                            push @{ $sender_targets{$receiver_address} }, $sender_address;
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
                my ($status, $res) = $self->__build_tests({ test => $test, targets => \%receiver_targets, target_receives => 1, target_sends => 1, created_by => $created_by, ma_map => $ma_map, configure_archives => $configure_archives });
                if ($status != 0) {
                    die("Problem creating tests: ".$res);
                }

                push @tests, @$res;
            }
            else {
                my ($status, $res) = $self->__build_tests({ test => $test, targets => \%receiver_targets, target_receives => 1, created_by => $created_by, ma_map => $ma_map, configure_archives => $configure_archives  });
                if ($status != 0) {
                    die("Problem creating tests: ".$res);
                }

                push @tests, @$res;

                ($status, $res) = $self->__build_tests({ test => $test, targets => \%sender_targets, target_sends => 1, created_by => $created_by, ma_map => $ma_map, configure_archives => $configure_archives  });
                if ($status != 0) {
                    die("Problem creating tests: ".$res);
                }
    
                push @tests, @$res;
            }
        };
        if ($@) {
            die("Problem adding test ".$test->description.": ".$@);
        }
    }
    
    

    push @{ $self->regular_testing_conf->tests }, @tests;

    return;
}

sub __build_archive(){
    my ($self, @args) = @_;
    my $parameters = validate( @args, { test_type => 1, archive => 1 });
    my $test_type = $parameters->{test_type};
    my $archive = $parameters->{archive};
    
    my $archive_obj;
    if ($test_type eq "pinger") {
        $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondLatency();
        foreach my $summ(@{$default_summaries->{'latency'}}){
            push @{$archive_obj->summary}, $archive_obj->create_summary_config(%{$summ});
        }
    }elsif ($test_type eq "perfsonarbuoy/owamp") {
        $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondLatency();
        foreach my $summ(@{$default_summaries->{'latency'}}){
            push @{$archive_obj->summary}, $archive_obj->create_summary_config(%{$summ});
        }
    }elsif ($test_type eq "traceroute") {
        $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondTraceroute();
    }elsif ($test_type eq "perfsonarbuoy/bwctl") {
        $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondThroughput();
        foreach my $summ(@{$default_summaries->{'throughput'}}){
            push @{$archive_obj->summary}, $archive_obj->create_summary_config(%{$summ});
        }
    }elsif ($test_type eq "simplestream") {
        $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondThroughput();
    }
    $archive_obj->database($archive->write_url());
    $archive_obj->added_by_mesh(1);
    
    return $archive_obj;
}
sub __lookup_mapped_address {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { address_map_field => 1, local_addr_maps => 1, local_address => 1, remote_address => 1, exclude_unmapped => 1});
    my $address_map_field = $parameters->{address_map_field};
    my $local_addr_maps = $parameters->{local_addr_maps};
    my $local_address = $parameters->{local_address};
    my $remote_address = $parameters->{remote_address};
    my $exclude_unmapped = $parameters->{exclude_unmapped};
    
    #if not mapped field, just return
    return $local_address unless($address_map_field);
    
    #go through map and find field - also ignore meaningless exclude_unmapped in this case
    my $found_default = 0;
    foreach my $addr_map(@{$local_addr_maps}){
        if($addr_map->remote_address eq $remote_address){
            foreach my $addr_map_field(@{$addr_map->fields}){
                if($addr_map_field->name eq $address_map_field){
                    return $addr_map_field->value;
                }
            }
        }elsif($addr_map->remote_address eq 'default'){
            #use default, but keep looking in case we find something better
            foreach my $addr_map_field(@{$addr_map->fields}){
                if($addr_map_field->name eq $address_map_field){
                    $local_address = $addr_map_field->value;
                    $found_default = 1;
                }
            }
        }
    }
    
    #if we got here and $exclude_unmapped set, then return unless we got a default value
    if(!$found_default && $exclude_unmapped){
        return undef;
    }
    
    return $local_address;
}

sub __build_tests {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { test => 1, targets => 1, target_sends => 0, target_receives => 0, created_by => 1, ma_map => 1, configure_archives => 1  });
    my $test = $parameters->{test};
    my $targets = $parameters->{targets};
    my $target_sends = $parameters->{target_sends};
    my $target_receives = $parameters->{target_receives};
    my $created_by = $parameters->{created_by};
    my $ma_map = $parameters->{ma_map};
    my $configure_archives = $parameters->{configure_archives};
    
    my @tests = ();
    foreach my $local_address (keys %{ $targets }) {
        my $test_obj = perfSONAR_PS::RegularTesting::Test->new();
        $test_obj->created_by($created_by);
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
        
        #add archives to test if needed
        if($configure_archives){
            my @measument_archives = ();
            my $test_archives = $test->lookup_measurement_archives({ type => $test->parameters->type });
            if($test_archives){
                foreach my $test_archive(@{$test_archives}){
                    if(!$ma_map->{$test->parameters->type}->{$test_archive->write_url()}){
                        my $test_archive_obj = $self->__build_archive( test_type => $test->parameters->type, archive => $test_archive);
                        push @measument_archives, $test_archive_obj if($test_archive_obj);
                    }
                }
            }
            
            foreach my $ma_url(keys %{$ma_map->{$test->parameters->type}}){
                push @measument_archives, $ma_map->{$test->parameters->type}->{$ma_url};
            }
            if(@measument_archives > 0){
                $test_obj->measurement_archives(\@measument_archives);
            }else{
                $logger->warn("Unable to find measurement archive for test '" . $test_obj->description . "'. Proceeding with test but results will not be stored.");
            }
        }
        
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
            $parameters->flowlabel($test->parameters->flowlabel) if $test->parameters->flowlabel;
            $parameters->hostnames($test->parameters->hostnames) if $test->parameters->hostnames;
            $parameters->suppress_loopback($test->parameters->suppress_loopback) if $test->parameters->suppress_loopback;
            $parameters->deadline($test->parameters->deadline) if $test->parameters->deadline;
            $parameters->timeout($test->parameters->timeout) if $test->parameters->timeout;
            $parameters->packet_tos_bits($test->parameters->tos_bits) if $test->parameters->tos_bits;
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
            $parameters->algorithm($test->parameters->algorithm) if $test->parameters->algorithm;
            $parameters->as($test->parameters->as) if $test->parameters->as;
            $parameters->fragment($test->parameters->fragment) if $test->parameters->fragment;
            $parameters->hostnames($test->parameters->hostnames) if $test->parameters->hostnames;
            $parameters->probe_type($test->parameters->probe_type) if $test->parameters->probe_type;
            $parameters->queries($test->parameters->queries) if $test->parameters->queries;
            $parameters->sendwait($test->parameters->sendwait) if $test->parameters->sendwait;
            $parameters->wait($test->parameters->wait) if $test->parameters->wait;
            $parameters->packet_tos_bits($test->parameters->tos_bits) if $test->parameters->tos_bits;
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
            $parameters->tcp_bandwidth($test->parameters->tcp_bandwidth) if $test->parameters->tcp_bandwidth;
            $parameters->mss($test->parameters->mss) if $test->parameters->mss;
            $parameters->dscp($test->parameters->dscp) if $test->parameters->dscp;
            $parameters->no_delay($test->parameters->no_delay) if $test->parameters->no_delay;
            $parameters->congestion($test->parameters->congestion) if $test->parameters->congestion;
            $parameters->flow_label($test->parameters->flow_label) if $test->parameters->flow_label;
            $parameters->client_cpu_affinity($test->parameters->client_cpu_affinity) if $test->parameters->client_cpu_affinity;
            $parameters->server_cpu_affinity($test->parameters->server_cpu_affinity) if $test->parameters->server_cpu_affinity;
            
            $parameters->force_ipv4($test->parameters->ipv4_only) if $test->parameters->ipv4_only;
            $parameters->force_ipv6($test->parameters->ipv6_only) if $test->parameters->ipv6_only;
			
			if ($test->parameters->time_slots){
				$schedule   = perfSONAR_PS::RegularTesting::Schedulers::TimeBasedSchedule->new();
				$schedule->time_slots($test->parameters->time_slots)
			} else {
				$schedule   = perfSONAR_PS::RegularTesting::Schedulers::RegularInterval->new();
            	$schedule->interval($test->parameters->interval) if $test->parameters->interval;
            	$schedule->random_start_percentage($test->parameters->random_start_percentage) if(defined $test->parameters->random_start_percentage);
			}
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
                $parameters->packet_count(25/$test->parameters->packet_interval) if($test->parameters->packet_interval);
            }
            else {
                $parameters = perfSONAR_PS::RegularTesting::Tests::Powstream->new();
                $parameters->resolution($test->parameters->sample_count * $test->parameters->packet_interval) if $test->parameters->sample_count * $test->parameters->packet_interval;
            }
            $parameters->inter_packet_time($test->parameters->packet_interval) if($test->parameters->packet_interval);
            $parameters->packet_length($test->parameters->packet_padding) if($test->parameters->packet_padding);
            $parameters->output_raw($test->parameters->output_raw) if($test->parameters->output_raw);
            $parameters->packet_tos_bits($test->parameters->tos_bits) if $test->parameters->tos_bits;
            $parameters->force_ipv4($test->parameters->ipv4_only) if $test->parameters->ipv4_only;
            $parameters->force_ipv6($test->parameters->ipv6_only) if $test->parameters->ipv6_only;

            $schedule = perfSONAR_PS::RegularTesting::Schedulers::Streaming->new();
        }
        elsif ($test->parameters->type eq "simplestream") {
            $parameters = perfSONAR_PS::RegularTesting::Tests::SimpleStream->new();
            $parameters->tool($test->parameters->tool) if($test->parameters->tool);
            $parameters->dawdle($test->parameters->dawdle) if defined $test->parameters->dawdle;
			$parameters->timeout($test->parameters->timeout) if defined $test->parameters->timeout;
			$parameters->test_material($test->parameters->test_material) if $test->parameters->test_material;
			$parameters->fail($test->parameters->fail) if defined  $test->parameters->fail;
			
			$schedule = perfSONAR_PS::RegularTesting::Schedulers::RegularInterval->new();
            $schedule->interval($test->parameters->interval) if $test->parameters->interval;
            $schedule->random_start_percentage($test->parameters->random_start_percentage) if(defined $test->parameters->random_start_percentage);
        }

        if ($target_sends and not $target_receives) {
            $parameters->send_only(1);
        }

        if ($target_receives and not $target_sends) {
            $parameters->receive_only(1);
        }
        
        my @test_refs = ();
        foreach my $test_ref(@{$test->references}){
            push @test_refs, new perfSONAR_PS::RegularTesting::Reference({
                    'name' => $test_ref->name(),
                    'value' => $test_ref->value()
                });
        }
        $test_obj->references(\@test_refs);
        
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
