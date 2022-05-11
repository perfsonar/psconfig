package perfSONAR_PS::PSConfig::PScheduler::Translator;

use Mouse;

use JSON::Validator;
use URI;
use JSON;
use Config::General qw(ParseConfig);
use Data::Dumper;

use perfSONAR_PS::Client::PSConfig::Translators::BaseTranslator;
use perfSONAR_PS::PSConfig::PScheduler::Config;
use perfSONAR_PS::PSConfig::Remote;
use perfSONAR_PS::PSConfig::RequestingAgentConfig;
use perfSONAR_PS::PSConfig::RequestingAgentConnect;
use perfSONAR_PS::Client::PSConfig::Addresses::Address;

extends 'perfSONAR_PS::Client::PSConfig::Translators::BaseTranslator';

has 'save_requesting_agent' => (is => 'rw', isa => 'Bool', default => sub { 0 });
has 'requesting_agent_file' => (is => 'rw', isa => 'Str', default => sub { '/etc/perfsonar/psconfig/requesting-agent.json' });

=item name()

Returns name of translator

=cut

sub name {
    return 'meshconfig-agent.conf';
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
    my $psconfig_agent_conf = new perfSONAR_PS::PSConfig::PScheduler::Config();
    
    #get global configure_archives settings
    my $global_configure_archives = $config->{'configure_archives'} ? 1 : 0;

    #convert meshes
    my %dup_mesh_tracker = ();
    foreach my $mesh(@{$config->{'mesh'}}){
        next unless($mesh->{'configuration_url'});
        my $remote = new perfSONAR_PS::PSConfig::Remote();
        $remote->url($mesh->{'configuration_url'});
        if(defined $mesh->{'configure_archives'}){
            $remote->configure_archives(1) if($mesh->{'configure_archives'});
        }elsif($global_configure_archives){
            $remote->configure_archives(1);
        }
        $remote->ssl_ca_file($mesh->{'ca_certificate_file'}) if($mesh->{'ca_certificate_file'});
        my $remote_checksum = $remote->checksum();
        unless($dup_mesh_tracker{$remote_checksum}){
            #don't trust meshconfig to not have duplicate meshes, so track that here
            $psconfig_agent_conf->add_remote($remote);
            $dup_mesh_tracker{$remote_checksum} = 1;
        }
    }
    
    #convert addresses
    if($config->{'address'}){
        unless(ref($config->{'address'}) eq 'ARRAY'){
            $config->{'address'} = [ $config->{'address'} ];
        }
        foreach my $address(@{$config->{'address'}}){
            $psconfig_agent_conf->add_match_address($address);
        }
    }

    #convert various settings
    if($config->{'pscheduler_url'}){
        my $url_obj = new URI($config->{'pscheduler_url'});
        $psconfig_agent_conf->pscheduler_assist_server($url_obj->host_port);
    }
    $psconfig_agent_conf->pscheduler_fail_attempts(int($config->{'pscheduler_fail_attempts'})) if($config->{'pscheduler_fail_attempts'});
    $psconfig_agent_conf->check_interval($self->_seconds_to_iso($config->{'check_interval'})) if($config->{'check_interval'});
    $psconfig_agent_conf->check_config_interval($self->_seconds_to_iso($config->{'check_config_interval'})) if($config->{'check_config_interval'});
    $psconfig_agent_conf->task_min_ttl($self->_seconds_to_iso($config->{'task_min_ttl'})) if($config->{'task_min_ttl'});
    $psconfig_agent_conf->task_min_runs(int($config->{'task_min_runs'})) if($config->{'task_min_runs'});
    $psconfig_agent_conf->task_renewal_fudge_factor($config->{'task_renewal_fudge_factor'} * 1.0) if($config->{'task_renewal_fudge_factor'});
    #Intentionally ignore below since they will still be in meshconfig directories
    #$psconfig_agent_conf->client_uuid_file($config->{'client_uuid_file'}) if($config->{'client_uuid_file'});
    #$psconfig_agent_conf->pscheduler_tracker_file($config->{'pscheduler_tracker_file'}) if($config->{'pscheduler_tracker_file'});
    
    #convert local_host
    if($config->{'local_host'} && $self->save_requesting_agent() && $config->{'local_host'}->{'address'}){
        # We ignore a lot of other stuff because I am not sure anyone uses this and probably
        # a waste of time to get too complicated. People can open issues or for the handful that do
        # some advanced stuff, they can probably convert manually just as quick
        
        #requesting agent config
        my $ra = new perfSONAR_PS::PSConfig::RequestingAgentConfig();
        
        #global tags
        if($config->{'local_host'}->{'tag'}){
            unless(ref($config->{'local_host'}->{'tag'}) eq 'ARRAY'){
                $config->{'local_host'}->{'tag'} = [ $config->{'local_host'}->{'tag'} ];
            }
        }
        
        #iterate through addresses
        unless(ref($config->{'local_host'}->{'address'}) eq 'ARRAY'){
            $config->{'local_host'}->{'address'} = [ $config->{'local_host'}->{'address'} ];
        }
        foreach my $address(@{$config->{'local_host'}->{'address'}}){
            unless(ref($address) eq 'HASH'){
                $address = {'address' => $address};
            }
            next unless($address->{'address'});
            #init address
            my $address_obj = new perfSONAR_PS::Client::PSConfig::Addresses::Address();
            $address_obj->address($address->{'address'});
            
            #global tags
            foreach my $global_tag(@{$config->{'local_host'}->{'tag'}}){
                $address_obj->add_tag($global_tag);
            }
            #tags
            if($address->{'tag'}){
                unless(ref($address->{'tag'}) eq 'ARRAY'){
                    $address->{'tag'} = [ $address->{'tag'} ];
                }
                foreach my $tag(@{$address->{'tag'}}){
                    $address_obj->add_tag($tag);
                }
            }
            $ra->address($address_obj->address(), $address_obj);
        }
        
        #save to file
        my $ra_client = new perfSONAR_PS::PSConfig::RequestingAgentConnect(
            'save_filename' => $self->requesting_agent_file()
        );
        $ra_client->save_config($ra, {"pretty" => 1, "canonical" => 1});
        if($ra_client->error()){
            $self->_set_error("Error saving " . $self->requesting_agent_file() . ": " . $ra_client->error());
            return;
        }
    }
    
    #build pSConfig Object and validate
    my @errors = $psconfig_agent_conf->validate();
    if(@errors){
        my $err = "Generated PSConfig pScheduler Agent JSON is not valid. Encountered the following validation errors:\n\n";
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

__PACKAGE__->meta->make_immutable;

1;
