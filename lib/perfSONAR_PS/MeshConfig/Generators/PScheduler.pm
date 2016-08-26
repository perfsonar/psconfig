package perfSONAR_PS::MeshConfig::Generators::PScheduler;
use strict;
use warnings;

our $VERSION = 3.1;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);
use Encode qw(encode);

use utf8;

use perfSONAR_PS::MeshConfig::Generators::Base;
use perfSONAR_PS::Client::PScheduler::Task;
use perfSONAR_PS::Client::PScheduler::TaskManager;
use Moose;

extends 'perfSONAR_PS::MeshConfig::Generators::Base';

has 'url'                 => (is => 'rw', isa => 'Str');
has 'configure_archives'  => (is => 'rw', isa => 'Bool');
has 'task_manager'        => (is => 'rw', isa => 'perfSONAR_PS::Client::PScheduler::TaskManager');

=head1 NAME

perfSONAR_PS::MeshConfig::Generators::PScheduler;

=head1 DESCRIPTION

=head1 API

=cut

my $logger = get_logger(__PACKAGE__);


sub init {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         url => 1,
                                         skip_duplicates => 1,
                                         client_uuid_file => 1,
                                         task_file => 1,
                                         configure_archives => 0,
                                      });
    
    my $url   = $parameters->{url};
    my $skip_duplicates   = $parameters->{skip_duplicates};
    my $configure_archives = $parameters->{configure_archives};
    
    $self->SUPER::init({config_file => "", skip_duplicates => $skip_duplicates });
    
    $self->url($url) if defined $url;
    $self->configure_archives($configure_archives) if defined $configure_archives;
    $self->task_manager(new perfSONAR_PS::Client::PScheduler::TaskManager());
    $self->task_manager()->init(
                                    pscheduler_url => $url,
                                    task_file => $parameters->{task_file},
                                    client_uuid_file => $parameters->{client_uuid_file},
                                    user_agent => "perfsonar-meshconfig"
                                );
    
    
    return (0, "");
}

sub add_mesh_tests {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { mesh => 1, tests => 1, addresses => 1, local_host => 1, host_classes => 1, requesting_agent => 1 } );
    my $mesh   = $parameters->{mesh};
    my $tests  = $parameters->{tests};
    my $addresses = $parameters->{addresses};
    my $local_host = $parameters->{local_host};
    my $host_classes = $parameters->{host_classes};
    my $requesting_agent = $parameters->{requesting_agent};
    
    my %host_addresses = map { $_ => 1 } @$addresses;

    my %addresses_added = ();

    my $mesh_id = $mesh->description;
    $mesh_id =~ s/[^A-Za-z0-9_-]/_/g;

    my @psc_tasks = ();
    my %test_types = ();
    foreach my $test (@$tests) {
        if ($test->disabled) {
            $logger->debug("Skipping disabled test: ".$test->description);
            #TODO: Disable in pscheduler
            next;
        }

        $logger->debug("Adding: ".$test->description);
        
        #TODO: Remove this?
        if ($test->has_unknown_attributes) {
            die("Test '".$test->description."' has unknown attributes: ".join(", ", keys %{ $test->get_unknown_attributes }));
        }
        
         #TODO: Remove this?
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
                    # We always send
                    $sender_targets{$sender->{address}} = [] unless $sender_targets{$sender->{address}};
                    push @{ $sender_targets{$sender->{address}} }, $receiver->{address};
                }
                else {
                    # We're the receiver. We receive in 2 cases:
                    #   1) the far side is no_agent and won't be performing this test.
                    #   2) the force_bidirectional flag is set so we perform both send and receive
                    if ($sender->{no_agent} or
                        ($test->parameters->can("force_bidirectional") and $test->parameters->force_bidirectional)) {
                            $receiver_targets{$receiver->{address}} = [] unless $receiver_targets{$receiver->{address}};
                            push @{ $receiver_targets{$receiver->{address}} }, $sender->{address};
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
                $self->__build_tasks({ test => $test, targets => \%receiver_targets, target_receives => 1, target_sends => 1 });
            }else{
                $self->__build_tasks({ test => $test, targets => \%receiver_targets, target_receives => 1 });
                $self->__build_tasks({ test => $test, targets => \%sender_targets, target_sends => 1 });
            }
            
            #track test types
            $test_types{$test->parameters->type} = 1;

        };
        if ($@) {
            die("Problem adding test ".$test->description.": ".$@);
        }
    }
    
    #add measurement archives
#     if($self->configure_archives()){
#         my $ma_map = {
#             "pinger" => {}, 
#             "perfsonarbuoy/owamp" => {}, 
#             "perfsonarbuoy/bwctl" => {}, 
#             "traceroute" => {}
#             };
#         foreach my $test_type(keys %test_types){
#             #lookup archive in explicit hosts and host classes. Append them all together if multiple match
#             my @archives = ();
#             if($local_host){
#                 my $host_archive = $local_host->lookup_measurement_archive({ type => $test_type, recursive => 1 });
#                 push @archives, $host_archive if($host_archive);
#             }
#             #lookup archives in host classes
#             foreach my $host_class(@{$host_classes}){
#                 if($host_class->host_properties){
#                     my $hc_archive = $host_class->host_properties->lookup_measurement_archive({ type => $test_type, recursive => 1 });
#                     push @archives, $hc_archive if($hc_archive);
#                 }
#             }
#             #lookup archives in requesting agent
#             if($requesting_agent){
#                  my $agent_archive = $requesting_agent->lookup_measurement_archive({ type => $test_type, recursive => 1 });
#                  push @archives, $agent_archive if($agent_archive);
#             }
#             
#             if(@archives < 1){
#                 die("Unable to find measurement archive of type $test_type");
#             }
#             
#             #iterate through archives skipping duplicates (same URL + same type)
#             foreach my $archive(@archives){
#                 next if $ma_map->{$test_type}->{$archive->write_url()};
#                 my $archive_obj;
#                 if ($test_type eq "pinger" || $test_type eq "perfsonarbuoy/owamp") {
#                     next if $ma_map->{'perfsonarbuoy/owamp'}->{$archive->write_url()} || $ma_map->{'pinger'}->{$archive->write_url()};
#                     $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondLatency();
#                     foreach my $summ(@{$default_summaries->{'latency'}}){
#                         push @{$archive_obj->summary}, $archive_obj->create_summary_config(%{$summ});
#                     }
#                 }elsif ($test_type eq "traceroute") {
#                     $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondTraceroute();
#                 }elsif ($test_type eq "perfsonarbuoy/bwctl") {
#                     $archive_obj = new perfSONAR_PS::RegularTesting::MeasurementArchives::EsmondThroughput();
#                     foreach my $summ(@{$default_summaries->{'throughput'}}){
#                         push @{$archive_obj->summary}, $archive_obj->create_summary_config(%{$summ});
#                     }
#                 }
#                 $archive_obj->database($archive->write_url());
#                 $archive_obj->added_by_mesh(1);
#                 push @{ $self->regular_testing_conf->measurement_archives }, $archive_obj;
#                 $ma_map->{$test_type}->{$archive->write_url()} = 1;
#             }
#         }
#         
#     }
    return;
}

sub __build_tasks {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { test => 1, targets => 1, target_sends => 0, target_receives => 0 });
    my $test = $parameters->{test};
    my $targets = $parameters->{targets};
    my $target_sends = $parameters->{target_sends};
    my $target_receives = $parameters->{target_receives};

    my @psc_tasks = ();
    foreach my $local_address (keys %{ $targets }) {
        #loop through all local addresses
        my @targets = ();
        foreach my $target (@{ $targets->{$local_address} }) {
            #loop through remote addresses
            my @directions = ();
            push @directions, [$local_address, $target] if($target_sends);
            push @directions, [$target, $local_address] if($target_receives);
            #loop through send and recv directions
            foreach my $dir(@directions){
                #Task init and meta info
                my $psc_task = new perfSONAR_PS::Client::PScheduler::Task(url => $self->url());
                $psc_task->reference_param('description', $test->description) if $test->description;
                
                #Test parameters
                my $psc_test_spec = {};
                if($test->parameters->type eq "pinger"){
                    #TODO: Support the options below
                    #"flowlabel":         { "$ref": "#/pScheduler/CardinalZero" },
                    #"hostnames":         { "$ref": "#/pScheduler/Boolean" },
                    #"suppress-loopback": { "$ref": "#/pScheduler/Boolean" },
                    #"tos":               { "$ref": "#/pScheduler/Cardinal" },
                    #"deadline":          { "$ref": "#/pScheduler/Duration" },
                    #"timeout":           { "$ref": "#/pScheduler/Duration" },
                    #tool?
                    $psc_task->test_type('rtt');
                    $psc_test_spec->{'source'} = $dir->[0];
                    $psc_test_spec->{'dest'} = $dir->[1];
                    $psc_test_spec->{'count'} = int($test->parameters->packet_count) if $test->parameters->packet_count;
                    $psc_test_spec->{'length'} = int($test->parameters->packet_size) if $test->parameters->packet_size;
                    $psc_test_spec->{'ttl'} = int($test->parameters->packet_ttl) if $test->parameters->packet_ttl;
                    $psc_test_spec->{'interval'} = "PT" . $test->parameters->packet_interval . "S" if $test->parameters->packet_interval;
                    $psc_test_spec->{'ip-version'} = 4 if($test->parameters->ipv4_only);
                    $psc_test_spec->{'ip-version'} = 6 if($test->parameters->ipv6_only);
                    #TODO: Support for more scheduling params
                    $psc_task->schedule_repeat('PT' . $test->parameters->test_interval . 'S') if(defined $test->parameters->test_interval);
                    $psc_task->schedule_randslip($test->parameters->random_start_percentage) if(defined $test->parameters->random_start_percentage);
                }elsif($test->parameters->type eq "traceroute"){
                    #TODO: Support the options below
                    #"algorithm":   { "$ref": "#/local/algorithm" },
                    #"as":          { "$ref": "#/pScheduler/Boolean" },
                    #"dest-port":   { "$ref": "#/pScheduler/IPPort" },
                    #"fragment":    { "$ref": "#/pScheduler/Boolean" },
                    #"hostnames":   { "$ref": "#/pScheduler/Boolean" },
                    #"probe-type":  { "$ref": "#/local/probe-type" },
                    #"queries":     { "$ref": "#/pScheduler/Cardinal" },
                    #"sendwait":    { "$ref": "#/pScheduler/Duration" },
                    #"tos":         { "$ref": "#/pScheduler/Cardinal" },
                    #"wait":        { "$ref": "#/pScheduler/Duration" },
                    $psc_task->test_type('trace');
                    if($test->parameters->tool){
                        $psc_task->add_requested_tool($test->parameters->tool);
                    }
                    $psc_test_spec->{'source'} = $dir->[0];
                    $psc_test_spec->{'dest'} = $dir->[1];
                    $psc_test_spec->{'length'} = int($test->parameters->packet_size) if $test->parameters->packet_size;
                    $psc_test_spec->{'first-ttl'} = int($test->parameters->first_ttl) if $test->parameters->first_ttl;
                    $psc_test_spec->{'hops'} = int($test->parameters->max_ttl) if $test->parameters->max_ttl;
                    $psc_test_spec->{'ip-version'} = 4 if($test->parameters->ipv4_only);
                    $psc_test_spec->{'ip-version'} = 6 if($test->parameters->ipv6_only);
                    #TODO: Support for more scheduling params
                    $psc_task->schedule_repeat('PT' . $test->parameters->test_interval . 'S') if(defined $test->parameters->test_interval);
                    $psc_task->schedule_randslip($test->parameters->random_start_percentage) if(defined $test->parameters->random_start_percentage);
                }elsif($test->parameters->type eq "perfsonarbuoy/bwctl"){
                    if($test->parameters->tool){
                        my $tool = $test->parameters->tool;
                        $tool =~ s/^bwctl\///; #backward compatibility
                        $psc_task->add_requested_tool($tool) ;
                    }
                    #TODO: Support the options below
                    #"source":      { "$ref": "#/pScheduler/Host" },
                    #"destination": { "$ref": "#/pScheduler/Host" },
                    #"duration":    { "$ref": "#/pScheduler/Duration" },
                    #"interval":    { "$ref": "#/pScheduler/Duration" },
                    #"parallel":    { "$ref": "#/pScheduler/Cardinal" },
                    #"udp":         { "$ref": "#/pScheduler/Boolean" },
                    #"bandwidth":   { "$ref": "#/pScheduler/Cardinal" },           
                    #"window-size": { "$ref": "#/pScheduler/Cardinal" },
                    #"mss":         { "$ref": "#/pScheduler/Cardinal" },
                    #"buffer-length": { "$ref": "#/pScheduler/Cardinal" },
                    #"force-ipv4":    { "$ref": "#/pScheduler/Boolean" },
                    #"force-ipv6":    { "$ref": "#/pScheduler/Boolean" },
                    #"local-address": { "$ref": "#/pScheduler/Host" },
                    #"dscp":          { "$ref": "#/pScheduler/Cardinal" },
                    #"omit":          { "$ref": "#/pScheduler/Cardinal" },
                    #"tos":           { "$ref": "#/pScheduler/Cardinal" },
                    #"dynamic-window-size":    { "$ref": "#/pScheduler/Cardinal" },
                    #"no-delay":    { "$ref": "#/pScheduler/Boolean" },
                    #"congestion":    { "$ref": "#/pScheduler/String" },
                    #"zero-copy":    { "$ref": "#/pScheduler/Boolean" },
                    #"flow-label":    { "$ref": "#/pScheduler/String" },
                    #"cpu-affinity":    { "$ref": "#/pScheduler/String" }
                    $psc_task->test_type('throughput');
                    $psc_test_spec->{'source'} = $dir->[0];
                    $psc_test_spec->{'destination'} = $dir->[1];
                    $psc_test_spec->{'udp'} = ($test->parameters->protocol eq "udp"?JSON::true:JSON::false);
                    $psc_test_spec->{'duration'} = "PT" . $test->parameters->duration . "S" if $test->parameters->duration;
                    $psc_test_spec->{'omit'} = $test->parameters->omit_interval if $test->parameters->omit_interval;
                    $psc_test_spec->{'bandwidth'} = $test->parameters->udp_bandwidth if $test->parameters->udp_bandwidth;
                    $psc_test_spec->{'buffer-length'} = $test->parameters->buffer_length if $test->parameters->buffer_length;
                    $psc_test_spec->{'tos'} = $test->parameters->tos_bits if $test->parameters->tos_bits;
                    $psc_test_spec->{'parallel'} = $test->parameters->streams if $test->parameters->streams;
                    $psc_test_spec->{'window-size'} = $test->parameters->window_size if $test->parameters->window_size;
                    $psc_test_spec->{'force-ipv4'} = $test->parameters->ipv4_only if $test->parameters->ipv4_only;
                    $psc_test_spec->{'force-ipv6'} = $test->parameters->ipv6_only if $test->parameters->ipv6_only;
                    #TODO: Support for more scheduling params
                    $psc_task->schedule_repeat('PT' . $test->parameters->interval . 'S') if(defined $test->parameters->interval);
                    $psc_task->schedule_randslip($test->parameters->random_start_percentage) if(defined $test->parameters->random_start_percentage);
                }elsif($test->parameters->type eq "perfsonarbuoy/owamp"){
                    #TODO: Support owping, old way was odd and broken
                    # TODO: Support these. 
                    # "duration": {
                    #     "description": "The length of time to run the test",
                    #     "$ref": "#/pScheduler/Duration"
                    # },
                    # "packet-timeout": {
                    #     "description": "The number of seconds to wait before declaring a packet lost",
                    #     "$ref": "#/pScheduler/CardinalZero"
                    # },
                    # "ctrl-port": {
                    #     "description": "The control plane port to use for the entity acting as the server (the dest if flip is not set, the source otherwise)",
                    #     "$ref": "#/pScheduler/IPPort"
                    # },
                    # "data-ports": {
                    #     "description": "The port range to use on the side of the test running the client. At least two ports required.",
                    #     "$ref": "#/pScheduler/IPPortRange"
                    # },
                    # "ip-tos": {
                    #     "description": "DSCP value for TOS byte in the IP header as an integer",
                    #     "$ref": "#/pScheduler/IPTOS"
                    # },
                    # "bucket-width": {
                    #     "description": "The bin size to use for histogram calculations. This value is divided into the result as reported in seconds and truncated to the nearest 2 decimal places.",
                    #     "$ref": "#/local/bucket-width" 
                    # },
                    $psc_task->test_type('latencybg');
                    $psc_test_spec->{'packet-count'} = int($test->parameters->sample_count) if $test->parameters->sample_count;
                    $psc_test_spec->{'source'} = $dir->[0];
                    $psc_test_spec->{'dest'} = $dir->[1];
                    $psc_test_spec->{'flip'} = JSON::true if($local_address eq $dir->[1]);
                    $psc_test_spec->{'packet-interval'} = $test->parameters->packet_interval + 0.0 if $test->parameters->packet_interval;
                    $psc_test_spec->{'packet-padding'} = int($test->parameters->packet_padding) if defined $test->parameters->packet_padding;
                    $psc_test_spec->{'ip-version'} = 4 if($test->parameters->ipv4_only);
                    $psc_test_spec->{'ip-version'} = 6 if($test->parameters->ipv6_only);
                }
                #add test spec to task
                $psc_task->test_spec($psc_test_spec);
                
                #add task to list of managed tasks
                $self->task_manager()->add_task(task => $psc_task, local_address => $local_address);
            }
        }
        
    }
}

sub save {
    my ($self) = @_;
    
    $self->task_manager()->commit(); 
    foreach my $error(@{$self->task_manager()->errors()}){
        $logger->warn($error);
    }
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
