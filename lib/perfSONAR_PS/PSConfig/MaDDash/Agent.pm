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
use perfSONAR_PS::Utils::ISO8601 qw/duration_to_seconds/;
use perfSONAR_PS::Utils::Logging;
use perfSONAR_PS::Client::PSConfig::Archive;
use perfSONAR_PS::PSConfig::MaDDash::Agent::ConfigConnect;
use perfSONAR_PS::PSConfig::MaDDash::Agent::Config;
use perfSONAR_PS::PSConfig::MaDDash::Agent::Grid;
use perfSONAR_PS::PSConfig::MaDDash::Checks::ConfigConnect;
use perfSONAR_PS::PSConfig::MaDDash::Checks::Config;
use perfSONAR_PS::PSConfig::MaDDash::Template;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::ConfigConnect;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::Config;

extends 'perfSONAR_PS::PSConfig::BaseAgent';

use constant META_DISPLAY_NAME => 'display-name';
use constant META_DISPLAY_URL => 'display-url';
use constant META_DISPLAY_SET => 'display-set';
use constant ADDED_BY_TAG => 'added_by_psconfig';
use constant OLD_ADDED_BY_TAG => 'added_by_mesh_agent';

our $VERSION = 4.1;

has 'group_member_map' => (is => 'rw', isa => 'HashRef', default => sub{ {} });
has 'group_map' => (is => 'rw', isa => 'HashRef', default => sub{ {} });
has 'grids' => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });
has 'dashboards' => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });
has 'check_map' => (is => 'rw', isa => 'HashRef', default => sub{ {} });
has 'agent_grids' => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });
has 'report_map' => (is => 'rw', isa => 'HashRef', default => sub{ {} });
has 'auto_dashboard_name_count' => (is => 'rw', isa => 'Int', default => 0);


my $logger = get_logger(__PACKAGE__);

sub _agent_name {
    return "maddash";
}

sub _config_client {
    return new perfSONAR_PS::PSConfig::MaDDash::Agent::ConfigConnect();
}

sub _init {
    my ($self, $agent_conf) = @_;
}

sub _run_start {
    my($self, $agent_conf) = @_;
    
    ##
    # Reset global values to avoid leaks
    $self->__reset_globals();
    
    ##
    # Set defaults for config values
    unless($agent_conf->maddash_yaml_file()){
        my $default = "/etc/maddash/maddash-server/maddash.yaml";
        $logger->debug($self->logf()->format("No maddash-yaml-file specified. Defaulting to $default"));
        $agent_conf->maddash_yaml_file($default);
    }
    unless($agent_conf->check_plugin_directory()){
        my $default = "/usr/lib/perfsonar/psconfig/checks/";
        $logger->debug($self->logf()->format("No check-plugin-directory specified. Defaulting to $default"));
        $agent_conf->check_plugin_directory($default);
    }
    unless($agent_conf->visualization_plugin_directory()){
        my $default = "/usr/lib/perfsonar/psconfig/visualization/";
        $logger->debug($self->logf()->format("No visualization-plugin-directory specified. Defaulting to $default"));
        $agent_conf->visualization_plugin_directory($default);
    }
    
    ##
    # Exit if no grids to setup
    unless($agent_conf->grids() && @{$agent_conf->grid_names()}){
        $logger->info($self->logf()->format("No grids to setup."));
        return;
    }
    
    ##
    # Load check plug-ins
    my $check_plugins_map = $self->_load_plugins($agent_conf->check_plugin_directory(), "check");
    
    ##
    # Load visualization plug-ins
    my $viz_plugins_map = $self->_load_plugins($agent_conf->visualization_plugin_directory(), "visualization");
    
    ##
    # Set plugins in each grid set
    foreach my $agent_grid_name(@{$agent_conf->grid_names()}){
        my $agent_grid = $agent_conf->grid($agent_grid_name);
        $agent_grid->load_check_plugin($check_plugins_map);
        $agent_grid->load_visualization_plugin($viz_plugins_map);
        #set here because the plugin settings won't stick with agent_conf
        push @{$self->agent_grids()}, $agent_grid;
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
    unless($dashboard_name){
        #set a default dashboard name
        my $dashboard_id = $self->auto_dashboard_name_count() + 1;
        $dashboard_name = "Dashboard $dashboard_id";
        $self->auto_dashboard_name_count($dashboard_id);
    }
    $dashboard = {
        ADDED_BY_TAG() => 1,
        "name" => $dashboard_name,
        "grids" => []
    };
    push @{$self->dashboards()}, $dashboard;
    
    ##
    # Generate groups and grids
    foreach my $task_name(@{$psconfig->task_names()}){
        my $task = $psconfig->task($task_name);
        next if(!$task || $task->disabled());
        my $maddash_task_name = "$dashboard_name - $task_name";
        $self->logf->global_context()->{'task_name'} = $maddash_task_name;
        my $group = $psconfig->group($task->group_ref());
        my $row_equal_col = 0;
        
        ##
        # check dimension count
        if($group->dimension_count() > 2){
            $logger->warn($self->logf()->format("MaDDash agent currently only supports groups with 2 or less dimensions"));
            next;
        }
        
        ##
        # build row group
        my $row_id = $self->__generate_yaml_key($maddash_task_name . "-row");
        my $row_labels = $self->_build_maddash_group($row_id, $group->dimension(0), $psconfig);
        
        ##
        # build column group if two-dimensional
        my $column_id = $self->__generate_yaml_key($maddash_task_name . "-col");
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
        
        ##
        # build excludes
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
        
        ##
        # Build object used to determine if task matches
        my $jq_obj = {
            'task-name' => $task_name,
            'task' => $task->data(),
            'group' => $group->data(),
            'test' => $psconfig->test($task->test_ref())->data()
        };
        $jq_obj->{'schedule'} = $psconfig->schedule($task->schedule_ref())->data() if($task->schedule_ref());
        $jq_obj->{'archives'} = [];
        #Build archive list (have to dig in to host, hence the generator)
        my $jq_tg = new perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator(
                psconfig => $psconfig,
                pscheduler_url => $self->pscheduler_url(),
                task_name => $task_name,
                default_archives => $self->default_archives(),
                use_psconfig_archives => 1
            );
       
        if($jq_tg->start()){
            my $jq_archive_map = {};
            while($jq_tg->next()){
                 foreach my $a(@{$jq_tg->expanded_archives()}){
                    my $a_obj = new perfSONAR_PS::Client::PSConfig::Archive(data => $a );
                    my $checksum = $a_obj->checksum();
                    next if($jq_archive_map->{$checksum});
                    $jq_archive_map->{$checksum} = $a;
                 }
            }
            foreach my $jq_archive_checksum(keys %{$jq_archive_map}){
                push @{$jq_obj->{'archives'}}, $jq_archive_map->{$jq_archive_checksum};
            } 
            $jq_tg->stop();
        }
        
        ##
        # walkthrough configured grids
        my @matching_agent_grids = ();
        my $matching_agent_grid_prios = {};
        foreach my $agent_grid(@{$self->agent_grids()}){
            ##
            # Determine if this task has a check we want configured
            if($agent_grid->matches($jq_obj)){
                if($agent_grid->priority()){
                    #if priority set, compare whether we should add it
                    my $prio = $agent_grid->priority();
                    if(!$matching_agent_grid_prios->{$prio->group()} ||
                            $prio->level() > $matching_agent_grid_prios->{$prio->group()}->{'level'}){
                        #if have not seen group yet, or we have and level is greater than current, then add                        
                        $matching_agent_grid_prios->{$prio->group()} = {
                            'level' => $prio->level(),
                            'grid' => $agent_grid
                        };
                    }
                }else{
                    #no priority, just add it
                    push @matching_agent_grids, $agent_grid;
                }
            }
        }
        #Add grids that had priority set
        foreach my $matching_agent_grid_prio(keys %{$matching_agent_grid_prios}){
            push @matching_agent_grids, $matching_agent_grid_prios->{$matching_agent_grid_prio}->{'grid'};
        }
        
        ##
        # Setup each matching grid
        foreach my $matching_agent_grid(@matching_agent_grids) {
            #useful vars
            my $check_plugin = $matching_agent_grid->check_plugin();
            my $viz_plugin = $matching_agent_grid->visualization_plugin();
            
            #get grid name
            my $grid_name = "$dashboard_name - ";
            if($task->psconfig_meta_param(META_DISPLAY_NAME())){
                $grid_name .= $task->psconfig_meta_param(META_DISPLAY_NAME());
            }else{
                $grid_name .= $maddash_task_name;
            }
            $grid_name .= ' - ' . $matching_agent_grid->display_name();
            
            my $log_ctx = { 
                "grid_name" => "$grid_name",
                "check_type" => $check_plugin->type(),
                "viz_type" => $viz_plugin->type()
            };
            
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
            
            ##
            #build checks 
            my $tg = new perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator(
                psconfig => $psconfig,
                pscheduler_url => $self->pscheduler_url(),
                task_name => $task_name,
                default_archives => $self->default_archives(),
                use_psconfig_archives => 1
            );
            # A bit of a hack, but this is how we handle labels
            # TODO: Can't currently handle group members that have name and label.
            #  Probably requires changes to MaDDash 'command' option to support.
            my $default_label = "address";
            if($tg->group() && $tg->group()->can('default_label') && $tg->group()->default_label()){
                $default_label = $tg->group()->default_label();
            }
            my $check_vars = $check_plugin->expand_vars($jq_obj);
            if(!$check_vars || $check_plugin->error()){
                $logger->error($self->logf()->format("Error expanding check plugin vars: ".$check_plugin->error(), $log_ctx));
                next;
            }
            my $viz_vars = $viz_plugin->expand_vars($jq_obj);
            if(!$viz_vars || $viz_plugin->error()){
                $logger->error($self->logf()->format("Error expanding vizualization plugin vars: ".$viz_plugin->error(), $log_ctx));
                next;
            }
            my $row_str = "%row.map.$default_label";
            my $col_str = "%col.map.$default_label";
            my $template = new perfSONAR_PS::PSConfig::MaDDash::Template({
                'replace_quotes' => 0,
                'row' => $row_str,
                'col' => $col_str,
                'jq_obj' => $jq_obj,
                'check_config' => $matching_agent_grid->check(),
                'viz_config' => $matching_agent_grid->visualization(),
                'check_defaults' => $check_plugin->defaults(),
                'viz_defaults' => $viz_plugin->defaults(),
                'check_vars' => $check_vars,
                'viz_vars' => $viz_vars,
            });
            
            #expand status labels
            my $maddash_status_labels = $self->_build_maddash_status_labels($template, $check_plugin, $log_ctx);
            next unless($maddash_status_labels); #if problem formatting labels then skip
            $grid->{statusLabels} = $maddash_status_labels;
            
            #build check object
            $grid->{checks} = [];
            my $check_name = $self->_build_check($grid_name, $template, $matching_agent_grid, $tg, 0, $log_ctx);
            next unless($check_name);
            push @{$grid->{checks}}, $check_name;
            
            #build reverse if not a mesh
            unless($row_equal_col){
                #flip row and column
                $template->row($col_str);
                $template->col($row_str);
                $template->flip_ma_url(1);
                my $rev_check_name = $self->_build_check($grid_name, $template, $matching_agent_grid, $tg, 1, $log_ctx);
                next unless($rev_check_name);
                push @{$grid->{checks}}, $rev_check_name;
            }
            
            #build reports
            my $report_name = $self->_load_report_yaml($check_plugin, $matching_agent_grid, $grid_name, $row_equal_col, $log_ctx);
            $grid->{'report'} = $report_name if($report_name);
            
            #add to grids
            push @{$self->grids()}, $grid;
            $logger->info($self->logf()->format("Grid added", $log_ctx));
            
            #add to dashboard
            if($dashboard){
                push @{$dashboard->{'grids'}}, {"name" => $grid_name};
            }
        }
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
        my @sorted_grids = sort {lc($a->{'name'}) cmp lc($b->{'name'})} @{$dashboard->{'grids'}};
        $dashboard->{'grids'} = \@sorted_grids;
        push @{$maddash_yaml->{'dashboards'}}, $dashboard;
    }
    
    ##
    # Add reports
    foreach my $report_id(keys %{$self->report_map()}){
        push @{$maddash_yaml->{'reports'}}, $self->report_map()->{$report_id};
    }

    ##
    # Output maddash yaml
    $self->_save_maddash_yaml($maddash_yaml, $agent_conf->maddash_yaml_file());
    
    ##
    # Clear out globals to save memory
    $self->__reset_globals();
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
    
    return $maddash_yaml;
}

sub _load_plugins {
    my($self, $directory, $name) = @_;

    my $plugin_map = {};
    unless(opendir(PLUGIN_FILES, $directory)){
        $logger->error($self->logf()->format("Could not open $directory"));
        return;
    }
    while (my $plugin_file = readdir(PLUGIN_FILES)) {
        next unless($plugin_file =~ /\.json$/);
        my $abs_file = "$directory/$plugin_file";
        my $log_ctx = {"${name}_plugin_file" => $abs_file};
        $logger->debug($self->logf()->format("Loading $name plug-in file $abs_file", $log_ctx));
        my $client;
        #not ideal, but all the rest of code is exactly the same so probably worth it
        if($name eq 'check'){
            $client = new perfSONAR_PS::PSConfig::MaDDash::Checks::ConfigConnect(url => $abs_file);
        }elsif($name eq 'visualization'){
            $client = new perfSONAR_PS::PSConfig::MaDDash::Visualization::ConfigConnect(url => $abs_file);
        }else{
            $logger->error($self->logf()->format("Programming error, unrecognized plugin type. File a bug, this should not happen.", $log_ctx));
        }
        my $plugin = $client->get_config();
        if($client->error()){
            $logger->error($self->logf()->format("Error reading $name plug-in file: " . $client->error(), $log_ctx));
            next;
        } 
        #validate
        my @errors = $plugin->validate();
        if(@errors){
            my $cat = "${name}_plugin_schema_validation_error";
            foreach my $error(@errors){
                my $path = $error->path;
                $logger->error($self->logf()->format($error->message, {
                    'category' => $cat,
                    'json_path' => $path
                }));
            }
            next;
        }
        $plugin_map->{$plugin->type()} = $plugin;
    }

    return $plugin_map;
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
            $group_member->{'pstoolkiturl'} = $display_url;
        }
        #look for a displayset (special maddash variable)
        my $display_set = $address->psconfig_meta_param(META_DISPLAY_SET());
        if($display_set){
            $group_member->{'displayset'} = $display_set;
        }
        
        #get ready to build a map
        my $map = $group_member->{'map'} ? $group_member->{'map'} : {};
        $map->{'default'} = {} unless($map->{'default'});
        $map->{'default'}->{'address'} = $address->address();
        $map->{'default'}->{'host_id'} = $address->host_ref() if($address->host_ref());
        
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

sub _build_maddash_status_labels {
    my($self, $template, $check_plugin, $log_ctx) = @_;
    
    #expand template
    my $expanded_status_labels = $template->expand($check_plugin->status_labels()->data());
    if($template->error()){
        $logger->error($self->logf()->format("Problem expanding status labels: ".$template->error(), $log_ctx));
        return;
    }
    
    #format for maddash
    my $maddash_status_labels = {};
    $maddash_status_labels->{'ok'} = $expanded_status_labels->{'ok'} if($expanded_status_labels->{'ok'});
    $maddash_status_labels->{'warning'} = $expanded_status_labels->{'warning'} if($expanded_status_labels->{'warning'});
    $maddash_status_labels->{'critical'} = $expanded_status_labels->{'critical'} if($expanded_status_labels->{'critical'});
    $maddash_status_labels->{'notrun'} = $expanded_status_labels->{'notrun'} if($expanded_status_labels->{'notrun'});
    $maddash_status_labels->{'unknown'} = $expanded_status_labels->{'unknown'} if($expanded_status_labels->{'unknown'});
    if($expanded_status_labels->{'extra'}){
        $maddash_status_labels->{'extra'} = [];
        foreach my $extra_obj(@{$expanded_status_labels->{'extra'}}){
            my $maddash_extra_obj = {};
            $maddash_extra_obj->{'value'} = $extra_obj->{'value'};
            $maddash_extra_obj->{'shortName'} = $extra_obj->{'short-name'};
            $maddash_extra_obj->{'description'} = $extra_obj->{'description'};
            push @{$maddash_status_labels->{'extra'}}, $maddash_extra_obj;
        }
    }
    
    return $maddash_status_labels;
}

sub _build_check {
    my($self, $grid_name, $template, $matching_agent_grid, $tg, $is_reverse, $log_ctx) = @_;
    
    ##
    #useful vars
    my $check_plugin = $matching_agent_grid->check_plugin();
    my $viz_plugin = $matching_agent_grid->visualization_plugin();
    my $suffix = $is_reverse ? 'reverse' : 'forward';
    ##        
    #build maUrl
    my $ma_map = {};
    unless($tg->start()){
         $logger->error($self->logf()->format("Error initializing task iterator: " . $tg->error(), $log_ctx));
         return;
    }
    my @addrs;
    while(@addrs = $tg->next()){
        #check for errors expanding task
        if($tg->error()){
            $logger->error($self->logf()->format($tg->error(), $log_ctx));
            next;
        }
        #build map
        my $row = $self->_get_root_address($addrs[0]);
        my $col = (@addrs > 1 ? $self->_get_root_address($addrs[1]) : "default");
        $ma_map->{$row} = {} unless($ma_map->{$row});
        $ma_map->{$row}->{$col} = $self->_select_archive($tg, $matching_agent_grid);
        unless($ma_map->{$row}->{$col}){
            $logger->error($self->logf()->format("Unable to find suitable archive between $row and $col. Check the plugin requirements as well as any selectors you may have defined and verify they match your configuration.", $log_ctx));
            return;
        }
        
    }
    $tg->stop();
    $self->_simplify_map($ma_map);
    
    ##        
    #build graphUrl
    ## more efficient to just used data directly, if change name may cause problems
    my $expanded_http_get_opts = $template->expand($viz_plugin->data()->{'http-get-opts'});
    if($template->error()){
        $logger->error($self->logf()->format("Unable to fill-in HTTP GET options: " . $template->error(), $log_ctx));
        return;
    }
    #set base URL
    my $graphUrl = $viz_plugin->defaults()->base_url();
    if($matching_agent_grid->visualization()->base_url()){
        $graphUrl = $matching_agent_grid->visualization()->base_url();
    }
    #build http get opts
    my $first_get_opt = 1;
    foreach my $expanded_http_get_opt(keys %{$expanded_http_get_opts}){
        my $http_get_opt_obj = new perfSONAR_PS::PSConfig::MaDDash::Visualization::HttpGetOpt('data' => $expanded_http_get_opts->{$expanded_http_get_opt});
        if($http_get_opt_obj->condition() && $http_get_opt_obj->condition() ne 'false'){
            if($first_get_opt){
                $graphUrl .= '?';
                $first_get_opt = 0;
            }else{
                $graphUrl .= '&';
            }
            $graphUrl .= $expanded_http_get_opt;
            $graphUrl .= '=' . $http_get_opt_obj->arg() if(defined $http_get_opt_obj->arg());
        }elsif($http_get_opt_obj->required()){
            $logger->error($self->logf()->format("Unable to generate graphUrl because unable generate $expanded_http_get_opt GET option", $log_ctx));
            return;
        }
    }
    
    ##
    #build command
    ## more efficient to just used data directly, if change name may cause problems
    my $expanded_command_opts = $template->expand($check_plugin->data()->{'command-opts'});
    if($template->error()){
        $logger->error($self->logf()->format("Unable to fill-in command-line options: " . $template->error(), $log_ctx));
        return;
    }
    my $expanded_command_args = $template->expand($check_plugin->command_args());
    if($template->error()){
        $logger->error($self->logf()->format("Unable to fill-in command-line args: " . $template->error(), $log_ctx));
        return;
    }
    #add command
    my @command = ($check_plugin->command());
    #add command opts
    foreach my $expanded_command_opt(keys %{$expanded_command_opts}){
        my $cmd_opt_obj = new perfSONAR_PS::PSConfig::MaDDash::Checks::CommandOpt('data' => $expanded_command_opts->{$expanded_command_opt});
        if($cmd_opt_obj->condition() && $cmd_opt_obj->condition() ne 'false'){
            push  @command, $expanded_command_opt;
            push  @command, $cmd_opt_obj->arg() if($cmd_opt_obj->arg());
        }elsif($cmd_opt_obj->required()){
            $logger->error($self->logf()->format("Unable to generate command because unable generate $expanded_command_opt command option", $log_ctx));
            return;
        }
    }
    #add command args
    push @command, @{$expanded_command_args} if($expanded_command_args);
    
    ##
    # Prepare various options for conversion to MaDDash format
    my $check_defaults = $check_plugin->defaults();
    my $grid_check_config = $matching_agent_grid->check();
    #checkInterval
    my $check_interval = $check_defaults->check_interval();
    if($grid_check_config->check_interval()){
        $check_interval = $grid_check_config->check_interval();
    }
    $check_interval = duration_to_seconds($check_interval);
    #retryInterval
    my $retry_interval = $check_defaults->retry_interval();
    if($grid_check_config->retry_interval()){
        $retry_interval = $grid_check_config->retry_interval();
    }
    $retry_interval = duration_to_seconds($retry_interval);
    #retryAttempts
    my $retry_attempts = $check_defaults->retry_attempts();
    if(defined $grid_check_config->retry_attempts()){
        $retry_attempts = $grid_check_config->retry_attempts();
    }
    #timeout
    my $timeout = $check_defaults->timeout();
    if($grid_check_config->timeout()){
        $timeout = $grid_check_config->timeout();
    }
    $timeout = duration_to_seconds($timeout);
    
    ##
    # bring it all together
    my $check_id = $self->__generate_yaml_key("$grid_name-$suffix");
    my $check_name = $check_plugin->name();
    $check_name .= ' - Reverse' if($is_reverse);
    $self->check_map()->{$check_id} = {
        ADDED_BY_TAG() => 1,
        "type" => "net.es.maddash.checks.PSNagiosCheck",
        "name" => $check_name,
        "description" => $check_plugin->description(),
        "checkInterval" => $check_interval,
        "retryInterval" => $retry_interval,
        "retryAttempts" => $retry_attempts,
        "timeout" => $timeout,
        "params" => {
            "command" => join(' ', @command),
            "maUrl" => $ma_map,
            "graphUrl" =>  $graphUrl
        }
    };
    
    return $check_id;
}

sub _select_archive {
    my($self, $tg, $matching_agent_grid) = @_;
    
    my $check_plugin = $matching_agent_grid->check_plugin();
    my $viz_plugin = $matching_agent_grid->visualization_plugin();
    my $grid_selector = $matching_agent_grid->selector();
    my $grid_archive_selector = $matching_agent_grid->check()->archive_selector();
    
    #build map of allowed archive types
    my $IS_MATCHED = 0; #value an allowed_archive_types entry must have to match
    my %allowed_archive_types = ();
    #check requires archive type
    my $check_required_type = $check_plugin->requires()->archive_type();
    if($check_required_type && @{$check_required_type}){
        $IS_MATCHED += 1;
        foreach my $rt(@{$check_required_type}){
            $allowed_archive_types{$rt} += 1;
        }
    }
    #viz requires archive type
    my $viz_required_type = $viz_plugin->requires()->archive_type();
    if($viz_required_type && @{$viz_required_type}){
        $IS_MATCHED += 1;
        foreach my $vt(@{$viz_required_type}){
            $allowed_archive_types{$vt} += 1;
        }
    }
    #grid selector archive type
    if($grid_selector){
        my $grid_sel_type = $grid_selector->archive_type();
        if($grid_sel_type && @{$grid_sel_type}){
            $IS_MATCHED += 1;
            foreach my $gt(@{$grid_sel_type}){
                $allowed_archive_types{$gt} += 1;
            }
        }
    }
    
    #perform all checks
    my $archive_accessor;
    foreach my $a(@{$tg->expanded_archives()}){
        my $archiver_type = $a->{'archiver'};
        
        #check type
        unless($allowed_archive_types{$archiver_type} && $allowed_archive_types{$archiver_type} == $IS_MATCHED){
            next;
        }
                
        #match against archive-selector
        if($grid_archive_selector){
            my $jq_result = $grid_archive_selector->apply($a);
            next unless($jq_result);
        }
        
        #use archive-accessor to return
        $archive_accessor = $check_plugin->archive_accessor()->apply($a->{'data'});
        last if($archive_accessor);
    }
    
    return $archive_accessor;
}

sub _load_report_yaml {
    my($self, $check_plugin, $matching_agent_grid, $grid_name, $row_equal_col, $log_ctx) = @_;
    
    # get yaml file
    my $report_yaml_file = $check_plugin->defaults()->report_yaml_file();
    my $report_name = $self->__generate_yaml_key($check_plugin->type());
    my $custom_report_name;
    $report_name .= $row_equal_col ? '_1' : '_2'; 
    my $final_report_name = $report_name;
    if($matching_agent_grid->check()->report_yaml_file()){
        $report_yaml_file = $matching_agent_grid->check()->report_yaml_file();
        $custom_report_name = "${grid_name}_${report_name}";
        $final_report_name = $custom_report_name;
    }
    unless($report_yaml_file){
        return;
    }
    
    #check if we already have loaded the report we're after
    if($self->report_map()->{$final_report_name}){
        return $final_report_name;
    }
            
    # Need to make changes to the YAML parser so that the Java YAML parser will
    # grok the output.
    local $YAML::UseHeader = 0;
    local $YAML::CompressSeries = 0;
    
    my $report_yaml;
    eval {
        $report_yaml = LoadFile($report_yaml_file);
    };
    if ($@) {
        $logger->error($self->logf()->format("Problem loading report YAML: ".$@, $log_ctx));
        return;
    }
    
    #simple validation
    unless($report_yaml->{'reports'} && @{$report_yaml->{'reports'}}){
        $logger->error($self->logf()->format("Report YAML is invalid. Top-level must a YAML array labelled 'reports'.", $log_ctx));
        return;
    }
    
    #walk through the loaded reports and grab the one we need
    my $rule;
    foreach my $report(@{$report_yaml->{'reports'}}){
        if($report->{'id'} && $report->{'id'} eq $report_name){
            $rule = $report->{'rule'};
            last;
        }
    }
    unless($rule){
        $logger->warn($self->logf()->format("Unable to find report with name $report_name in $report_yaml_file", $log_ctx));
        return;
    }
    
    #update report map
    $self->report_map()->{$final_report_name} = {
        ADDED_BY_TAG() => 1,
        'id' => $final_report_name,
        'rule' => $rule
    };
    
    return $final_report_name;
}

=item _save_maddash_yaml()

Saves maddash yaml file to disk

=cut

sub _save_maddash_yaml() {
    my ($self, $maddash_yaml, $filename) = @_;
    
    # Need to make changes to the YAML parser so that the Java YAML parser will
    # grok the output.
    local $YAML::UseHeader = 0;
    local $YAML::CompressSeries = 0;
    
    # convert to YAML string
    my $maddash_yaml_str = $self->__quote_ipv6_address(YAML::Dump($maddash_yaml));
    
    #log_ctx
    my $log_ctx = {};
    
    #format filename
    chomp $filename;
    $filename =~ s/^file:\/\///g;
    unless($filename) {
        $self->_set_error("No save_filename set");
        return;
    }
    $log_ctx->{'maddash_yaml_file'} = $filename;
    
    #save
    eval{
        open(my $fh, ">:encoding(UTF-8)", $filename) or die("Can't open $filename: $!");
        print $fh $maddash_yaml_str;
        close $fh;
    };
    if($@){
        $logger->error($self->logf()->format($@, $log_ctx));
        return;
    }
    $logger->info($self->logf()->format("Successfully generated a new MaDDash configuration", $log_ctx));
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

sub __reset_globals {
    my ($self) = @_;
    
    $self->group_member_map({});
    $self->group_map({});
    $self->grids([]);
    $self->dashboards([]);
    $self->check_map({});
    $self->agent_grids([]);
    $self->report_map({});
    $self->auto_dashboard_name_count(0);
}

sub __generate_yaml_key {
  my ($self, $name) = @_;

  $name =~ s/[^a-zA-Z0-9_\-.]/_/g;

  return $name;
}

sub __quote_ipv6_address {
    my ($self, $yaml) = @_;

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

__PACKAGE__->meta->make_immutable;

1;