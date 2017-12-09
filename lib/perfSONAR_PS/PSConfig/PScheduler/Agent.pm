package perfSONAR_PS::PSConfig::PScheduler::Agent;

=head1 NAME

perfSONAR_PS::Client::PSConfig::Agent - Agent that loads config, grabs meshes and submits to pscheduler

=head1 DESCRIPTION

Agent that loads config, grabs meshes and submits to pscheduler

=cut

use Mouse;

use Data::Validate::Domain qw(is_hostname);
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use File::Basename;
use Log::Log4perl qw(get_logger);
use URI;

use perfSONAR_PS::Client::PScheduler::TaskManager;
use perfSONAR_PS::Client::PScheduler::Task;
use perfSONAR_PS::Client::PSConfig::ApiConnect;
use perfSONAR_PS::Client::PSConfig::ApiFilters;
use perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator;
use perfSONAR_PS::PSConfig::PScheduler::ConfigConnect;
use perfSONAR_PS::PSConfig::PScheduler::Config;
use perfSONAR_PS::Utils::DNS qw(resolve_address reverse_dns);
use perfSONAR_PS::Utils::Host qw(get_ips);
use perfSONAR_PS::Utils::ISO8601 qw/duration_to_seconds/;

our $VERSION = 4.1;

has 'config_file' => (is => 'rw', isa => 'Str');
has 'include_directory' => (is => 'rw', isa => 'Str');
has 'archive_directory' => (is => 'rw', isa => 'Str');
has 'config' => (is => 'rw', isa => 'perfSONAR_PS::PSConfig::PScheduler::Config');
has 'check_interval_seconds' => (is => 'rw', isa => 'Int', default => sub { 3600 });
has 'check_config_interval_seconds' => (is => 'rw', isa => 'Int', default => sub { 60 });
has 'pscheduler_fails' => (is => 'rw', isa => 'Int', default => sub { 0 });
has 'max_pscheduler_attempts' => (is => 'rw', isa => 'Int', default => sub { 5 });
has 'pscheduler_url' => (is => 'rw', isa => 'Str');
has 'match_addresses' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
has 'debug' => (is => 'rw', isa => 'Bool', default => sub { 0 });
has 'error' => (is => 'ro', isa => 'Str', writer => '_set_error');

my $logger = get_logger(__PACKAGE__);

sub init {
    my ($self, $config_file) = @_;
    
    ##
    # Set the config_file
    $self->config_file($config_file);
    
    ##
    # Set some defaults
    my $CONFIG_DIR = dirname($config_file);
    my $DEFAULT_INCLUDE_DIR = "${CONFIG_DIR}/pscheduler.d";
    my $DEFAULT_ARCHIVES_DIR = "${CONFIG_DIR}/archives.d";

    ##
    #Load configuration file
    my $agent_conf;
    eval{ $agent_conf = $self->_load_config($config_file); };
    if($@){
        $self->_set_error($@);
        return;
    }

    ##
    # Grab properties and set defaults
    if($agent_conf->include_directory()) {
        $self->include_directory($agent_conf->include_directory());
    }else{
        $logger->debug("No include directory specified. Defaulting to $DEFAULT_INCLUDE_DIR");
        $self->include_directory($DEFAULT_INCLUDE_DIR);
    }
    if($agent_conf->archive_directory()) {
        $self->archive_directory($agent_conf->archive_directory());
    }else{
        $logger->debug("No archives directory specified. Defaulting to $DEFAULT_ARCHIVES_DIR");
        $self->archive_directory($DEFAULT_ARCHIVES_DIR);
    }
    
    ##
    # pscheduler_fail_attempts goes in max_pscheduler_attempts if set
    if(defined $agent_conf->pscheduler_fail_attempts()) {
        $self->max_pscheduler_attempts($agent_conf->pscheduler_fail_attempts());
    }
    
    ##
    # Set the config
    $self->config($agent_conf);

}

sub run {
    my($self) = @_;
    
    ##
    # Load configuration
    my $agent_conf;
    eval{
        $agent_conf = $self->_load_config($self->config_file());
    };
    if($@){
        $logger->error("Error reading " . $self->config_file() . ", proceeding with defaults. Caused by: $@");
        $agent_conf = new perfSONAR_PS::PSConfig::PScheduler::Config();
    }
    
    ##
    # Set the config
    $self->config($agent_conf);
    
    ##
    # Set defaults for minimal values requiring no transformation
    unless($agent_conf->client_uuid_file()){
        my $default = "/var/lib/perfsonar/psconfig/client_uuid";
        $logger->debug("No client-uuid-file specified. Defaulting to $default");
        $agent_conf->client_uuid_file($default);
    }
    
    unless($agent_conf->pscheduler_tracker_file()){
        my $default = "/var/lib/perfsonar/psconfig/psc_tracker";
        $logger->debug("No pscheduler-tracker-file specified. Defaulting to $default");
        $agent_conf->pscheduler_tracker_file($default);
    }
    
    ##
    # Set assist server - Host/Post to URL
    unless($agent_conf->pscheduler_assist_server()){
        my $default = "localhost";
        $logger->debug( "No pscheduler-assist-server specified. Defaulting to $default" );
        $agent_conf->pscheduler_assist_server($default);
    }
    $self->pscheduler_url($self->_build_pscheduler_url($agent_conf->pscheduler_assist_server()));
    $logger->debug("pscheduler_url is " . $self->pscheduler_url());
    
    ##
    # Set intervals which have instance values used by daemon
    if($agent_conf->check_interval()) {
        my $check_interval;
        eval{ $check_interval = duration_to_seconds($agent_conf->check_interval()) };
        if($@){
            $logger->error("Error parsing check-interval. Defaulting to " . $self->check_interval_seconds() . " seconds: $@");
        }elsif(!$check_interval){
            $logger->error("check_interval has no value, sticking with default ". $self->check_interval_seconds() . " seconds");
        }else{
            $self->check_interval_seconds($check_interval);
        }
        $logger->debug("check_interval is " . $self->check_interval_seconds() . " seconds");
    }
    if($agent_conf->check_config_interval()) {
        my $check_config_interval;
        eval{ $check_config_interval = duration_to_seconds($agent_conf->check_config_interval()) };
        if($@){
            $logger->error("Error parsing check-config-interval. Defaulting to " . $self->check_config_interval_seconds() . " seconds: $@");
        }elsif(!$check_config_interval){
            $logger->error("check-config-interval has no value, sticking with default ". $self->check_config_interval_seconds() . " seconds");
        }else{
            $self->check_config_interval_seconds($check_config_interval);
        }
        $logger->debug("check_config_interval is " . $self->check_config_interval_seconds() . " seconds");
    }
    my $task_min_ttl_seconds = 86400;
    if($agent_conf->task_min_ttl()) {
        my $task_min_ttl;
        eval{ $task_min_ttl = duration_to_seconds($agent_conf->task_min_ttl()) };
        if($@){
            $logger->error("Error parsing task-min-ttl. Defaulting to " . $self->task_min_ttl() . " seconds: $@");
        }elsif(!$task_min_ttl){
            $logger->error("task_min_ttl has no value, sticking with default ". $self->task_min_ttl() . " seconds");
        }else{
            $task_min_ttl_seconds = $task_min_ttl;
        }
        $logger->debug("task_min_ttl is $task_min_ttl_seconds seconds");
    }
    
    unless ($agent_conf->task_min_runs()) {
        my $default = 2;
        $logger->debug( "No task-min-runs specified. Defaulting to $default" );
        $agent_conf->task_min_runs($default);
    }
    
    unless ($agent_conf->task_renewal_fudge_factor()) {
        my $default = .25;
        $logger->debug( "No task-renewal-fudge-factor specified. Defaulting to $default" );
        $agent_conf->task_renewal_fudge_factor($default);
    }

    ###
    #Determine match addresses
    my $match_addresses = $agent_conf->match_addresses();
    unless($match_addresses && @{$match_addresses}) {
        $match_addresses = $self->_get_addresses();
    }
    foreach my $match_address(@{$match_addresses}){
        $logger->debug("Match Address: $match_address");
    }
    $self->match_addresses($match_addresses);

#     #todo: handle default archives and configure_archives -probably need a $self->default_archives()
#     
#     #todo: handle requesting agent  -probably need a $self->requesting_agent()
#     
#     #todo handle jq
#     
#     #todo: check binding options - even when downloading meshes
#      
#     #todo: make sure timeouts are set correctly
#
#     #todo: make sure i am happy with error reporting
#    
    ##
    #Init the TaskManager
    my $old_task_deadline = time + $self->check_interval_seconds();
    my $task_manager;        
    eval{
        $task_manager = new perfSONAR_PS::Client::PScheduler::TaskManager();
        $task_manager->init(
                            pscheduler_url => $self->pscheduler_url(),
                            tracker_file => $agent_conf->pscheduler_tracker_file(),
                            client_uuid_file => $agent_conf->client_uuid_file(),
                            user_agent => "psconfig-pscheduler-agent",
                            new_task_min_ttl => $task_min_ttl_seconds,
                            new_task_min_runs => $agent_conf->task_min_runs(),
                            old_task_deadline => $old_task_deadline,
                            task_renewal_fudge_factor => $agent_conf->task_renewal_fudge_factor(),
                            bind_map => {},#\%bind_map,
                            lead_address_map => {},#\%pscheduler_addr_map,
                            debug => $self->debug()
                        );
    };
    if($@){
        $logger->error("Problem initializing task_manager: $@");
    }elsif(!$task_manager->check_assist_server()){
        $logger->error("Problem contacting pScheduler, will try again later.");
        $self->pscheduler_fails($self->pscheduler_fails() + 1);
    }else{
        $logger->info("pScheduler is back up, resuming normal operation") if($self->pscheduler_fails());
        $self->pscheduler_fails(0);
        
        ##
        # Process remotes
        foreach my $remote(@{$agent_conf->remotes()}){
            #create api filters 
            my $filters = new perfSONAR_PS::Client::PSConfig::ApiFilters(
                ca_certificate_file => $remote->ssl_ca_file(),
                ca_certificate_path => $remote->ssl_ca_path(),
                verify_hostname => $remote->ssl_validate_certificate(),
            );
            #create client
            my $psconfig_client = new perfSONAR_PS::Client::PSConfig::ApiConnect(
                url => $remote->url(),
                filters =>  $filters
            );
            #process tasks
            $self->_process_tasks($psconfig_client, $task_manager);
        }
        
        ##
        # Process include directory
        #todo: make sure we handle this die correctly
        opendir(INCLUDE_FILES,  $self->include_directory()) or die "Could not open " . $self->include_directory();
        while (my $include_file = readdir(INCLUDE_FILES)) {
            next unless($include_file =~ /\.json$/);
            my $abs_file = $self->include_directory() . "/$include_file";
            $logger->debug("Loading include file $abs_file");
            #create client
            my $psconfig_client = new perfSONAR_PS::Client::PSConfig::ApiConnect(
                url => $abs_file
            );
            #process tasks
            $self->_process_tasks($psconfig_client, $task_manager);
        }
        
        ##
        #commit tasks
        $task_manager->commit();
        
        ##
        #Log results
        foreach my $error(@{$task_manager->errors()}){
           $logger->warn($error);
        }
        foreach my $deleted_task(@{$task_manager->deleted_tasks()}){
           $logger->debug("Deleted task " . $deleted_task->uuid . " on server " . $deleted_task->url);
        }
        foreach my $added_task(@{$task_manager->added_tasks()}){
           $logger->debug("Created task " . $added_task->uuid . " on server " . $added_task->url);
        }
        if(@{$task_manager->added_tasks()} || @{$task_manager->deleted_tasks()}){
            $logger->info("Added " . @{$task_manager->added_tasks()} . " new tasks, and deleted " . @{$task_manager->deleted_tasks()} . " old tasks");
        }
    }

}

sub _load_config {
    my ($self, $config_file) = @_;
    
    ##
    #load config file
    my $agent_conf_client = new perfSONAR_PS::PSConfig::PScheduler::ConfigConnect(
        url => $config_file
    );
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

    my @all_addressses = ();
    @all_addressses = @ips;
    push @all_addressses, $hostname if ($hostname);

    foreach my $address (@all_addressses) {
        next if ($ret_addresses{$address});

        $ret_addresses{$address} = 1;

        if ( is_ipv4( $address ) or 
             is_ipv6( $address ) ) {
            my @hostnames = reverse_dns($address);

            push @all_addressses, @hostnames;
        }
        elsif ( is_hostname( $address ) ) {
            my $hostname = $address;

            my @addresses = resolve_address($hostname);

            push @all_addressses, @addresses;
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

sub _process_tasks {
    my ($self, $psconfig_client, $task_manager) = @_;
    
    #get config
    my $psconfig = $psconfig_client->get_config();
    if($psconfig_client->error()){
        print STDERR $psconfig_client->error() . "\n";
        next;
    } 
    print $psconfig->json() . "\n";
    
    #validate
    my @errors = $psconfig->validate();
    if(@errors){
        foreach my $error(@errors){
            print STDERR "Error: " . $error->message . "\n";
            print STDERR "Path: " . $error->path . "\n\n";
        }
        print STDERR "Invalid JSON (pre-expansion)\n";
        next;
    }

    #expand
    $psconfig_client->expand_config($psconfig);
    if($psconfig_client->error()){
        print STDERR $psconfig_client->error() . "\n";
        next;
    }

    #validate
    @errors = $psconfig->validate();
    if(@errors){
        foreach my $error(@errors){
            print STDERR "Error: " . $error->message . "\n";
            print STDERR "Path: " . $error->path . "\n\n";
        }
        print STDERR "Invalid JSON (post-expansion)\n";
        next;
    }

    #walk through tasks
    foreach my $task_name(@{$psconfig->task_names()}){
        print "Task Name: $task_name\n";
        my $tg = new perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator(
            psconfig => $psconfig,
            pscheduler_url => $self->pscheduler_url(),
            task_name => $task_name,
            match_addresses => $self->match_addresses()
        );
        $tg->start() or die($tg->error());
        my @pair;
        while(@pair = $tg->next()){
            my $psc_task = $tg->pscheduler_task();
            unless($psc_task){
                print STDERR "Error converting task to pscheduler: " . $tg->error() . "\n";
                next;
            }
            $task_manager->add_task(task => $psc_task);
        }
        $tg->stop();
    }
}



__PACKAGE__->meta->make_immutable;

1;