package perfSONAR_PS::PSConfig::MaDDash::Agent;

=head1 NAME

perfSONAR_PS::Client::PSConfig::MaDDash::Agent - Agent that loads config, grabs meshes and generates a MaDDash configuration

=head1 DESCRIPTION

Agent that loads config, grabs meshes and generates a MaDDash configuration

=cut

use Mouse;

use Data::Dumper;
use Log::Log4perl qw(get_logger);
use YAML qw(LoadFile);

use perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator;
use perfSONAR_PS::Utils::Logging;
use perfSONAR_PS::PSConfig::MaDDash::ConfigConnect;
use perfSONAR_PS::PSConfig::MaDDash::Config;
use perfSONAR_PS::PSConfig::MaDDash::DefaultReports qw(load_default_reports);

extends 'perfSONAR_PS::PSConfig::BaseAgent';

use constant META_DISPLAY_NAME => 'display-name';
use constant META_DISPLAY_URL => 'display-url';
use constant ADDED_BY_TAG => 'added_by_psconfig';
use constant OLD_ADDED_BY_TAG => 'added_by_mesh_agent';

our $VERSION = 4.1;

has 'group_member_map' => (is => 'rw', isa => 'HashRef', default => sub{ {} });
has 'group_map' => (is => 'rw', isa => 'HashRef', default => sub{ {} });
has 'grids' => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });
has 'dashboards' => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });
has 'check_map' => (is => 'rw', isa => 'HashRef', default => sub{ {} });

my $logger = get_logger(__PACKAGE__);
my $task_logger = get_logger('TaskLogger');
my $transaction_logger = get_logger('TransactionLogger');

sub _agent_name {
    return "maddash";
}

sub _config_client {
    return new perfSONAR_PS::PSConfig::MaDDash::ConfigConnect();
}

sub _init {
    my ($self, $agent_conf) = @_;
}

sub _run_start {
    my($self, $agent_conf) = @_;
    
    ##
    # Set defaults for config values
    unless($agent_conf->maddash_yaml_file()){
        my $default = "/etc/maddash/maddash-server/maddash.yaml";
        $logger->debug($self->logf()->format("No maddash-yaml-file specified. Defaulting to $default"));
        $agent_conf->maddash_yaml_file($default);
    }
    
    return 1;
}

sub _run_handle_psconfig {
    my($self, $psconfig, $agent_conf, $remote) = @_;
    
    ##
    # Generate group members
    $self->_build_group_members($psconfig);
    
    ##
    # Initialize dashboards
    my $dashboard;
    my $dashboard_name = $psconfig->psconfig_meta_param(META_DISPLAY_NAME());
    if($dashboard_name){
         $dashboard = {
            "name" => $dashboard_name,
            "grids" => []
        };
        push @{$self->dashboards()}, $dashboard;
    }
    
    ##
    # Generate groups and grids
    foreach my $task_name(@{$psconfig->task_names()}){
        $self->logf->global_context()->{'task_name'} = $task_name;
        my $task = $psconfig->task($task_name);
        my $group = $psconfig->group($task->group_ref());
        my $row_equal_col = 0;
         
        #get grid name
        my $grid_name = $task->psconfig_meta_param(META_DISPLAY_NAME());
        unless($grid_name){
            $grid_name = $task_name;
        }
        
        #add to dashboard
        if($dashboard){
            push @{$dashboard->{'grids'}}, $grid_name;
        }
        
        #check dimension count
        if($group->dimension_count() > 2){
            $logger->warn($self->logf()->format("MaDDash agent currently only supports groups with 2 or less dimensions"));
            next;
        }
        
        #build row group
        my $row_id = $task_name . "-row";
        my $row_labels = $self->_build_maddash_group($row_id, $group->dimension(0), $psconfig);
         
        #build column group if two-dimensional
        my $column_id = $task_name . "-col";
        my $col_labels = [];
        if($group->dimension_count() == 1){
            $self->group_map()->{$column_id} = [ "check" ]; #TODO: Make this better
            $row_equal_col = 1;
        }else{
            $col_labels = $self->_build_maddash_group($column_id, $group->dimension(1), $psconfig);
            if(@{$self->group_map()->{$row_id}} == @{$self->group_map()->{$column_id}}){
                $row_equal_col = 1;
                for(my $i = 0; $i < @{$self->group_map()->{$row_id}}; $i++){
                    if($self->group_map()->{$row_id}->[$i] ne $self->group_map()->{$column_id}->[$i]){
                        $row_equal_col = 0;
                        last;
                    }
                }
            }
        }
        
        #build excludes
        my $exclude_checks = {};
        my $has_exclude_checks = 0;
        if($group->can('excludes') && $group->excludes()){
            foreach my $exclude(@{$group->excludes()}){
                $has_exclude_checks = 1;
                my $local_nlas = $exclude->local_address()->select($psconfig);
                foreach my $local_nla(@{$local_nlas}){
                    $exclude_checks->{$local_nla->{'name'}} = [];
                    foreach my $target(@{$exclude->target_addresses()}){
                        my $target_nlas = $target->select($psconfig);
                        foreach my $target_nla(@{$target_nlas}){
                            push @{$exclude_checks->{$local_nla->{'name'}}}, $target_nla->{'name'};
                        }
                    }
                }
            }
        }
        
        #build checks 
        my $checks = $self->_build_checks($psconfig, $agent_conf, $task_name, $task, $group, $row_equal_col);
        
        #build grid
        my $grid = {};
        $grid->{ADDED_BY_TAG()}  = 1;
        $grid->{name}            = $grid_name;
        $grid->{rows}            = $row_id;
        $grid->{columns}         = $column_id;
        $grid->{excludeChecks}   = $exclude_checks if($has_exclude_checks);
        $grid->{rowOrder}        = "alphabetical";
        $grid->{colOrder}        = "alphabetical";
        $grid->{excludeSelf}     = 1;
        $grid->{columnAlgorithm} = "all";
        $grid->{checks}          = $checks; #TODO: figure this out
       #  $grid->{statusLabels}    = {
#             ok => $check->{ok_description},
#             warning  => $check->{warning_description},
#             critical => $check->{critical_description},
#             unknown => "Unable to retrieve data",
#             notrun => "Check has not yet run",
#         };
#         my $report_id = __generate_report_id(
#                                 grid_name => $grid_name,
#                                 group_type => $test->members->type, 
#                                 test_type => $test->parameters->type,
#                                 maddash_options => $maddash_options
#                             );
#         $grid->{report} = $report_id if($report_id);
        push @{$self->grids()}, $grid;
        
        #build checks
        ## $row_labels, $col_labels - or maybe row_nlas, col_nlas,
    }
    
    
}

sub _run_end {
    # load file, format YAML and output file
    my($self, $agent_conf) = @_;
    
    ##
    # Load YAML
    my $maddash_yaml = $self->_load_maddash_yaml($agent_conf);
    return unless($maddash_yaml);
    
    ##
    # Format group members
    foreach my $group_member_id(keys %{$self->group_member_map()}){
        push @{$maddash_yaml->{'groupMembers'}}, $self->group_member_map()->{$group_member_id};
    }
    
    ##
    # Add groups
    foreach my $group_id(keys %{$self->group_map()}){
        $maddash_yaml->{'groups'}->{$group_id} = $self->group_map()->{$group_id};
    }
    
    ##
    # Add checks
    foreach my $check_id(keys %{$self->check_map()}){
        $maddash_yaml->{'checks'}->{$check_id} = $self->check_map()->{$check_id};
    }
    
    ##
    # Add grids
    foreach my $grid(@{$self->grids()}){
        push @{$maddash_yaml->{'grids'}}, $grid;
    }
    
    ##
    # Add dashboards
    foreach my $dashboard(@{$self->dashboards()}){
        push @{$maddash_yaml->{'dashboards'}}, $dashboard;
    }
    
    ##
    # Output maddash yaml
    print "::::::YAML::::::\n";
    print YAML::Dump($maddash_yaml);
    
    
}

sub _load_maddash_yaml {
    my($self, $agent_conf) = @_;
    
    # Need to make changes to the YAML parser so that the Java YAML parser will
    # grok the output.
    local $YAML::UseHeader = 0;
    local $YAML::CompressSeries = 0;
    
    my $maddash_yaml;
    eval {
        $maddash_yaml = LoadFile($agent_conf->maddash_yaml_file());
    };
    if ($@) {
        $logger->error($self->logf()->format("Problem loading existing maddash YAML: ".$@));
        return;
    }
    
    #Fill in defaults if we need to
    $maddash_yaml->{dashboards} = [] unless $maddash_yaml->{dashboards};
    $maddash_yaml->{grids}      = [] unless $maddash_yaml->{grids};
    $maddash_yaml->{checks}     = {} unless $maddash_yaml->{checks};
    $maddash_yaml->{groups}     = {} unless $maddash_yaml->{groups};
    $maddash_yaml->{groupMembers}  = [] unless $maddash_yaml->{groupMembers};
    $maddash_yaml->{reports}       = [] unless $maddash_yaml->{reports};
    
    #set some defaults so people don't need to start with partial file
    $maddash_yaml->{database} = '/var/lib/maddash/' unless $maddash_yaml->{database};
    $maddash_yaml->{serverHost} = 'localhost' unless $maddash_yaml->{serverHost};
    $maddash_yaml->{http} = { 'port' => 8881 } unless $maddash_yaml->{http};
    
    #clean out stuff we already added
    my @deleted_grids = ();
    my $elements_to_delete = { groups => [], checks => [] };
    my $existing_reports = {};
    
    # Delete the elements that we added
    foreach my $type ("dashboards", "grids", "groupMembers", "reports") {
        my @new_value = ();
        foreach my $element (@{ $maddash_yaml->{$type} }) {
            if ($element->{ADDED_BY_TAG()} || $element->{OLD_ADDED_BY_TAG()}) {
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

        $maddash_yaml->{$type} = \@new_value;
    }

    foreach my $type (keys %$elements_to_delete) {
        foreach my $key (@{ $elements_to_delete->{$type} }) {
            delete($maddash_yaml->{$type}->{$key});
        }
    }
    
    #TODO: add thus back. It works fine but may need to be a bit more generic
    #create map of existing reports
    #add default reports if they are not already in place
    #foreach my $default_report(@{load_default_reports()}){
    #    #add unless we have our own manual version of the same name. allows default rules to be overridden.
    #    unless($existing_reports->{$default_report->{id}}){
    #        $default_report->{ADDED_BY_TAG()} = 1;
    #        push @{ $maddash_yaml->{reports} },$default_report;
    #    }
    #}
    
    return $maddash_yaml;
}

sub _build_group_members {
    my($self, $psconfig) = @_;
    
    ##
    # Generate groupMembers
    foreach my $address_key(keys %{$psconfig->addresses()}){
        #build a map
        my $address = $psconfig->address($address_key);
        unless($self->group_member_map()->{$address_key}){
            $self->group_member_map()->{$address_key} = { 
                'id' => $address_key ,
                ADDED_BY_TAG() => 1
            };
        }
        my $group_member = $self->group_member_map()->{$address_key};
        
        #look for a display-name and copy to label (special maddash variable)
        my $display_name = $address->psconfig_meta_param(META_DISPLAY_NAME());
        if($display_name){
            $group_member->{'label'} = $display_name;
        }

        #look for a pstoolkiturl (special maddash variable)
        my $display_url = $address->psconfig_meta_param(META_DISPLAY_URL());
        if($display_url){
            $group_member->{'pstoolkiturl'} = $display_name;
        }
        
        #get ready to build a map
        my $map = $group_member->{'map'} ? $group_member->{'map'} : {};
        $map->{'default'} = {} unless($map->{'default'});
        $map->{'default'}->{'address'} = $address->address();
        
        #look for labels and put in default map
        foreach my $label_name(keys %{$address->labels()}){
            #only add map if we actually have values
            $map->{'default'}->{$label_name} = $address->label($label_name)->address();
        }
        
        #look for remotes
        foreach my $remote_id(keys %{$address->remote_addresses()}){
            #get remote address
            my $remote_address = $address->remote_address($remote_id);
            
            #only add map if we actually have values
            $map->{$remote_id} = {} unless($map->{$remote_id});
            $map->{$remote_id}->{'address'} = $remote_address->address();
            foreach my $remote_label_name(keys %{$remote_address->labels()}){
                #only add map if we actually have values
                $map->{$remote_id}->{$remote_label_name} = $remote_address->label($remote_label_name)->address();
            }
        }
        
        #set the map
        $group_member->{'map'} = $map;
    }
}

sub _build_maddash_group {
    my($self, $name, $dimension, $psconfig) = @_;
    
    my @maddash_group = ();
    my @maddash_group_labels = ();
    foreach my $addr_sel(@{$dimension}){
        my $nlas = $addr_sel->select($psconfig);
        foreach my $nla(@{$nlas}){
            push @maddash_group, $nla->{'name'};
            push @maddash_group_labels, ($nla->{'label'} ? $nla->{'label'} : 'address');
        }
    }
    $self->group_map()->{$name} = \@maddash_group;
    
    return \@maddash_group_labels;
}

sub _build_checks {
    #todo: review if we need all these
    my($self, $psconfig, $agent_conf, $task_name, $task, $group, $row_equal_col) = @_;
    
    #build ma map
    my $ma_map = {};
    my $tg = new perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator(
        psconfig => $psconfig,
        pscheduler_url => $self->pscheduler_url(),
        task_name => $task_name,
        default_archives => $self->default_archives(),
        use_psconfig_archives => 1
    );
    unless($tg->start()){
         $logger->error($self->logf()->format("Error initializing task iterator: " . $tg->error()));
         return;
    }
    my @addrs;
    while(@addrs = $tg->next()){
        #check for errors expanding task
        if($tg->error()){
            $logger->error($tg->error());
            next;
        }
        #build map
        my $row = $self->_get_root_address($addrs[0]);
        my $col = (@addrs > 1 ? $self->_get_root_address($addrs[1]) : "default");
        $ma_map->{$row} = {} unless($ma_map->{$row});
        $ma_map->{$row}->{$col} = $self->_select_archive($tg);
        
    }
    $tg->stop();
    $self->_simplify_map($ma_map);
    $self->check_map()->{$task_name . "-check"} = {
        ADDED_BY_TAG() => 1,
        "maUrl" => $ma_map
    };
    
    #TODO: Delete this
    my @checks = ('forward');
    unless($row_equal_col){
        push @checks, 'reverse';
    }
    
    return \@checks;
}

sub _select_archive {
    my($self, $tg) = @_;
    
    #TODO: base this off of check definition
    foreach my $a(@{$tg->expanded_archives()}){
        print Dumper($a);
        if($a->{'archiver'} eq 'esmond'){
            return $a->{'data'}->{'url'};
        }
    }
    
    return;
}

sub _get_root_address {
    my($self, $address) = @_;
    
    if($address->_parent_name()){
        return $address->_parent_name();
    }
    
    return $address->map_name();
}

sub _simplify_map {
    my ($self, $map) = @_;

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


__PACKAGE__->meta->make_immutable;

1;