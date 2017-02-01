package perfSONAR_PS::MeshConfig::Generators::MaDDash;
use strict;
use warnings;

our $VERSION = 3.1;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use perfSONAR_PS::Utils::DNS qw(resolve_address);
use perfSONAR_PS::MeshConfig::Generators::MaDDash::DefaultReports qw(load_default_reports);
use Net::IP;

use JSON;
use YAML qw(Dump);
use Encode qw(encode);

use base 'Exporter';

our @EXPORT_OK = qw( generate_maddash_config );

=head1 NAME

perfSONAR_PS::MeshConfig::Generators::MaDDash;

=head1 DESCRIPTION

=head1 API

=cut

my $logger = get_logger(__PACKAGE__);
my %SUPPORTED_TEST_TYPES = (
    "perfsonarbuoy/owamp" => 1,
    "perfsonarbuoy/bwctl" => 1,
    "simplestream" => 1,
    "traceroute" => 1,
    "pinger" => 1
);

sub generate_maddash_config {
    my $parameters = validate( @_, { meshes => 1, existing_maddash_yaml => 1, maddash_options => 1 } );
    my $meshes                = $parameters->{meshes};
    my $existing_maddash_yaml = $parameters->{existing_maddash_yaml};
    my $maddash_options       = $parameters->{maddash_options};
    
    # Need to make changes to the YAML parser so that the Java YAML parser will
    # grok the output.
    local $YAML::UseHeader = 0;
    local $YAML::CompressSeries = 0;
    
    $existing_maddash_yaml->{dashboards} = [] unless $existing_maddash_yaml->{dashboards};
    $existing_maddash_yaml->{grids}      = [] unless $existing_maddash_yaml->{grids};
    $existing_maddash_yaml->{checks}     = {} unless $existing_maddash_yaml->{checks};
    $existing_maddash_yaml->{groups}     = {} unless $existing_maddash_yaml->{groups};
    $existing_maddash_yaml->{groupMembers}  = [] unless $existing_maddash_yaml->{groupMembers};
    $existing_maddash_yaml->{reports}       = [] unless $existing_maddash_yaml->{reports};
    
    #set some defaults so people don't need to start with partial file
    $existing_maddash_yaml->{database} = '/var/lib/maddash/' unless $existing_maddash_yaml->{database};
    $existing_maddash_yaml->{serverHost} = 'localhost' unless $existing_maddash_yaml->{serverHost};
    $existing_maddash_yaml->{http} = { 'port' => 8881 } unless $existing_maddash_yaml->{http};
     
    my @deleted_grids = ();
    my $elements_to_delete = { groups => [], checks => [] };
    my $existing_reports = {};
    
    # Delete the elements that we added
    foreach my $type ("dashboards", "grids", "groupMembers", "reports") {
        my @new_value = ();
        foreach my $element (@{ $existing_maddash_yaml->{$type} }) {
            if ($element->{added_by_mesh_agent}) {
                if ($type eq "grids") {
                    push @deleted_grids, $element->{name};
                    push @{ $elements_to_delete->{groups} }, $element->{rows};
                    push @{ $elements_to_delete->{groups} }, $element->{columns};
                    push @{ $elements_to_delete->{checks} }, @{ $element->{checks} };
                }
            }
            else {
                push @new_value, $element;
                if ($type eq "reports") {
                    $existing_reports->{$element->{'id'}} = 1;
                }
            }
        }

        $existing_maddash_yaml->{$type} = \@new_value;
    }

    foreach my $type (keys %$elements_to_delete) {
        foreach my $key (@{ $elements_to_delete->{$type} }) {
            delete($existing_maddash_yaml->{$type}->{$key});
        }
    }
    
    #create map of existing reports
    #add default reports if they are not already in place
    foreach my $default_report(@{load_default_reports()}){
        #add unless we have our own manual version of the same name. allows default rules to be overridden.
        unless($existing_reports->{$default_report->{id}}){
            $default_report->{added_by_mesh_agent} = 1;
            push @{ $existing_maddash_yaml->{reports} },$default_report;
        }
    }
    
    # Verify that there are tests to be run
    foreach my $mesh (@$meshes) {
        my $num_tests = 0;

        foreach my $test (@{ $mesh->tests }) {
            unless (exists $SUPPORTED_TEST_TYPES{$test->parameters->type} && $SUPPORTED_TEST_TYPES{$test->parameters->type}) {
                $logger->debug("Skipping: ".$test->parameters->type);
                next;
            }

            if ($test->disabled) {
                $logger->debug("Skipping disabled test: ".$test->description);
                next;
            }
    
            $num_tests++;
        }

        unless ($num_tests) {
            $logger->debug("No supported tests run by this mesh");
             next;
        }

        my $dashboards      = $existing_maddash_yaml->{dashboards};
        my $checks          = $existing_maddash_yaml->{checks};
        my $groups          = $existing_maddash_yaml->{groups};
        my $groupMembers    = $existing_maddash_yaml->{groupMembers};
        my $grids           = $existing_maddash_yaml->{grids};
        my $reports         = $existing_maddash_yaml->{reports};
        
        my $dashboard = {};
        $dashboard->{name}                = $mesh->description?$mesh->description:"Mesh Sites";
        $dashboard->{grids}               = [];
        $dashboard->{added_by_mesh_agent} = 1;
        
        #generate groupMembers. not we could 
        my @all_hosts = ();
        push @all_hosts, @{ $mesh->hosts };
        my %addr_site_map = ();
        foreach my $organization (@{ $mesh->organizations }) {
            push @all_hosts, @{ $organization->hosts };
            foreach my $site (@{ $organization->sites }) {
                push @all_hosts, @{ $site->hosts };
                foreach my $site_host (@{ $site->hosts }){
                    foreach my $addr_obj (@{ $site_host->addresses }) {
                        my $address = $addr_obj->address;
                        $addr_site_map{$address} = $site->hosts;
                    }
                }
            }
        }

        foreach my $host (@all_hosts) {
            next unless $host->addresses;
            
            foreach my $addr_obj (@{ $host->addresses }) {
                my $address = __normalize_addr($addr_obj->address);
                my $description = $host->description?$host->description:$address;
                
                my $member_params = { 
                    "id" => $address, 
                    "label" => $description, 
                    "added_by_mesh_agent" => 'yes' #force a string 
                    };
                if($host->toolkit_url eq 'auto'){
                    $member_params->{pstoolkiturl} = "http://$address/toolkit";
                }elsif($host->toolkit_url){
                    $member_params->{pstoolkiturl} = $host->toolkit_url;
                }
                #build groupMember 'map' attribute
                if($addr_obj->maps && @{$addr_obj->maps} > 0){
                    my %unique_field_names = ();
                    $member_params->{map} = {} unless($member_params->{map});
                    foreach my $addr_map(@{$addr_obj->maps}){
                        my $tmp_map = ($member_params->{map}->{$addr_map->remote_address} ? $member_params->{map}->{$addr_map->remote_address} : {});
                        foreach my $map_field(@{$addr_map->fields}){
                            $tmp_map->{$map_field->name} = $map_field->value;
                            $unique_field_names{$map_field->name} = 1;
                        }
                        $member_params->{map}->{$addr_map->remote_address} = $tmp_map;
                    }
                    #set default for all fields seen to the address of host. a bit of hack and won't make sense for fields that aren't addresses.
                    #people should really always set default for non-address fields to avoid this
                    my $tmp_default_map = ($member_params->{map}->{'default'} ? $member_params->{map}->{'default'} : {});
                    foreach my $unique_field_name(keys %unique_field_names){
                        $tmp_default_map->{$unique_field_name} = $address unless($tmp_default_map->{$unique_field_name});
                    }
                    $member_params->{map}->{'default'} = $tmp_default_map;
                    
                }
                push @{$groupMembers}, $member_params;
            }
        }
        
        my $i = 0;
        foreach my $test (@{ $mesh->tests }) {
            unless (exists $SUPPORTED_TEST_TYPES{$test->parameters->type} && $SUPPORTED_TEST_TYPES{$test->parameters->type}) {
                $logger->debug("Skipping: ".$test->parameters->type);
                next;
            }

            if ($test->disabled) {
                $logger->debug("Skipping disabled test: ".$test->description);
                next;
            }
 
            $i++;

            my $grid_name = $dashboard->{name}." - ";
            if ($test->description) {
                $grid_name .= $test->description;
            }
            else {
                $grid_name .= "test".$i;
            }

            # Build the groups
            my $row_id;
            my @row_members = ();

            my $column_id;
            my @column_members = ();
            my $is_full_mesh = 0;
            
            my $columnAlgorithm = "all";
            if ($test->members->type eq "star") {
                $test->members->center_address(__normalize_addr($test->members->center_address));
                push @row_members, $test->members->center_address;
                foreach my $member (@{__normalize_addrs($test->members->members)}) {
                    push @column_members, $member unless $member eq $test->members->center_address;
                }

                $column_id = __generate_yaml_key($grid_name)."-column";
                $row_id = __generate_yaml_key($grid_name)."-row";
            }
            elsif ($test->members->type eq "disjoint") {
                foreach my $a_member (@{__normalize_addrs($test->members->a_members)}) {
                    push @row_members, $a_member;
                }
                foreach my $b_member (@{__normalize_addrs($test->members->b_members)}) {
                    push @column_members, $b_member;
                }
                $column_id = __generate_yaml_key($grid_name)."-column";
                $row_id = __generate_yaml_key($grid_name)."-row";
            
            }
            elsif ($test->members->type eq "ordered_mesh") {
                foreach my $member (@{__normalize_addrs($test->members->members)}) {
                    push @row_members, $member;
                    push @column_members, $member;
                }
                $row_id = $column_id = __generate_yaml_key($grid_name);
                $columnAlgorithm = "afterSelf";
            }
            else {
                # try to do it in a generic fashion. i.e. go through all the
                # source/dest pairs and add each source/dest to both the column and
                # the row. This should be, more or less, a mesh configuration.
                
                $is_full_mesh= 1;
                my %tmp_members = ();

                foreach my $pair (@{ $test->members->source_destination_pairs }) {
                    $tmp_members{$pair->{source}->{address}} = 1;
                    $tmp_members{$pair->{destination}->{address}} = 1;
                }

                @row_members = @column_members = keys %tmp_members;
                $row_id = $column_id = __generate_yaml_key($grid_name);
            }

            # build the 'exclude' maps to remove any pairs in the above that don't
            # actually form a test.
            my %exclude_checks = ();

            foreach my $row (@row_members) {
                $exclude_checks{$row} = {};
                foreach my $column (@column_members) {
                    $exclude_checks{$row}->{$column} = 1;
                }
            }
            
            #remove port specifications from pairs
             foreach my $pair( @{ $test->members->source_destination_pairs }) {
                $pair->{source}->{address} = __normalize_addr($pair->{source}->{address});
                $pair->{destination}->{address} = __normalize_addr($pair->{destination}->{address});
            }
            
            foreach my $pair (@{ $test->members->source_destination_pairs }) {
                next if ($pair->{source}->{no_agent} and $pair->{destination}->{no_agent});
                #if using mapped addresses with exclude_unmapped, make sure to skip unmapped
                if($test->members->address_map_field && $test->members->exclude_unmapped){
                    next unless __has_mapped_address(address_map_field => $test->members->address_map_field, local_addr_maps => $pair->{source}->{addr_obj}->maps, remote_address => $pair->{destination}->{address});
                    next unless __has_mapped_address(address_map_field => $test->members->address_map_field, local_addr_maps => $pair->{destination}->{addr_obj}->maps, remote_address => $pair->{source}->{address});
                }
         
                delete($exclude_checks{$pair->{source}->{address}}->{$pair->{destination}->{address}});
                if (scalar(keys %{ $exclude_checks{$pair->{source}->{address}} }) == 0) {
                    delete($exclude_checks{$pair->{source}->{address}});
                }

                delete($exclude_checks{$pair->{destination}->{address}}->{$pair->{source}->{address}});
                if (scalar(keys %{ $exclude_checks{$pair->{destination}->{address}} }) == 0) {
                    delete($exclude_checks{$pair->{destination}->{address}});
                }
            }

            # Convert the exclude check lists into the appropriate syntax
            foreach my $key (keys %exclude_checks) {
                my @values = keys %{ $exclude_checks{$key} };
                $exclude_checks{$key} = \@values;
            }

            # build the MA maps
            my %forward_ma_map = ();
            my %reverse_ma_map = ();
            
            # build the graph maps
            my %forward_graph_map = ();
            my %reverse_graph_map = ();
            
            my %row_hosts = map { $_ => 1 } @row_members;
            my %column_hosts = map { $_ => 1 } @column_members;

            foreach my $pair (@{ $test->members->source_destination_pairs }) {
                next if ($pair->{source}->{no_agent} and $pair->{destination}->{no_agent});

                my $tester = $pair->{source}->{no_agent}?$pair->{destination}->{addr_obj}:$pair->{source}->{addr_obj};

                my $host = $tester->parent;
                
                #use test-specific first
                my $ma = $test->lookup_measurement_archive({ type => $test->parameters->type });
                unless($ma){
                    $ma = $host->lookup_measurement_archive({ type => $test->parameters->type, recursive => 1 });
                }
                unless ($ma) {
                    die("Couldn't find ma for host: ".$tester);
                }

                my $src_addr = $pair->{source}->{address};
                my $dst_addr = $pair->{destination}->{address};

                #get test address type
                my $test_type = '';
                if($test->parameters->ipv4_only || is_ipv4($src_addr) || is_ipv4($dst_addr)){
                    $test_type = 'ipv4';
                }elsif($test->parameters->ipv6_only || is_ipv6($src_addr) || is_ipv6($dst_addr)){
                    $test_type = 'ipv6';
                }else{
                    my $src_type = __get_hostname_ip_type($src_addr);
                    my $dst_type = __get_hostname_ip_type($dst_addr);
                    if($src_type =~ /ipv6/ && $dst_type =~ /ipv6/){
                        $test_type = 'ipv6';
                    }else{
                        $test_type = 'ipv4';
                    }
                }
                
                #determine base graph url
                my $enable_combined_graphs = __get_check_option({ option => "enable_combined_graphs", test_type => $test->parameters->type, grid_name => $grid_name, maddash_options => $maddash_options });
                my $graph_url = __get_check_option({ option => "graph_url", test_type => $test->parameters->type, grid_name => $grid_name, maddash_options => $maddash_options });
                $graph_url .= '?' if($graph_url !~ /\?$/);
                #rev_graph_url is the URL used when both of the following simultaneously hold true:  a) the source is a column and b) it is the bottom check
                my $rev_graph_url = $graph_url; 
                #only do combined graphs if not using mapped addresses, since you will get wierd results otherwise
                if($test->members->address_map_field){
                    $enable_combined_graphs = 0;
                }
                
                #Build list of hosts at same site for graphs
                my $src_site_hosts = $addr_site_map{$src_addr} ? $addr_site_map{$src_addr} : [{'addresses' => [$src_addr]}];
                my $dst_site_hosts = $addr_site_map{$dst_addr} ? $addr_site_map{$dst_addr} : [{'addresses' => [$dst_addr]}];
                
                #Build graph URL
                if($enable_combined_graphs){
                    #New MA so use new graphs that try to plot all latency and throughput data together
                    #Note using combined graphs forgoes bwctl protocol filters, tool name, and custom filters due to complexity
                    my $is_source_ma = $tester->{address} eq $src_addr ? 1 : 0;
                    foreach my $src_site_host(@{$src_site_hosts}){
                        foreach my $dst_site_host(@{$dst_site_hosts}){
                        
                            #figure out mas
                            my @ma_list;
                            if($is_source_ma){
                                @ma_list = map {$_->read_url} @{$src_site_host->measurement_archives};      
                            }else{
                                @ma_list = map {$_->read_url} @{$dst_site_host->measurement_archives};    
                            }
                            my %seen = ();
                            my @unique_mas = grep !$seen{$_}++, @ma_list;
                        
                            #go through all hosts
                            my %seen_src_ip = ();
                            foreach my $src_site_host_addr (@{ $src_site_host->{addresses} }) {
                                my $src_ip = $src_site_host_addr->address;
                                if(!is_ipv4($src_ip) && !is_ipv6($src_ip)){
                                    $src_ip = __get_hostname_ip($src_ip, $test_type);
                                }
                                $src_ip = '' . Net::IP->new($src_ip)->ip() if($src_ip);#normalize ipv6
                                next if($seen_src_ip{$src_ip});
                                next if $test_type eq 'ipv4' && !is_ipv4($src_ip);
                                next if $test_type eq 'ipv6' && !is_ipv6($src_ip);
                                my %seen_dst_ip = ();
                                foreach my $dst_site_host_addr (@{ $dst_site_host->{addresses} }) {
                                    my $dst_ip = $dst_site_host_addr->address;
                                    if(!is_ipv4($dst_ip) && !is_ipv6($dst_ip)){
                                        $dst_ip = __get_hostname_ip($dst_ip, $test_type);
                                    }
                                    $dst_ip = '' . Net::IP->new($dst_ip)->ip() if($dst_ip);#normalize ipv6
                                    next if($seen_dst_ip{$dst_ip});
                                    next if $test_type eq 'ipv4' && !is_ipv4($dst_ip);
                                    next if $test_type eq 'ipv6' && !is_ipv6($dst_ip);
                                    foreach my $unique_ma (@unique_mas){
                                        if($is_full_mesh){
                                            $graph_url .= "url=$unique_ma&source=$src_ip&dest=$dst_ip&agent=$src_ip&";
                                            $rev_graph_url .= "url=$unique_ma&source=$dst_ip&dest=$src_ip&agent=$src_ip&";
                                        }else{
                                            $graph_url .= "url=$unique_ma&source=$src_ip&dest=$dst_ip&";
                                            #below is not a bug. this gets set when src is column and bottom check, thus the forward is the reverse
                                            $rev_graph_url .= "url=$unique_ma&source=$src_ip&dest=$dst_ip&";
                                        }
                                        $seen_src_ip{$src_ip}++;
                                        $seen_dst_ip{$dst_ip}++;
                                    }
                                }
                            }
                        }
                    }
                }else{
                    my $graph_options = "";
                    my $graph_custom_filters = "";
                    #Set IP version if needed
                    if($test->parameters->ipv6_only){
                        $graph_options .= "&ipversion=6";
                    }elsif($test->parameters->ipv4_only){
                        $graph_options .= "&ipversion=4";
                    }
                    #Set BWCTL options if needed
                    if($test->parameters->type eq "perfsonarbuoy/bwctl"){
                        $graph_options .= "&protocol=" . $test->parameters->protocol if($test->parameters->protocol);
                        $graph_custom_filters .= "bw-target-bandwidth:" . $test->parameters->udp_bandwidth if($test->parameters->udp_bandwidth);
                        my $filter_tool_name = __get_check_option({ option => "filter_tool_name", test_type => $test->parameters->type, grid_name => $grid_name, maddash_options => $maddash_options });
                        if($filter_tool_name && $test->parameters->tool){
                            $graph_options .= "&tool=" . $test->parameters->tool;
                        }
                    } 
                    #set custom filters
                    my $custom_ma_filters = __get_check_option({ option => "ma_filter", test_type => $test->parameters->type, grid_name => $grid_name, maddash_options => $maddash_options });
                    if($custom_ma_filters){
                        if(ref $custom_ma_filters ne 'ARRAY'){
                            $custom_ma_filters = [ $custom_ma_filters ];
                        }
                        foreach my $custom_ma_filter(@{$custom_ma_filters}){
                            unless ($custom_ma_filter->{'ma_filter_name'}){
                                die "custom_ma_filter config missing ma_filter_name property";
                            }
                            unless ($custom_ma_filter->{'mesh_parameter_name'}){
                                die "custom_ma_filter config missing mesh_parameter_name property";
                            }
                            unless(exists $test->parameters->{$custom_ma_filter->{'mesh_parameter_name'}} 
                                    && defined $test->parameters->{$custom_ma_filter->{'mesh_parameter_name'}} ){
                                next;
                            }
                           $graph_custom_filters .= ',' if($graph_custom_filters);
                           $graph_custom_filters .= $custom_ma_filter->{'ma_filter_name'} . ':' . $test->parameters->{$custom_ma_filter->{'mesh_parameter_name'}}; 
                        }
                    }
                    $graph_custom_filters = "&filter=$graph_custom_filters" if($graph_custom_filters);
                    
                    #determine if we are using mapped addresses
                    my $row_templ_var = '%row';
                    my $col_templ_var = '%col';
                    if($test->members->address_map_field){
                        $row_templ_var .= '.map.' . $test->members->address_map_field;
                        $col_templ_var .= '.map.' . $test->members->address_map_field;
                    }
                    $graph_url .= "url=%maUrl&source=$row_templ_var&dest=$col_templ_var" . $graph_options . $graph_custom_filters;
                    if($is_full_mesh){
                        $graph_url .= "&agent=$row_templ_var";
                        $rev_graph_url .= "url=%maUrl&source=$row_templ_var&dest=$col_templ_var" . $graph_options . $graph_custom_filters;
                        $rev_graph_url .= "&agent=$col_templ_var";
                    }else{
                        $rev_graph_url .= "url=%maUrl&source=$col_templ_var&dest=$row_templ_var" . $graph_options . $graph_custom_filters ;
                    }
                } 
                
                if ($row_hosts{$src_addr}) {
                    my $ma_url = $ma->read_url;

                    if ($tester eq $src_addr) {
                        $ma_url =~ s/$tester/\%row/g;
                        $graph_url =~ s/$tester/\%row/g;
                    }
                    else {
                        $ma_url =~ s/$tester/\%col/g;
                        $graph_url =~ s/$tester/\%col/g;
                    }
                    
                    $forward_ma_map{$src_addr}->{$dst_addr} = $ma_url;
                    $forward_graph_map{$src_addr}->{$dst_addr} = $graph_url;
                }

                if ($column_hosts{$src_addr} and $row_hosts{$dst_addr}) {
                    my $ma_url = $ma->read_url;

                    if ($tester eq $src_addr) {
                        $ma_url =~ s/$tester/\%col/g;
                        $rev_graph_url =~ s/$tester/\%col/g;
                    }
                    else {
                        $ma_url =~ s/$tester/\%row/g;
                        $rev_graph_url =~ s/$tester/\%row/g;
                    }
                    
                    $reverse_ma_map{$dst_addr}->{$src_addr} = $ma_url;
                    $reverse_graph_map{$dst_addr}->{$src_addr} = $rev_graph_url;
                }
            }

            # simplify the maps
            foreach my $map (\%forward_ma_map, \%reverse_ma_map, \%forward_graph_map, \%reverse_graph_map) {
                __simplify_map($map);
            }


            # Add the groups
            if ($groups->{$row_id}) {
                die("Check ".$row_id." has been redefined");
            }
            elsif ($groups->{$column_id}) {
                die("Check ".$column_id." has been redefined");
            }

            $groups->{$row_id}    = \@row_members;
            $groups->{$column_id} = \@column_members;
            
            #Build the checks 
            my @checks = ();
            
            # Build the top half of the box check
            my $check = __build_check(grid_name => $grid_name, test_params => $test->parameters, ma_map => \%forward_ma_map, direction => "forward", maddash_options => $maddash_options, is_full_mesh => $is_full_mesh, graph_map => \%forward_graph_map, address_map_field => $test->members->address_map_field);
            if ($checks->{$check->{id}}) {
                die("Check ".$check->{id}." has been redefined");
            }
            $checks->{$check->{id}}     = $check;
            push @checks, $check->{id};
            
            # Build the bottom half of the box check
            if($test->parameters->force_bidirectional){
                my $rev_check = __build_check(grid_name => $grid_name, test_params => $test->parameters, ma_map => \%reverse_ma_map, direction => "reverse", maddash_options => $maddash_options, is_full_mesh => $is_full_mesh, graph_map => \%reverse_graph_map, address_map_field => $test->members->address_map_field);
                if ($checks->{$rev_check->{id}}) {
                    die("Check ".$rev_check->{id}." has been redefined");
                }
                $checks->{$rev_check->{id}} = $rev_check;
                push @checks, $rev_check->{id};
            }
            
            # Build the grid
            my $grid = {};
            $grid->{name}            = $grid_name;
            $grid->{rows}            = $row_id;
            $grid->{columns}         = $column_id;
            $grid->{rowOrder}        = "alphabetical";
            $grid->{colOrder}        = "alphabetical";
            $grid->{excludeSelf}     = 1;
            $grid->{columnAlgorithm} = $columnAlgorithm;
            $grid->{checks}          = \@checks;
            $grid->{excludeChecks}   = \%exclude_checks;
            $grid->{statusLabels}    = {
                ok => $check->{ok_description},
                warning  => $check->{warning_description},
                critical => $check->{critical_description},
                unknown => "Unable to retrieve data",
                notrun => "Check has not yet run",
            };
            my $report_id = __generate_report_id(
                                    grid_name => $grid_name,
                                    group_type => $test->members->type, 
                                    test_type => $test->parameters->type,
                                    maddash_options => $maddash_options
                                );
            $grid->{report} = $report_id if($report_id);
            $grid->{added_by_mesh_agent} = 1;

            # Add the new grid
            foreach my $existing_grid (@$grids) {
                die("Grid ".$grid->{name}." has been redefined") if ($existing_grid->{name} eq $grid->{name});
            }

            push @$grids, $grid;
            push @{ $dashboard->{grids} }, { name => $grid->{name} };
        }

        # Add the new dashboard
        foreach my $existing_dashboard (@$dashboards) {
            die("Mesh ".$dashboard->{name}." has been redefined") if ($existing_dashboard->{name} eq $dashboard->{name});
        }

        push @$dashboards, $dashboard;
    }

    my $ret = Dump($existing_maddash_yaml);
    $ret = __quote_ipv6_address(maddash_yaml => $ret);
    return encode('ascii', $ret);
}

sub __generate_report_id {
    my $parameters = validate( @_, { grid_name => 1, group_type => 1, test_type => 1, maddash_options => 1, } );
    my $grid_name = $parameters->{grid_name};
    my $group_type = $parameters->{group_type};
    my $test_type = $parameters->{test_type};
    my $maddash_options = $parameters->{maddash_options};
    
    #look if report_id specified in config
    my $report_id = __get_check_option({ option => "report_id", test_type => $test_type, grid_name => $grid_name, maddash_options => $maddash_options });
    
    #otherwise generate default id
    unless($report_id){
        $report_id = "meshconfig";
        if($group_type eq 'mesh'){
            $report_id .= "_mesh";
        }else{
            $report_id .= "_disjoint";
        }
    
        if($test_type eq "perfsonarbuoy/bwctl"){
            $report_id .= "_throughput";
        }elsif($test_type eq "perfsonarbuoy/owamp"){
            $report_id .= "_loss";
        }else{
            return;
        }
    }
    
    return $report_id;
}
    
sub __quote_ipv6_address {
    my $parameters = validate( @_, { maddash_yaml => 1 } );
    my $yaml = $parameters->{maddash_yaml};

    my $IPv4 = "((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))";
    my $G = "[0-9a-fA-F]{1,4}";

    my @tail = ( ":",
	     "(:($G)?|$IPv4)",
             ":($IPv4|$G(:$G)?|)",
             "(:$IPv4|:$G(:$IPv4|(:$G){0,2})|:)",
	     "((:$G){0,2}(:$IPv4|(:$G){1,2})|:)",
	     "((:$G){0,3}(:$IPv4|(:$G){1,2})|:)",
	     "((:$G){0,4}(:$IPv4|(:$G){1,2})|:)" );


    my $IPv6_re = $G;
    $IPv6_re = "$G:($IPv6_re|$_)" for @tail;
    $IPv6_re = qq/:(:$G){0,5}((:$G){1,2}|:$IPv4)|$IPv6_re/;
    $IPv6_re =~ s/\(/(?:/g;
    $IPv6_re = qr/$IPv6_re/;

    $yaml =~ s/($IPv6_re)/\'$1\'/gm;
    $yaml =~ s/\'\'/\'/gm;
    $yaml =~ s/\=\'($IPv6_re)\'/=$1/gm;
    $yaml =~ s/([^=]https?)\:\/\/\'($IPv6_re)\'/'$1:\/\/[$2]'/gm;
    $yaml =~ s/(\=https?)\:\/\/\'($IPv6_re)\'/$1:\/\/[$2]/gm;
    return $yaml; 
}

my %maddash_default_check_options = (
    "perfsonarbuoy/owamp" => {
        check_command => "/usr/lib64/nagios/plugins/check_owdelay.pl",
        check_interval => 1800,
        check_time_range => 2700,
        retry_interval => 300,
        retry_attempts => 1,
        timeout => 60,
        acceptable_loss_rate => 0,
        critical_loss_rate => 0.01,
        enable_combined_graphs => 0,
        filter_tool_name => 0,
        graph_url => '/perfsonar-graphs/',
        ma_filter => [],
        report_id => '',
    },
    "perfsonarbuoy/bwctl" => {
        check_command => "/usr/lib64/nagios/plugins/check_throughput.pl",
        check_interval => 28800,
        check_time_range => 86400,
        retry_interval => 300,
        retry_attempts => 1,
        timeout => 60,
        acceptable_throughput => 900,
        critical_throughput => 500,
        enable_combined_graphs => 0,
        filter_tool_name => 0,
        graph_url => '/perfsonar-graphs/',
        ma_filter => [],
        report_id => '',
    },
    "simplestream" => {
        check_command => "/usr/lib64/nagios/plugins/check_pscheduler_raw.pl",
        check_interval => 1800,
        check_time_range => 3600,
        retry_interval => 300,
        retry_attempts => 1,
        timeout => 60,
        acceptable_count => 1,
        critical_count => 0,
        enable_combined_graphs => 0,
        filter_tool_name => 0,
        graph_url => '/perfsonar-graphs/',
        ma_filter => [],
        report_id => '',
    },
    "traceroute" => {
        check_command => "/usr/lib64/nagios/plugins/check_traceroute.pl",
        check_interval => 1800,
        check_time_range => 3600,
        retry_interval => 300,
        retry_attempts => 1,
        timeout => 60,
        acceptable_count => 1,
        critical_count => 2,
        enable_combined_graphs => 0,
        filter_tool_name => 0,
        graph_url => '/perfsonar-graphs/',
        ma_filter => [],
        report_id => '',
    },
    "pinger" => {
        check_command => "/usr/lib64/nagios/plugins/check_ping_loss.pl",
        check_interval => 1800,
        check_time_range => 3600,
        retry_interval => 300,
        retry_attempts => 1,
        timeout => 60,
        acceptable_count => 0,
        critical_count => 0,
        enable_combined_graphs => 0,
        filter_tool_name => 0,
        graph_url => '/perfsonar-graphs/',
        ma_filter => [],
        report_id => '',
    },
);

sub __build_check {
    my $parameters = validate( @_, { grid_name => 1, test_params => 1, ma_map => 1, direction => 1, maddash_options => 1, is_full_mesh => 1, graph_map => 1, address_map_field => 1  } );
    my $grid_name = $parameters->{grid_name};
    my $test_params  = $parameters->{test_params};
    my $type  = $parameters->{test_params}->type;
    my $ma_map = $parameters->{ma_map};
    my $direction = $parameters->{direction};
    my $maddash_options = $parameters->{maddash_options};
    my $is_full_mesh = $parameters->{is_full_mesh};
    my $graph_map = $parameters->{graph_map};
    my $address_map_field = $parameters->{address_map_field};
    my $filter_tool_name = __get_check_option({ option => "filter_tool_name", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
    my $custom_ma_filters = __get_check_option({ option => "ma_filter", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
    my $row_templ_var = '%row';
    my $col_templ_var = '%col';
    if($address_map_field){
        $row_templ_var .= '.map.' . $address_map_field;
        $col_templ_var .= '.map.' . $address_map_field;
    }
    
    my $check = {};
    $check->{type} = "net.es.maddash.checks.PSNagiosCheck";
    $check->{retryInterval}   = __get_check_option({ option => "retry_interval", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });;
    $check->{retryAttempts}   = __get_check_option({ option => "retry_attempts", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });;
    $check->{timeout}         = __get_check_option({ option => "timeout", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
    $check->{params}          = {};
    $check->{params}->{maUrl} = $ma_map;
    $check->{checkInterval}   = __get_check_option({ option => "check_interval", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
    $check->{params}->{graphUrl} = $graph_map;

    my $nagios_cmd    = __get_check_option({ option => "check_command", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
    my $check_time_range = __get_check_option({ option => "check_time_range", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });

    my $host = $maddash_options->{external_address};
    $host = "localhost" unless $host;

    if ($type eq "perfsonarbuoy/bwctl") {
        my $ok_throughput = __get_check_option({ option => "acceptable_throughput", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
        my $critical_throughput = __get_check_option({ option => "critical_throughput", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
        $check->{ok_description} = "Throughput >= ".$ok_throughput."Mbps";
        $check->{warning_description} = "Throughput < ".$ok_throughput."Mbps";
        $check->{critical_description} = "Throughput <= ".$critical_throughput."Mbps";
 
        # convert to Gbps used in the nagios plugin
        $ok_throughput       /= 1000;
        $critical_throughput /= 1000; 

        if($is_full_mesh && $direction eq "reverse") {
            $check->{name} = 'Throughput Alternate MA';
            $check->{description} = "Throughput from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_throughput.': -c '.$critical_throughput.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var -a $col_templ_var";
        }
        elsif($is_full_mesh) {
            $check->{name} = 'Throughput';
            $check->{description} = "Throughput from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_throughput.': -c '.$critical_throughput.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var -a $row_templ_var";
        }
        elsif ($direction eq "reverse") {
            $check->{name} = 'Throughput Reverse';
            $check->{description} = "Throughput from $col_templ_var to $row_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_throughput.': -c '.$critical_throughput.': -r '.$check_time_range." -s $col_templ_var -d $row_templ_var";
        }
        else {
            $check->{name} = 'Throughput';
            $check->{description} = "Throughput from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_throughput.': -c '.$critical_throughput.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var";
        }
        
        #add additional filters
        $check->{params}->{command} .= (' -p ' . $test_params->protocol ) if($test_params->protocol);
        $check->{params}->{command} .= (' --udpbandwidth ' . $test_params->udp_bandwidth ) if($test_params->udp_bandwidth);
        #set tool name if needed
        if($filter_tool_name && $test_params->tool){
            $check->{params}->{command} .= ' --tool "' . $test_params->tool . '"'; 
        }
    }
    elsif ($type eq "perfsonarbuoy/owamp") {
        my $ok_loss = __get_check_option({ option => "acceptable_loss_rate", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
        my $critical_loss = __get_check_option({ option => "critical_loss_rate", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });

        $check->{ok_description}  = "Loss rate is <= ".$ok_loss;
        $check->{warning_description}  = "Loss rate is >= ".$ok_loss;
        $check->{critical_description}  = "Loss rate is >= ".$critical_loss;

        if ($is_full_mesh && $direction eq "reverse") {
           $check->{name} = 'Loss Alternate MA';
           $check->{description} = "Loss from $row_templ_var to $col_templ_var";
           $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_loss.' -c '.$critical_loss.' -r '.$check_time_range." -l -p -s $row_templ_var -d $col_templ_var -a $col_templ_var";
        }
        elsif ($is_full_mesh) {
            $check->{name} = 'Loss';
            $check->{description} = "Loss from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_loss.' -c '.$critical_loss.' -r '.$check_time_range." -l -p -s $row_templ_var -d $col_templ_var -a $row_templ_var";
        }
        elsif ($direction eq "reverse") {
            $check->{name} = 'Loss Reverse';
            $check->{description} = "Loss from $col_templ_var to $row_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_loss.' -c '.$critical_loss.' -r '.$check_time_range." -l -p -s $col_templ_var -d $row_templ_var";
        }
        else {
            $check->{name} = 'Loss';
            $check->{description} = "Loss from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_loss.' -c '.$critical_loss.' -r '.$check_time_range." -l -p -s $row_templ_var -d $col_templ_var";
        }
    }
    elsif ($type eq "simplestream") {
        my $metric_label = "Simplestream Test Count";
        my $ok_count = __get_check_option({ option => "acceptable_count", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
        my $critical_count = __get_check_option({ option => "critical_count", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });

        $check->{ok_description}  = "Test count is <= ".$ok_count;
        $check->{warning_description}  = "Test count is >= ".$ok_count;
        $check->{critical_description}  = "Test count is >= ".$critical_count;

        if ($is_full_mesh && $direction eq "reverse") {
           $check->{name} = "$metric_label Alternate MA";
           $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
           $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.' -c '.$critical_count.' -r '.$check_time_range." --filter pscheduler-test-type:simplestream -s $row_templ_var --filter pscheduler-simplestream-dest:$col_templ_var -a $col_templ_var";
        }
        elsif ($is_full_mesh) {
            $check->{name} = "$metric_label";
            $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.' -c '.$critical_count.' -r '.$check_time_range." --filter pscheduler-test-type:simplestream -s $row_templ_var --filter pscheduler-simplestream-dest:$col_templ_var -a $row_templ_var";
        }
        elsif ($direction eq "reverse") {
            $check->{name} = "$metric_label Reverse";
            $check->{description} = "$metric_label from $col_templ_var to $row_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.' -c '.$critical_count.' -r '.$check_time_range." --filter pscheduler-test-type:simplestream -s $col_templ_var --filter pscheduler-simplestream-dest:$row_templ_var";
        }
        else {
            $check->{name} = "$metric_label";
            $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.' -c '.$critical_count.' -r '.$check_time_range." --filter pscheduler-test-type:simplestream -s $row_templ_var --filter pscheduler-simplestream-dest:$col_templ_var";
        }
    }
    elsif ($type eq "traceroute") {
        my $metric_label = "Number of Paths";
        my $ok_count = __get_check_option({ option => "acceptable_count", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
        my $critical_count = __get_check_option({ option => "critical_count", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });

        $check->{ok_description}  = "$metric_label is <= ".$ok_count;
        $check->{warning_description}  = "$metric_label is >= ".$ok_count;
        $check->{critical_description}  = "$metric_label is >= ".$critical_count;

        if ($is_full_mesh && $direction eq "reverse") {
           $check->{name} = "$metric_label Alternate MA";
           $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
           $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.': -c '.$critical_count.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var -a $col_templ_var";
        }
        elsif ($is_full_mesh) {
            $check->{name} = "$metric_label";
            $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.': -c '.$critical_count.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var -a $row_templ_var";
        }
        elsif ($direction eq "reverse") {
            $check->{name} = "$metric_label Reverse";
            $check->{description} = "$metric_label from $col_templ_var to $row_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.': -c '.$critical_count.': -r '.$check_time_range." -s $col_templ_var -d $row_templ_var";
        }
        else {
            $check->{name} = "$metric_label";
            $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.': -c '.$critical_count.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var";
        }
    }
    elsif ($type eq "pinger") {
        my $metric_label = "Ping packets lost";
        my $ok_count = __get_check_option({ option => "acceptable_count", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });
        my $critical_count = __get_check_option({ option => "critical_count", test_type => $type, grid_name => $grid_name, maddash_options => $maddash_options });

        $check->{ok_description}  = "$metric_label is <= ".$ok_count;
        $check->{warning_description}  = "$metric_label is >= ".$ok_count;
        $check->{critical_description}  = "$metric_label is >= ".$critical_count;

        if ($is_full_mesh && $direction eq "reverse") {
           $check->{name} = "$metric_label Alternate MA";
           $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
           $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.': -c '.$critical_count.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var -a $col_templ_var";
        }
        elsif ($is_full_mesh) {
            $check->{name} = "$metric_label";
            $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.': -c '.$critical_count.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var -a $row_templ_var";
        }
        elsif ($direction eq "reverse") {
            $check->{name} = "$metric_label Reverse";
            $check->{description} = "$metric_label from $col_templ_var to $row_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.': -c '.$critical_count.': -r '.$check_time_range." -s $col_templ_var -d $row_templ_var";
        }
        else {
            $check->{name} = "$metric_label";
            $check->{description} = "$metric_label from $row_templ_var to $col_templ_var";
            $check->{params}->{command} =  $nagios_cmd.' -u %maUrl -w '.$ok_count.': -c '.$critical_count.': -r '.$check_time_range." -s $row_templ_var -d $col_templ_var";
        }
    }
    

    #set v4 only and v6 only
    if($test_params->ipv6_only){
        $check->{params}->{command} .= ' -6'
    }elsif($test_params->ipv4_only){
       $check->{params}->{command} .= ' -4'
    }
    
    #set any custom filters
    if($custom_ma_filters){
        if(ref $custom_ma_filters ne 'ARRAY'){
            $custom_ma_filters = [ $custom_ma_filters ];
        }
        foreach my $custom_ma_filter(@{$custom_ma_filters}){
            unless ($custom_ma_filter->{'ma_filter_name'}){
                die "custom_ma_filter config missing ma_filter_name property";
            }
            unless ($custom_ma_filter->{'mesh_parameter_name'}){
                die "custom_ma_filter config missing mesh_parameter_name property";
            }
            unless(exists $test_params->{$custom_ma_filter->{'mesh_parameter_name'}} 
                    && defined $test_params->{$custom_ma_filter->{'mesh_parameter_name'}} ){
                next;
            }
            $check->{params}->{command} .= ' --filter "' . $custom_ma_filter->{'ma_filter_name'} . ':' . $test_params->{$custom_ma_filter->{'mesh_parameter_name'}} . '"'; 
        }
    }
        
    $check->{id} = __generate_yaml_key($grid_name." - ".$check->{name});

    return $check;
}

sub __get_check_option {
    my $parameters = validate( @_, { option => 1, test_type => 1, grid_name => 1, maddash_options => 1 } );
    my $option = $parameters->{option};
    my $test_type  = $parameters->{test_type};
    my $maddash_options = $parameters->{maddash_options};
    my $grid_name = $parameters->{grid_name};
    
    #find check parameters that match grid
    my $check_description = {};
    if (ref $maddash_options->{$test_type} eq 'ARRAY' ){
        foreach my $maddash_opt_check(@{$maddash_options->{$test_type}}){
            my %grid_name_map = ();
            if(!$maddash_opt_check->{grid_name}){
                #default definition if no grid_name
                $check_description = $maddash_opt_check;
                next;
            }elsif(ref $maddash_opt_check->{grid_name} eq 'ARRAY'){
                #grid_name list provided
                %grid_name_map = map { $_ => 1 } @{ $maddash_opt_check->{grid_name} };
            }else{
                #just one grid_name provided
                $grid_name_map{$maddash_opt_check->{grid_name}} = 1;
            }
            
            #we have a list of grids, check if any match
            if($grid_name_map{$grid_name}){
                $check_description = $maddash_opt_check;
                last;
            }
        }
    }else{
        $check_description = $maddash_options->{$test_type};
    }
    
    if (defined  $check_description->{$option}) {
        return $check_description->{$option};
    }

    return $maddash_default_check_options{$test_type}->{$option};
}
 
sub __generate_yaml_key {
  my ($name) = @_;

  $name =~ s/[^a-zA-Z0-9_\-.]/_/g;

  return $name;
}

sub __simplify_map {
    my ($map) = @_;

    my %all_ma_url_counts = ();

    foreach my $row (keys %$map) {
        my %row_ma_url_counts = ();

        foreach my $column (keys %{ $map->{$row} }) {
            my $ma_url = $map->{$row}->{$column};

            $row_ma_url_counts{$ma_url} = 0 unless $row_ma_url_counts{$ma_url};
            $row_ma_url_counts{$ma_url}++;

            $all_ma_url_counts{$ma_url} = 0 unless $all_ma_url_counts{$ma_url};
            $all_ma_url_counts{$ma_url}++;
        }

        my $maximum_url;
        my $maximum_count = 0;

        foreach my $url (keys %row_ma_url_counts) {
            if ($row_ma_url_counts{$url} > $maximum_count) {
                $maximum_url   = $url;
                $maximum_count = $row_ma_url_counts{$url};
            }
        }

        foreach my $column (keys %{ $map->{$row} }) {
            if ($map->{$row}->{$column} eq $maximum_url) {
                delete($map->{$row}->{$column});
            }
        }

        $map->{$row}->{default} = $maximum_url;
    }

    return;
}

sub __normalize_addr {
    my ($address) = @_;
    
    #strip port specification
    $address =~ s/\[//g; #remove starting square bracket
    $address =~ s/\](:\d+)?//g; #remove closing square bracket and optional port
    $address =~ s/^([^:]+):\d+$/$1/g; #remove port if no brackets and not IPv6
    
    return $address;            
}

sub __normalize_addrs {
    my ($addresses) = @_;
    
    for(my $i = 0; $i < @{$addresses}; $i++){
        $addresses->[$i] = __normalize_addr($addresses->[$i]);
    }
    
    return $addresses;            
}

sub __get_hostname_ip_type {
    my ($name) = @_;
    
    my $type = '';
    my $v4_count = 0;
    my $v6_count = 0;
    my @addresses = resolve_address($name);
    foreach my $addr (@addresses){
        if(is_ipv4($addr)){
            $v4_count++;
        }elsif(is_ipv6($addr)){
            $v6_count++;
        }
    }
    $type = 'ipv4' if($v4_count > 0);
    $type .= 'ipv6' if($v6_count > 0);;
    
    return $type;
}

sub __get_hostname_ip {
    my ($name, $type) = @_;
    
    my @addresses = resolve_address($name);
    foreach my $addr (@addresses){
        if($type eq 'ipv4' && is_ipv4($addr)){
            return $addr;
        }elsif($type eq 'ipv6' && is_ipv6($addr)){
            return $addr;
        }
    }
    
    return '';
}


sub __has_mapped_address {
    my $parameters = validate( @_, { address_map_field => 1, local_addr_maps => 1, remote_address => 1});
    my $address_map_field = $parameters->{address_map_field};
    my $local_addr_maps = $parameters->{local_addr_maps};
    my $remote_address = $parameters->{remote_address};
    
    #go through map and find field - also ignore meaningless exclude_unmapped in this case
    foreach my $addr_map(@{$local_addr_maps}){
        if($addr_map->remote_address eq $remote_address){
            foreach my $addr_map_field(@{$addr_map->fields}){
                if($addr_map_field->name eq $address_map_field){
                    return 1;
                }
            }
        }elsif($addr_map->remote_address eq 'default'){
            #use default, but keep looking in case we find something better
            foreach my $addr_map_field(@{$addr_map->fields}){
                if($addr_map_field->name eq $address_map_field){
                    return 1;
                }
            }
        }
    }
    
    return 0;
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
