package perfSONAR_PS::PSConfig::MaDDash::Translator;

use Mouse;

use JSON::Validator;
use JSON;
use Config::General qw(ParseConfig);
use Data::Dumper;

use perfSONAR_PS::Client::PSConfig::Translators::BaseTranslator;
use perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig;
use perfSONAR_PS::PSConfig::MaDDash::Agent::Config;
use perfSONAR_PS::PSConfig::MaDDash::Agent::Grid;
use perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;
use perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig;
use perfSONAR_PS::PSConfig::Remote;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;

extends 'perfSONAR_PS::Client::PSConfig::Translators::BaseTranslator';

=item name()

Returns name of translator

=cut

sub name {
    return 'meshconfig-guiagent.conf';
}

=item can_translate()

Determines if given JSON object can be converted to MeshConfig format, if can prepare object
for translation

=cut


sub can_translate {
    my ($self, $raw_config, $json_obj) = @_;
    
    #this config is not JSON
    return 0 if($json_obj || !$raw_config);
    
    #clear errors
    $self->_set_error('');

    #try to read
    my $config = $self->_load_config($raw_config);
    return 0 unless($config);
    
    #looks good  
    return 1;
}

=item translate()

Translates MeshConfig file to pSConfig format

=cut

sub translate {
    my ($self, $raw_config, $json_obj) = @_;
    
    #clear errors
    $self->_set_error('');
    
    #First validate this config
    my $config = $self->_load_config($raw_config);
    return unless($config);
    #convert tests to array
    unless(ref($config->{'mesh'}) eq 'ARRAY'){
        $config->{'mesh'} = [ $config->{'mesh'} ];
    }
    #set to data
    $self->data($config);
    
    #init translation
    my $psconfig_agent_conf = new perfSONAR_PS::PSConfig::MaDDash::Agent::Config();

    #convert meshes
    my %dup_mesh_tracker = ();
    foreach my $mesh(@{$config->{'mesh'}}){
        next unless($mesh->{'configuration_url'});
        my $remote = new perfSONAR_PS::PSConfig::Remote();
        $remote->url($mesh->{'configuration_url'});
        $remote->ssl_ca_file($mesh->{'ca_certificate_file'}) if($mesh->{'ca_certificate_file'});
        my $remote_checksum = $remote->checksum();
        unless($dup_mesh_tracker{$remote_checksum}){
            #don't trust meshconfig to not have duplicate meshes, so track that here
            $psconfig_agent_conf->add_remote($remote);
            $dup_mesh_tracker{$remote_checksum} = 1;
        }
    }

    #convert various settings
    $psconfig_agent_conf->maddash_yaml_file($config->{'maddash_yaml'}) if($config->{'maddash_yaml'});
    $psconfig_agent_conf->check_interval($self->_seconds_to_iso($config->{'check_interval'})) if($config->{'check_interval'});
    $psconfig_agent_conf->check_config_interval($self->_seconds_to_iso($config->{'check_config_interval'})) if($config->{'check_config_interval'});
    
    #convert maddash_options
    ## convert perfsonarbuoy/owamp
    $self->_convert_grids($config, $psconfig_agent_conf, 'perfsonarbuoy/owamp', 'loss', 'Loss', 'ps-nagios-loss', 'ps-graphs', 'acceptable_loss_rate', 'critical_loss_rate', 1);
    ## convert perfsonarbuoy/bwctl
    $self->_convert_grids($config, $psconfig_agent_conf, 'perfsonarbuoy/bwctl', 'throughput', 'Throughput', 'ps-nagios-throughput', 'ps-graphs', 'acceptable_throughput', 'critical_throughput', 1, 1000.0);
    ## convert simplestream
    #TODO: Maybe need a no-op viz
    $self->_convert_grids($config, $psconfig_agent_conf, 'simplestream', 'simplestream', 'Simplestream Count', 'ps-nagios-pscheduler-raw', 'ps-graphs', 'acceptable_count', 'critical_count', 0);
    ## convert traceroute
    $self->_convert_grids($config, $psconfig_agent_conf, 'traceroute', 'trace', 'Path Count', 'ps-nagios-traceroute', 'ps-traceroute-viewer', 'acceptable_count', 'critical_count', 1);
    ## convert ping
    $self->_convert_grids($config, $psconfig_agent_conf, 'pinger', 'ping_loss', 'Ping Loss', 'ps-nagios-ping-loss', 'ps-graphs', 'acceptable_loss_rate', 'critical_loss_rate', 1);
    
    #build pSConfig Object and validate
    my @errors = $psconfig_agent_conf->validate();
    if(@errors){
        my $err = "Generated PSConfig MaDDash Agent JSON is not valid. Encountered the following validation errors:\n\n";
        foreach my $error(@errors){
            $err .= "   Node: " . $error->path . "\n";
            $err .= "   Error: " . $error->message . "\n\n";
        }
        $self->_set_error($err);
        return;
    }
    
    return $psconfig_agent_conf;
}

=item _load_config()

Loads config and does simple validation

=cut

sub _load_config {
    my ($self, $raw_config) = @_;
    
    #load from file
    my %config;
    eval {
        %config = ParseConfig(-String => $raw_config, -UTF8 => 1);
    };
    if ($@) {
        return;
    }
    
    #validate
    unless($config{'mesh'}){
        return;
    }
    
    return \%config;
}

sub _seconds_to_iso {
    my ($self, $secs) = @_;
    
    $secs = int($secs);
    return "PT${secs}S";
}

sub _format_name {
    my ($self, $val) = @_;
    
    #replace spaces
    $val =~ s/\s/_/g;
    #replace invalid character
    $val =~ s/[^a-zA-Z0-9:._\\-]//g;
    
    return $val;
}

sub _convert_grids {
    my ($self, $config, $psconfig_agent_conf, $old_type, $label, $display_name, $check_type, $viz_type, $warn_field, $crit_field, $set_default, $thres_factor) = @_;
    
    ## convert perfsonarbuoy/bwctl
    if($config->{'maddash_options'}->{$old_type}){
        unless(ref($config->{'maddash_options'}->{$old_type}) eq 'ARRAY'){
            $config->{'maddash_options'}->{$old_type} = [$config->{'maddash_options'}->{$old_type}];
        }
        my $i = 0;
        foreach my $maddash_opt(@{$config->{'maddash_options'}->{$old_type}}){
            #make sure it's enabled
            if(defined $maddash_opt->{'enabled'} && !$maddash_opt->{'enabled'}){
                next;
            }
            
            #init
            my $grid_name = "${label}_${i}";
            my $grid = new perfSONAR_PS::PSConfig::MaDDash::Agent::Grid();
            $grid->display_name($display_name);
            
            #set a default priority, will increase if we have selector
            my $priority = new perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority();
            $priority->group($label);
            $priority->level(1);
            $grid->priority($priority);
            
            #look for grid_name so can build task selector
            #NOTE: Assumes you are pointing at translated JSON so names are predictable
            if($maddash_opt->{'grid_name'}){
                my $sel = new perfSONAR_PS::PSConfig::MaDDash::TaskSelector();
                $priority->level(2); #bump priority
                unless(ref($maddash_opt->{'grid_name'}) eq 'ARRAY'){
                    $maddash_opt->{'grid_name'} = [$maddash_opt->{'grid_name'}];
                }
                foreach my $old_grid_name(@{$maddash_opt->{'grid_name'}}){
                    #remove the mesh name prefix
                    $old_grid_name =~ s/^.+? - //;
                    $sel->add_task_name($self->_format_name($old_grid_name));
                }
                $grid->selector($sel);
            }
            
            #build check config
            my $check = new perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig();
            $check->type($check_type);
            $check->check_interval($self->_seconds_to_iso($maddash_opt->{'check_interval'})) if($maddash_opt->{'check_interval'});
            if($thres_factor){
                $check->warning_threshold($maddash_opt->{$warn_field}/$thres_factor . '') if($maddash_opt->{$warn_field});
                $check->critical_threshold($maddash_opt->{$crit_field}/$thres_factor . '') if($maddash_opt->{$crit_field});
            }else{
                $check->warning_threshold($maddash_opt->{$warn_field} . '') if($maddash_opt->{$warn_field});
                $check->critical_threshold($maddash_opt->{$crit_field} . '') if($maddash_opt->{$crit_field});
            }
            $check->retry_interval($self->_seconds_to_iso($maddash_opt->{'retry_interval'})) if($maddash_opt->{'retry_interval'});
            $check->retry_attempts(int($maddash_opt->{'retry_attempts'})) if($maddash_opt->{'retry_attempts'});
            $check->timeout($self->_seconds_to_iso($maddash_opt->{'timeout'})) if($maddash_opt->{'timeout'});            
            ##params
            $check->param("time-range", int($maddash_opt->{'check_time_range'})) if($maddash_opt->{'check_time_range'});
            $grid->check($check);
            
            #build visualization
            my $viz = new perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig();
            $viz->type($viz_type);
            $viz->base_url($maddash_opt->{'graph_url'}) if($maddash_opt->{'graph_url'});
            $grid->visualization($viz);
            
            $psconfig_agent_conf->grid($grid_name, $grid);
            $i++;
        }
    }elsif($set_default){
        #build a bare-bones default check
        my $grid = new perfSONAR_PS::PSConfig::MaDDash::Agent::Grid();
        my $grid_name = "default_${label}";
        $grid->display_name($display_name);
        my $check = new perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig();
        $check->type($check_type);
        $grid->check($check);
        my $viz = new perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig();
        $viz->type($viz_type);
        $grid->visualization($viz);
        $psconfig_agent_conf->grid($grid_name, $grid);
    }
}

__PACKAGE__->meta->make_immutable;

1;
