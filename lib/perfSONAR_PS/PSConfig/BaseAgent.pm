package perfSONAR_PS::PSConfig::BaseAgent;

=head1 NAME

perfSONAR_PS::Client::PSConfig::BaseAgent - Abstract class for building agent that downloads
JSON config, applies a transform and then does something with it

=head1 DESCRIPTION

Abstract class for building agent that downloads JSON config, applies a transform and 
then does something with it

=cut

use Mouse;

use CHI;
use Data::Dumper;
use Data::Validate::Domain qw(is_hostname);
use Data::Validate::IP qw(is_ipv4 is_ipv6 is_loopback_ipv4);
use Net::CIDR qw(cidrlookup);
use File::Basename;
use JSON qw/ from_json /;
use Log::Log4perl qw(get_logger);
use URI;

use perfSONAR_PS::Client::PSConfig::ApiConnect;
use perfSONAR_PS::Client::PSConfig::ApiFilters;
use perfSONAR_PS::Client::PSConfig::Archive;
use perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator;
use perfSONAR_PS::PSConfig::ArchiveConnect;
use perfSONAR_PS::Utils::Logging;
use perfSONAR_PS::PSConfig::RequestingAgentConnect;
use perfSONAR_PS::PSConfig::TransformConnect;
use perfSONAR_PS::Utils::DNS qw(resolve_address reverse_dns);
use perfSONAR_PS::Utils::Host qw(get_ips);
use perfSONAR_PS::Utils::ISO8601 qw/duration_to_seconds/;

our $VERSION = 4.1;

has 'config_file' => (is => 'rw', isa => 'Str');
has 'include_directory' => (is => 'rw', isa => 'Str');
has 'archive_directory' => (is => 'rw', isa => 'Str');
has 'transform_directory' => (is => 'rw', isa => 'Str');
has 'requesting_agent_file' => (is => 'rw', isa => 'Str');
has 'pscheduler_url' => (is => 'rw', isa => 'Str');
has 'check_interval_seconds' => (is => 'rw', isa => 'Int', default => sub { 3600 });
has 'check_config_interval_seconds' => (is => 'rw', isa => 'Int', default => sub { 60 });
has 'default_archives' => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::Client::PSConfig::Archive]', default => sub { [] });
has 'cache_expires_seconds' => (is => 'rw', isa => 'Int', default => sub { 86400 });
has 'template_cache' => (is => 'rw', isa => 'Object|Undef', default => sub { undef });
has 'default_transforms' => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::Client::PSConfig::JQTransform]', default => sub { [] });
has 'requesting_agent_addresses' => (is => 'rw', isa => 'HashRef');
has 'debug' => (is => 'rw', isa => 'Bool', default => sub { 0 });
has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');
has 'logf' => (is => 'ro', isa => 'perfSONAR_PS::Utils::Logging', writer => '_set_logf', default => sub{ new perfSONAR_PS::Utils::Logging() });

my $logger = get_logger(__PACKAGE__);

sub _agent_name {
    die("Override this");
}

sub _config_client {
    die("Override this");
}

sub _init {
    my ($self) = @_;
    return;
}

sub _run_start {
    my ($self, $agent_conf) = @_;
    return;
}

sub _run_handle_psconfig {
    my ($self, $agent_conf, $remote) = @_;
    die("Override this");
}

sub _run_end {
    my ($self, $agent_conf) = @_;
    return;
}


sub init {
    my ($self, $config_file) = @_;
    
    ##
    # Set the config_file
    $self->config_file($config_file);
    
    ##
    # Set some defaults
    my $CONFIG_DIR = dirname($config_file);
    my $DEFAULT_INCLUDE_DIR = "${CONFIG_DIR}/" . lc($self->_agent_name()) . ".d";
    my $DEFAULT_ARCHIVES_DIR = "${CONFIG_DIR}/archives.d";
    my $DEFAULT_TRANSFORM_DIR = "${CONFIG_DIR}/transforms.d";
    my $DEFAULT_RA_FILE = "${CONFIG_DIR}/requesting-agent.json";
    
    ##
    #Load configuration file
    my $agent_conf;
    eval{ $agent_conf = $self->_load_config($config_file); };
    if($@){
        $self->_set_error($@);
        return;
    }
    
    ##
    # init local logging context
    my $log_ctx = { "agent_conf_file" => "$config_file" };
    
    ##
    # Grab properties and set defaults
    if($agent_conf->include_directory()){
        $self->include_directory($agent_conf->include_directory());
    }else{
        $logger->debug($self->logf()->format("No include directory specified. Defaulting to $DEFAULT_INCLUDE_DIR", $log_ctx));
        $self->include_directory($DEFAULT_INCLUDE_DIR);
    }
    if($agent_conf->archive_directory()){
        $self->archive_directory($agent_conf->archive_directory());
    }else{
        $logger->debug($self->logf()->format("No archives directory specified. Defaulting to $DEFAULT_ARCHIVES_DIR", $log_ctx));
        $self->archive_directory($DEFAULT_ARCHIVES_DIR);
    }
    if($agent_conf->transform_directory()){
        $self->transform_directory($agent_conf->transform_directory());
    }else{
        $logger->debug($self->logf()->format("No transform directory specified. Defaulting to $DEFAULT_TRANSFORM_DIR", $log_ctx));
        $self->transform_directory($DEFAULT_TRANSFORM_DIR);
    }
    if($agent_conf->requesting_agent_file()){
        $self->requesting_agent_file($agent_conf->requesting_agent_file());
    }else{
        $logger->debug($self->logf()->format("No requesting agent file specified. Defaulting to $DEFAULT_RA_FILE", $log_ctx));
        $self->requesting_agent_file($DEFAULT_RA_FILE);
    }
    
    ##
    # Call agent implementation specific initialization
    $self->_init($agent_conf);
    
    return 1;
}

sub run {
    my($self) = @_;
    
    ##
    # Load configuration
    $self->logf()->global_context({'agent_conf_file' => $self->config_file()});
    my $agent_conf;
    eval{
        $agent_conf = $self->_load_config($self->config_file());
    };
    if($@){
        $logger->error($self->logf()->format("Error reading " . $self->config_file() . ", not going to run any updates. Caused by: $@"));
        return;
    }
    
    ##
    # Set assist server - Host/Post to URL
    unless($agent_conf->pscheduler_assist_server()){
        my $default = "localhost";
        $logger->debug($self->logf()->format( "No pscheduler-assist-server specified. Defaulting to $default" ));
        $agent_conf->pscheduler_assist_server($default);
    }
    $self->pscheduler_url($self->_build_pscheduler_url($agent_conf->pscheduler_assist_server()));
    $logger->debug($self->logf()->format("pscheduler_url is " . $self->pscheduler_url()));
    
    ##
    # Set intervals which have instance values used by daemon
    if($agent_conf->check_interval()) {
        my $check_interval;
        eval{ $check_interval = duration_to_seconds($agent_conf->check_interval()) };
        if($@){
            $logger->error($self->logf()->format("Error parsing check-interval. Defaulting to " . $self->check_interval_seconds() . " seconds: $@"));
        }elsif(!$check_interval){
            $logger->error($self->logf()->format("check_interval has no value, sticking with default ". $self->check_interval_seconds() . " seconds"));
        }else{
            $self->check_interval_seconds($check_interval);
        }
        $logger->debug($self->logf()->format("check_interval is " . $self->check_interval_seconds() . " seconds"));
    }
    if($agent_conf->check_config_interval()) {
        my $check_config_interval;
        eval{ $check_config_interval = duration_to_seconds($agent_conf->check_config_interval()) };
        if($@){
            $logger->error($self->logf()->format("Error parsing check-config-interval. Defaulting to " . $self->check_config_interval_seconds() . " seconds: $@"));
        }elsif(!$check_config_interval){
            $logger->error($self->logf()->format("check-config-interval has no value, sticking with default ". $self->check_config_interval_seconds() . " seconds"));
        }else{
            $self->check_config_interval_seconds($check_config_interval);
        }
        $logger->debug($self->logf()->format("check_config_interval is " . $self->check_config_interval_seconds() . " seconds"));
    }
    
    ##
    # Build requesting_address which is used in address classes
    $self->requesting_agent_addresses($self->_requesting_agent_from_file($self->requesting_agent_file()));
    unless($self->requesting_agent_addresses()){
        ##
        # Build requesting agent from all addresses on local machine
        my $auto_detected_addresses = $self->_get_addresses();
        my %requesting_agent = map {$_ => {'address' => $_ }} @{$auto_detected_addresses};
        $self->requesting_agent_addresses(\%requesting_agent);
        $logger->debug($self->logf()->format("Auto-detected requesting agent", {"requesting_agent" => \%requesting_agent}));
    }

    ##
    # Reset logging context, done with config file
    $self->logf()->global_context({'pscheduler_assist_url' => $self->pscheduler_url()});
    
    ##
    #Init the run. If returns false, exit
    unless($self->_run_start($agent_conf)){
        return;
    }
    
    ##
    # Handle cache settings
    $logger->debug($self->logf()->format("disable-cache is " . $agent_conf->disable_cache()));
    if($agent_conf->cache_expires()) {
        my $cache_expires_seconds;
        eval{ $cache_expires_seconds = duration_to_seconds($agent_conf->cache_expires()) };
        if($@){
            $logger->error($self->logf()->format("Error parsing cache-expires. Defaulting to " . $self->cache_expires_seconds() . " seconds: $@"));
        }elsif(!$cache_expires_seconds){
            $logger->error($self->logf()->format("cache-expires has no value, sticking with default ". $self->cache_expires_seconds() . " seconds"));
        }else{
            $self->cache_expires_seconds($cache_expires_seconds);
        }
    }
    $logger->debug($self->logf()->format("cache-expires is " . $self->cache_expires_seconds() . " seconds"));
    
    # Build cache client
    if($agent_conf->disable_cache() || !$agent_conf->cache_directory()){
        $self->template_cache(undef);
    }else{
        my $template_cache = CHI->new( 
            driver => 'File', 
            root_dir => $agent_conf->cache_directory(), 
            expires_in => $self->cache_expires_seconds()
        );
        eval{
            $template_cache->purge();
        };
        if($@){
            $logger->debug("Unable to purge template cache directory. This is non-fatal so moving-on.");
        }
        $self->template_cache($template_cache);
    }
    
    ##
    # Process default archives directory
    #todo: make sure we handle this die correctly
    $self->logf()->global_context({}); #reset logging context
    my @default_archives = ();
    unless(opendir(ARCHIVE_FILES,  $self->archive_directory())){
        $logger->error($self->logf()->format("Could not open " . $self->archive_directory()));
        return;
    }
    while (my $archive_file = readdir(ARCHIVE_FILES)) {
        next unless($archive_file =~ /\.json$/);
        my $abs_file = $self->archive_directory() . "/$archive_file";
        my $log_ctx = {"archive_file" => $abs_file};
        $logger->debug($self->logf()->format("Loading default archive file $abs_file", $log_ctx));
        my $archive_client = new perfSONAR_PS::PSConfig::ArchiveConnect(url => $abs_file);
        my $archive = $archive_client->get_config();
        if($archive_client->error()){
            $logger->error($self->logf()->format("Error reading default archive file: " . $archive_client->error(), $log_ctx));
            next;
        } 
        #validate
        my @errors = $archive->validate();
        if(@errors){
            my $cat = "archive_schema_validation_error";
            foreach my $error(@errors){
                my $path = $error->path;
                $path =~ s/^\/archives//; #makes prettier error message
                $logger->error($self->logf()->format($error->message, {
                    'category' => $cat,
                    'json_path' => $path
                    
                }));
            }
            next;
        }

        push @default_archives, $archive;
    }
    $self->default_archives(\@default_archives);
        
    ##
    # Process default transforms directory
    my @default_transforms = ();
    unless(opendir(TRANSFORM_FILES,  $self->transform_directory())){
        $logger->error($self->logf()->format("Could not open " . $self->transform_directory()));
        return;
    }
    while (my $transform_file = readdir(TRANSFORM_FILES)) {
        next unless($transform_file =~ /\.json$/);
        my $abs_file = $self->transform_directory() . "/$transform_file";
        my $log_ctx = {"transform_file" => $abs_file};
        $logger->debug($self->logf()->format("Loading transform file $abs_file", $log_ctx));
        my $transform_client = new perfSONAR_PS::PSConfig::TransformConnect(url => $abs_file);
        my $transform = $transform_client->get_config();
        if($transform_client->error()){
            $logger->error($self->logf()->format("Error reading default transform file: " . $transform_client->error(), $log_ctx));
            next;
        } 
        #validate
        my @errors = $transform->validate();
        if(@errors){
            my $cat = "transform_schema_validation_error";
            foreach my $error(@errors){
                my $path = $error->path;
                $path =~ s/^\/transform//; #makes prettier error message
                $logger->error($self->logf()->format($error->message, {
                    'category' => $cat,
                    'json_path' => $path
                    
                }));
            }
            next;
        }

        push @default_transforms, $transform;
    }
    $self->default_transforms(\@default_transforms);
        
    ##
    # Process remotes
    my %psconfig_checksum_tracker = ();
    foreach my $remote(@{$agent_conf->remotes()}){
        #create api filters 
        my $filters = new perfSONAR_PS::Client::PSConfig::ApiFilters(
            ca_certificate_file => $remote->ssl_ca_file()
        );
        #create client
        my $psconfig_client = new perfSONAR_PS::Client::PSConfig::ApiConnect(
            url => $remote->url(),
            filters =>  $filters,
            bind_address => $remote->bind_address()
        );
        #process tasks
        $self->logf()->global_context({"config_src" => 'remote', 'config_url' => $remote->url()});
        my $processed_psconfig = $self->_process_psconfig($psconfig_client, $remote->transform());
        unless($processed_psconfig){
            next;
        }
        my $processed_psconfig_checksum = $processed_psconfig->checksum();
        if($psconfig_checksum_tracker{$processed_psconfig_checksum}){
            $logger->warn($self->logf()->format("Checksum matches another psconfig already read, so skipping"));
            next;
        }else{
            $psconfig_checksum_tracker{$processed_psconfig_checksum} = 1;
        }
        $self->_run_handle_psconfig($processed_psconfig, $agent_conf, $remote) if($processed_psconfig);
        $self->logf()->global_context({});
    }
    
    ##
    # Process include directory
    unless(opendir(INCLUDE_FILES,  $self->include_directory())){
        $logger->error($self->logf()->format("Could not open " . $self->include_directory()));
        return;
    }
    while (my $include_file = readdir(INCLUDE_FILES)) {
        next unless($include_file =~ /\.json$/);
        my $abs_file = $self->include_directory() . "/$include_file";
        my $log_ctx = {"template_file" => $abs_file};
        $logger->debug($self->logf()->format("Loading include file $abs_file", $log_ctx));
        #create client
        my $psconfig_client = new perfSONAR_PS::Client::PSConfig::ApiConnect(
            url => $abs_file
        );
        #process tasks
        $self->logf()->global_context({"config_src" => 'include', 'config_file' => $abs_file});
        my $processed_psconfig = $self->_process_psconfig($psconfig_client);
        my $processed_psconfig_checksum = $processed_psconfig->checksum();
        if($psconfig_checksum_tracker{$processed_psconfig_checksum}){
            $logger->warn($self->logf()->format("Checksum matches another psconfig already read, so skipping", $log_ctx));
            next;
        }else{
            $psconfig_checksum_tracker{$processed_psconfig_checksum} = 1;
        }
        $self->_run_handle_psconfig($processed_psconfig, $agent_conf) if($processed_psconfig);
        $self->logf()->global_context({});
    }
    
    ##
    # Call implementation specific code to wrap-up run
    $self->_run_end($agent_conf);

}

sub _process_psconfig {
    my ($self, $psconfig_client, $transform) = @_;
    
    #variable to track whether we are working with cached copy
    my $using_cached = 0;
    
    #get config
    my $psconfig = $psconfig_client->get_config();
    if($psconfig_client->error()){
        $logger->error($self->logf()->format("Error loading psconfig: " . $psconfig_client->error()));
        $psconfig = $self->_get_cached_template($psconfig_client->url());
        return unless($psconfig);
        $using_cached = 1;
    } 
    $logger->debug($self->logf()->format('Loaded pSConfig JSON', {'json' => $psconfig->json()}));
    
    #validate
    my @errors = $psconfig->validate();
    if(@errors){
        my $cat = "psconfig_schema_validation_error";
        foreach my $error(@errors){
            $logger->error($self->logf()->format($error->message, {
                'category' => $cat,
                'expanded' => 0,
                'transformed' => 0,
                'json_path' => $error->path
            }));
        }
        $psconfig = $self->_get_cached_template($psconfig_client->url());
        return unless($psconfig);
        $using_cached = 1;
    }

    #expand
    if($psconfig->includes()){
        $psconfig_client->expand_config($psconfig);
        if($psconfig_client->error()){
            $logger->error($self->logf()->format("Error expanding include directives in JSON: " . $psconfig_client->error()));
            $psconfig = $self->_get_cached_template($psconfig_client->url());
            return unless($psconfig);
            $using_cached = 1;
        }

        #validate
        @errors = $psconfig->validate();
        if(@errors){
            my $cat = "psconfig_schema_validation_error";
            foreach my $error(@errors){
               $logger->error($self->logf()->format($error->message, {
                    'category' => $cat,
                    'expanded' => 1,
                    'transformed' => 0,
                    'json_path' => $error->path
                }));
            }
            $psconfig = $self->_get_cached_template($psconfig_client->url());
            return unless($psconfig);
            $using_cached = 1;
        }
    }
    
    #if we got this far, cache the template. do this prior to transforms or 
    #we might get strange results. DO NOT do this if we are using a cached version
    # or else the cached item will never expire
    if($self->template_cache() && !$using_cached){
        eval{
            $self->template_cache()->set($psconfig_client->url(), $psconfig->json());
            $logger->debug("Caching template " . $psconfig_client->url());
        };
        if($@){
            $logger->debug("Error caching " . $psconfig_client->url() . "This is non-fatal.");
        }
    }
    
    #apply default transforms
    foreach my $default_transform(@{$self->default_transforms()}){
        $self->_apply_transform($default_transform, $psconfig, 'include');
    }
    
    #apply local transform
    $self->_apply_transform($transform, $psconfig, 'remote_spec');
    
    #set requesting agent
    $psconfig->requesting_agent_addresses($self->requesting_agent_addresses());
    
    return $psconfig;
}

sub _get_cached_template {
    my ($self, $key) = @_;
    
    #if no cache, return
    unless($self->template_cache()){
        return;
    }
    
    #check cache
    my $psconfig_json;
    eval{
        my $cached_txt = $self->template_cache()->get($key);
        $psconfig_json = from_json($cached_txt) if($cached_txt);
    }; 
    if($@){
        $logger->debug("Unable to load cached template for $key: " . $@);
    }
    
    #build psconfig object
    my $psconfig;
    if($psconfig_json){
        $psconfig = new perfSONAR_PS::Client::PSConfig::Config(data => $psconfig_json);
        my @errors = $psconfig->validate();
        if(@errors){
            $logger->debug("Invalid cached template found for for $key");
            foreach my $error(@errors){
                my $path = $error->path;
                $logger->error($self->logf()->format($error->message, {
                    'category' => "cached_schema_validation_error",
                    'json_path' => $path

                }));
            }
        }else{
            $logger->info("Using cached JSON template for $key");
        }
    }
    
    return $psconfig;
}

sub _load_config {
    my ($self, $config_file) = @_;
    
    ##
    #load config file
    my $agent_conf_client = $self->_config_client();
    $agent_conf_client->url($config_file);
    if($agent_conf_client->error()){
        die "Error opening $config_file: " . $agent_conf_client->error();
    } 
    my $agent_conf = $agent_conf_client->get_config();
    if($agent_conf_client->error()){
        die "Error parsing $config_file: " . $agent_conf_client->error();
    }
    my @agent_conf_errors = $agent_conf->validate();
    if(@agent_conf_errors){
        my $err = "$config_file is not valid. The following errors were encountered: ";
        foreach my $error(@agent_conf_errors){
            $err .= "    JSON Path: " . $error->path . "\n";
            $err .= "    Error: " . $error->message . "\n\n";
        }
        die $err;
    }
    
    return $agent_conf;
}

sub _get_addresses {
    my ($self) = @_;
    
    my $hostname = `hostname -f 2> /dev/null`;
    chomp($hostname);

    my @ips = get_ips();

    my %ret_addresses = ();

    my @all_addresses = ();
    foreach my $ip(@ips){
        push @all_addresses, $ip unless(is_loopback_ipv4($ip) || (is_ipv6($ip) && cidrlookup($ip, "::1/128")));
    }
    
    push @all_addresses, $hostname if ($hostname);

    foreach my $address (@all_addresses) {
        next if (!$address || $ret_addresses{$address});

        $ret_addresses{$address} = 1;

        if ( is_ipv4( $address ) or 
             is_ipv6( $address ) ) {
            my @hostnames = reverse_dns($address);

            push @all_addresses, @hostnames;
        }
        elsif ( is_hostname( $address ) ) {
            my $hostname = $address;

            my @addresses = resolve_address($hostname);

            push @all_addresses, @addresses;
        }
    }

    my @ret_addresses = keys %ret_addresses;

    return \@ret_addresses;
}

sub _build_pscheduler_url {
    my ($self, $hostport) = @_;
    
    my $uri = new URI();
    $uri->scheme('https');
    $uri->host_port($hostport);
    $uri->path('pscheduler');
    
    return $uri->as_string;
}

sub _requesting_agent_from_file {
    my ($self, $requesting_agent_file) = @_;
    my $log_ctx = {'requesting_agent_file' => $requesting_agent_file};
    
    #if no file, return
    unless($requesting_agent_file){
        return;
    }
    
    #if file does not exist then return
    unless(-e $requesting_agent_file){
        return;
    }
    
    #try loading from file
    my $ra_client = new perfSONAR_PS::PSConfig::RequestingAgentConnect(url => $requesting_agent_file);
    my $requesting_agent = $ra_client->get_config();
    if($ra_client->error()){
        $logger->error($self->logf()->format("Error reading requesting agent file: " . $ra_client->error(), $log_ctx));
        return;
    } 
    #validate
    my @errors = $requesting_agent->validate();
    if(@errors){
        my $cat = "requesting_agent_schema_validation_error";
        foreach my $error(@errors){
            my $path = $error->path;
            $path =~ s/^\/addresses//; #makes prettier error message
            $logger->error($self->logf()->format($error->message, {
                'category' => $cat,
                'json_path' => $path,
                'requesting_agent_file' => $requesting_agent_file
            }));
        }
        return;
    }
    
    #return data
    $log_ctx->{"requesting_agent"} = $requesting_agent->data();
    $logger->debug($self->logf()->format("Loaded requesting agent from file $requesting_agent_file", $log_ctx));
    return $requesting_agent->data();
}

sub _apply_transform {
    my ($self, $transform, $psconfig, $transform_src) = @_;
    
    #make sure we got params we need
    unless($transform && $psconfig && $transform_src){
        return;
    }
    
    #set log context
    my $log_ctx = {'transform_src' => "$transform_src"};
    
    #try to apply transformation
    my $new_data = $transform->apply($psconfig->data());
    if(!$new_data && $transform->error()){
        # error applying script
        $logger->error($self->logf()->format("Error applying transform: " . $transform->error(), $log_ctx));
        return;
    }elsif(!$new_data){
        #jq returned undefined value
        $logger->error($self->logf()->format("Transform returned undefined value with no error. Check your JQ script logic.", $log_ctx));
        return;
    }elsif(ref $new_data ne 'HASH'){
        #jq returned non hash value
        $logger->error($self->logf()->format("Transform returned a value that is not a JSON object. Check your JQ script logic.", $log_ctx));
        return;
    }
    
    #validate JSON after applying
    $psconfig->data($new_data);
    my @errors = $psconfig->validate();
    if(@errors){
        #validation errors
        my $cat = "psconfig_schema_validation_error";
        foreach my $error(@errors){
            $logger->error($self->logf()->format($error->message, {
                'category' => $cat,
                'json_path' => $error->path,
                'expanded' => 1,
                'transformed' => 1,
                'transform_src' => "$transform_src"
            }));
        }
        return;
    }
    
    $log_ctx->{'json'} = $psconfig->json();
    $logger->debug($self->logf()->format("Transform completed", $log_ctx));
}


__PACKAGE__->meta->make_immutable;

1;