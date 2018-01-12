package perfSONAR_PS::PSConfig::PScheduler::Agent;

=head1 NAME

perfSONAR_PS::Client::PSConfig::PScheduler::Agent - Agent that loads config, grabs meshes and submits to pscheduler

=head1 DESCRIPTION

Agent that loads config, grabs meshes and submits to pscheduler

=cut

use Mouse;

use Data::Dumper;
use Data::Validate::Domain qw(is_hostname);
use Data::Validate::IP qw(is_ipv4 is_ipv6 is_loopback_ipv4);
use Net::CIDR qw(cidrlookup);
use File::Basename;
use Log::Log4perl qw(get_logger);
use URI;

use perfSONAR_PS::Client::PScheduler::TaskManager;
use perfSONAR_PS::Client::PScheduler::Task;
use perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator;
use perfSONAR_PS::PSConfig::ArchiveConnect;
use perfSONAR_PS::Utils::Logging;
use perfSONAR_PS::PSConfig::PScheduler::ConfigConnect;
use perfSONAR_PS::PSConfig::PScheduler::Config;
use perfSONAR_PS::Utils::DNS qw(resolve_address reverse_dns);
use perfSONAR_PS::Utils::Host qw(get_ips);
use perfSONAR_PS::Utils::ISO8601 qw/duration_to_seconds/;

extends 'perfSONAR_PS::PSConfig::BaseAgent';

our $VERSION = 4.1;

has 'pscheduler_fails' => (is => 'rw', isa => 'Int', default => sub { 0 });
has 'max_pscheduler_attempts' => (is => 'rw', isa => 'Int', default => sub { 5 });
has 'task_min_ttl_seconds' => (is => 'rw', isa => 'Int', default => sub { 86400 });
has 'task_manager' => (is => 'rw', isa => 'perfSONAR_PS::Client::PScheduler::TaskManager|Undef');

my $logger = get_logger(__PACKAGE__);
my $task_logger = get_logger('TaskLogger');
my $transaction_logger = get_logger('TransactionLogger');

sub _agent_name {
    return "pscheduler";
}

sub _config_client {
    return new perfSONAR_PS::PSConfig::PScheduler::ConfigConnect();
}

sub _init {
    my ($self, $agent_conf) = @_;

    ##
    # pscheduler_fail_attempts goes in max_pscheduler_attempts if set
    if(defined $agent_conf->pscheduler_fail_attempts()) {
        $self->max_pscheduler_attempts($agent_conf->pscheduler_fail_attempts());
    }
}

sub _run_start {
    my($self, $agent_conf) = @_;
    
    ##
    # Set defaults for config values
    unless($agent_conf->client_uuid_file()){
        my $default = "/var/lib/perfsonar/psconfig/client_uuid";
        $logger->debug($self->logf()->format("No client-uuid-file specified. Defaulting to $default"));
        $agent_conf->client_uuid_file($default);
    }
    
    unless($agent_conf->pscheduler_tracker_file()){
        my $default = "/var/lib/perfsonar/psconfig/psc_tracker";
        $logger->debug($self->logf()->format("No pscheduler-tracker-file specified. Defaulting to $default"));
        $agent_conf->pscheduler_tracker_file($default);
    }
    
    my $task_min_ttl_seconds = 86400;
    if($agent_conf->task_min_ttl()) {
        my $task_min_ttl;
        eval{ $task_min_ttl = duration_to_seconds($agent_conf->task_min_ttl()) };
        if($@){
            $logger->error($self->logf()->format("Error parsing task-min-ttl. Defaulting to " . $self->task_min_ttl() . " seconds: $@"));
        }elsif(!$task_min_ttl){
            $logger->error($self->logf()->format("task_min_ttl has no value, sticking with default ". $self->task_min_ttl() . " seconds"));
        }else{
            $task_min_ttl_seconds = $task_min_ttl;
        }
        $logger->debug($self->logf()->format("task_min_ttl is $task_min_ttl_seconds seconds"));
    }
    $self->task_min_ttl_seconds($task_min_ttl_seconds);
    
    unless ($agent_conf->task_min_runs()) {
        my $default = 2;
        $logger->debug($self->logf()->format( "No task-min-runs specified. Defaulting to $default" ));
        $agent_conf->task_min_runs($default);
    }
    
    unless ($agent_conf->task_renewal_fudge_factor()) {
        my $default = .25;
        $logger->debug($self->logf()->format( "No task-renewal-fudge-factor specified. Defaulting to $default" ));
        $agent_conf->task_renewal_fudge_factor($default);
    }

    ##
    # Set defaults for pscheduler binding addresses
    unless($agent_conf->pscheduler_bind_map()){
        $agent_conf->pscheduler_bind_map({});
    }
    
    ##
    #Init the TaskManager
    my $old_task_deadline = time + $self->check_interval_seconds();
    my $task_manager;        
    eval{
        $task_manager = new perfSONAR_PS::Client::PScheduler::TaskManager(logger => $transaction_logger);
        $task_manager->logf()->guid($self->logf()->guid()); # make logging guids consistent
        $task_manager->init(
                            pscheduler_url => $self->pscheduler_url(),
                            tracker_file => $agent_conf->pscheduler_tracker_file(),
                            client_uuid_file => $agent_conf->client_uuid_file(),
                            reference_label => "psconfig",
                            user_agent => "psconfig-pscheduler-agent",
                            new_task_min_ttl => $self->task_min_ttl_seconds(),
                            new_task_min_runs => $agent_conf->task_min_runs(),
                            old_task_deadline => $old_task_deadline,
                            task_renewal_fudge_factor => $agent_conf->task_renewal_fudge_factor(),
                            bind_map => $agent_conf->pscheduler_bind_map(),
                            lead_address_map => {},#\%pscheduler_addr_map,
                            debug => $self->debug()
                        );
    };
    if($@){
        $logger->error($self->logf()->format("Problem initializing task_manager: $@"));
        return;
    }elsif(!$task_manager->check_assist_server()){
        $logger->error($self->logf()->format("Problem contacting pScheduler, will try again later."));
        $self->pscheduler_fails($self->pscheduler_fails() + 1);
        return;
    }
    $logger->info($self->logf()->format("pScheduler is back up, resuming normal operation")) if($self->pscheduler_fails());
    $self->pscheduler_fails(0);
    $self->task_manager($task_manager);
    
    return 1;
}

sub _run_handle_psconfig {
    my($self, $psconfig, $agent_conf, $remote) = @_;
    
    #Init variables
    my $configure_archives = 0; #make sure defined
    if($remote && $remote->configure_archives()){
        $configure_archives = 1;
    }
    
    #walk through tasks
    foreach my $task_name(@{$psconfig->task_names()}){
        $self->logf->global_context()->{'task_name'} = $task_name;
        my $tg = new perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator(
            psconfig => $psconfig,
            pscheduler_url => $self->pscheduler_url(),
            task_name => $task_name,
            match_addresses => $self->match_addresses(),
            default_archives => $self->default_archives(),
            use_psconfig_archives => $configure_archives,
            bind_map => $agent_conf->pscheduler_bind_map()
        );
        unless($tg->start()){
             $logger->error($self->logf()->format("Error initializing task iterator: " . $tg->error()));
             return;
        }
        my @pair;
        while(@pair = $tg->next()){
            #check for errors expanding task
            if($tg->error()){
                $logger->error($tg->error());
                next;
            }
            #build pscheduler
            my $psc_task = $tg->pscheduler_task();
            unless($psc_task){
                $logger->error($self->logf()->format("Error converting task to pscheduler: " . $tg->error()));
                next;
            }
            $self->task_manager()->add_task(task => $psc_task);
            #log task to task log. Do here because even if was not added, want record that
            # it is a task that this host manages
            $task_logger->info($self->logf()->format_task($psc_task));
        }
        $tg->stop();
    }
    $logger->debug($self->logf()->format('Successfully processed task.'));
}

sub _run_end {
    my($self, $agent_conf) = @_;
    my $task_manager = $self->task_manager();
    
    ##
    #commit tasks
    $task_manager->commit();
    
    ##
    #Log results
    foreach my $error(@{$task_manager->errors()}){
       $logger->warn($self->logf()->format($error));
    }
    foreach my $deleted_task(@{$task_manager->deleted_tasks()}){
       $logger->debug($self->logf()->format("Deleted task " . $deleted_task->uuid . " on server " . $deleted_task->url));
    }
    foreach my $added_task(@{$task_manager->added_tasks()}){
       $logger->debug($self->logf()->format("Created task " . $added_task->uuid . " on server " . $added_task->url));
    }
    if(@{$task_manager->added_tasks()} || @{$task_manager->deleted_tasks()}){
        $logger->info($self->logf()->format("Added " . @{$task_manager->added_tasks()} . " new tasks, and deleted " . @{$task_manager->deleted_tasks()} . " old tasks"));
    }
}

sub will_retry_pscheduler {
    my ($self) = @_;
    
    if($self->pscheduler_fails() > 0 && $self->pscheduler_fails() < $self->max_pscheduler_attempts()){
        return 1;
    }
    return 0;
}


__PACKAGE__->meta->make_immutable;

1;