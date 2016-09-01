package perfSONAR_PS::MeshConfig::Agent;

use strict;
use warnings;

our $VERSION = 3.1;

use Config::General;
use File::Basename;
use Log::Log4perl qw(get_logger);
use MIME::Lite;
use Params::Validate qw(:all);
use URI::Split qw(uri_split);
use FreezeThaw qw(freeze thaw);

use perfSONAR_PS::Utils::Host qw(get_ips);
use perfSONAR_PS::Utils::DNS qw(resolve_address reverse_dns);

use Data::Validate::Domain qw(is_hostname);
use Data::Validate::IP qw(is_ipv4);
use Net::IP;

use perfSONAR_PS::MeshConfig::Utils qw(load_mesh);

use perfSONAR_PS::MeshConfig::Config::Mesh;
use perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting;

use perfSONAR_PS::NPToolkit::Services::ServicesMap qw(get_service_object);

use Module::Load;

use Moose;

has 'meshes'                 => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { [] });

has 'tasks_conf'   => (is => 'rw', isa => 'Str', default => "/etc/perfsonar/meshconfig-agent-tasks.conf");
has 'configure_archives'     => (is => 'rw', isa => 'Bool', default=>0);

has 'addresses'              => (is => 'rw', isa => 'ArrayRef[Str]');
has 'requesting_agent'       => (is => 'rw', isa => 'perfSONAR_PS::MeshConfig::Config::Host');
has 'requesting_agent_config' => (is => 'rw', isa => 'HashRef');

has 'send_error_emails'      => (is => 'rw', isa => 'Bool', default => 0);

has 'from_address'           => (is => 'rw', isa => 'Str');
has 'administrator_emails'   => (is => 'rw', isa => 'ArrayRef[Str]');

has 'skip_redundant_tests'   => (is => 'rw', isa => 'Bool', default=>1);

has 'errors'                 => (is => 'rw', isa => 'ArrayRef[HashRef]');
my $logger = get_logger(__PACKAGE__);

sub __build_requesting_agent {
    my $parameters = validate( @_, { requesting_agent_config => 0, addresses => 0 });
    my $requesting_agent_config = $parameters->{requesting_agent_config};
    my $addresses = $parameters->{addresses};

    $requesting_agent_config = {} unless $requesting_agent_config;

    $requesting_agent_config = __map_arrays($requesting_agent_config);

    if ($addresses and scalar(@$addresses) > 0) {
        $requesting_agent_config->{addresses} = $addresses;
    }
    elsif (not $requesting_agent_config->{addresses}) {
        $requesting_agent_config->{addresses} = __get_addresses()
    }

    return perfSONAR_PS::MeshConfig::Config::Host->parse($requesting_agent_config, 1);
}

sub __map_arrays {
    my ($hash, $outer_key) = @_;

    my %array_mapping = (
        'administrator' => { 'value' => 'administrators' }, 
        'address'       => { value => 'addresses', except_in => 'addresses' }, 
        'measurement_archive' => { 'value' => 'measurement_archives' },
        'tag' => { 'value' => 'tags' }
    );

    use Data::Dumper;

    my %ret_hash = ();

    foreach my $key (keys %$hash) {
        my $value = $hash->{$key};

        if ($array_mapping{$key} and 
            (not $array_mapping{$key}->{except_in} or
             (!$outer_key or $array_mapping{$key}->{except_in} ne $outer_key))
           ) {
            $value = [ $value ] unless ref($value) eq "ARRAY";
            $key = $array_mapping{$key}->{value};
        }

        if (ref($value) eq "ARRAY") {
            my @new_values = ();
            foreach my $sub_value (@$value) {
                if (ref($sub_value) eq "HASH") {
                    $sub_value = __map_arrays($sub_value, $key);
                }
                push @new_values, $sub_value;
            }

            $value = \@new_values;
        }

        $ret_hash{$key} = $value;
    }

    return \%ret_hash;
}

sub init {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         meshes => 1,
                                         requesting_agent_config => 0,
                                         validate_certificate => 0,
                                         ca_certificate_file => 0,
                                         ca_certificate_path => 0,
                                         tasks_conf => 0,
                                         configure_archives   => 0,
                                         skip_redundant_tests => 0,
                                         addresses => 0,
                                         from_address => 0,
                                         administrator_emails => 0,
                                         send_error_emails    => 0,
                                      });
    foreach my $key (keys %$parameters) {
        if (defined $parameters->{$key}) {
            $self->$key($parameters->{$key});
        }
    }

    my $requesting_agent = __build_requesting_agent(requesting_agent_config => $self->requesting_agent_config,
                                                    addresses => $self->addresses);

    $self->requesting_agent($requesting_agent) if $requesting_agent;

    return;
}

sub run {
    my ($self) = @_;

    $self->__configure_host();

    $self->__send_error_messages();

    return;
}

sub __send_error_messages {
    my ($self) = @_;

    unless ($self->send_error_emails) {
        $logger->debug("Sending error messages is disabled");
        return;
    }

    if (not $self->errors or scalar(@{ $self->errors }) == 0) {
        $logger->debug("No errors reported");
        return;
    }


    # Build one email for each group of recipients. We may want to do this
    # per-recipient.
    my %emails_by_to = ();
    foreach my $error (@{ $self->errors }) {
        my @to_addresses = $self->__get_administrator_emails({ local => $self->administrator_emails, mesh => $error->{mesh}, host => $error->{host} });
        if (scalar(@to_addresses) == 0) {
            $logger->debug("No email address to send error message to: ".$error->{error_msg});
            next;
        }

        my $full_error_msg = "Mesh Error:\n";
        $full_error_msg .= "  Mesh: ".($error->{mesh}?$error->{mesh}->description:"")."\n";
        $full_error_msg .= "  Host: ".($error->{host}?$error->{host}->addresses->[0]->address:"")."\n";
        $full_error_msg .= "  Error: ".$error->{error_msg}."\n\n";

        my $hash_key = join("|", @to_addresses);

        unless ($emails_by_to{$hash_key}) {
            $emails_by_to{$hash_key} = { to => \@to_addresses, body => "" };
        }

        $emails_by_to{$hash_key}->{body} .= $full_error_msg;
    }

    my $from_address = $self->from_address;
    unless ($from_address) {
        my $hostname = `hostname -f 2> /dev/null`;
        chomp($hostname);
        unless($hostname) {
            $hostname = `hostname 2> /dev/null`;
            chomp($hostname);
        }
        unless($hostname) {
            $hostname = "localhost";
        }

        $from_address = "mesh_agent@".$hostname;
    }
 
    foreach my $email (values %emails_by_to) {
        $logger->debug("Sending email to: ".join(', ', @{ $email->{to} }).": ".$email->{body});
        my $msg = MIME::Lite->new(
                From     => $from_address,
                To       => $email->{to},
                Subject  =>'Mesh Errors',
                Data     => $email->{body},
            );

        unless ($msg->send) {
            $logger->error("Problem sending email to: ".join(', ', @{ $email->{to} }));
        }
    }

    return;
}

sub __get_administrator_emails {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         local => 0,
                                         mesh => 0,
                                         host => 0,
                                      });

    my $local = $parameters->{local};
    my $mesh  = $parameters->{mesh};
    my $host  = $parameters->{host};

    my %addresses = ();

    my $site = $host?$host->parent:undef;
    my $organization = $site?$site->parent:undef;

    foreach my $level ($host, $site, $organization, $mesh) { # i.e. host, site and mesh level administrators
        next unless ($level and $level->administrators);

        foreach my $admin (@{ $level->administrators }) {
            $addresses{$admin->email} = 1;
        }
    }

    if ($local) {
        foreach my $admin (@{ $local }) {
            $addresses{$admin} = 1;
        }
    }

    return keys %addresses;
}

sub __configure_host {
    my ($self) = @_;

    if (scalar(@{ $self->meshes }) == 0) {
        $logger->debug("No meshes defined in the configuration");
    }

    my $generator = perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting->new();
    my ($status, $res) = $generator->init({ config_file => $self->tasks_conf,
                                            skip_duplicates => $self->skip_redundant_tests,
                                            configure_archives => $self->configure_archives });
    if ($status != 0) {
        my $msg = "Problem initializing Tasks configuration: ".$res;
        $logger->error($msg);
        $self->__add_error({ error_msg => $msg });
        return;
    }

    # The $dont_change variable lets us know at the end whether or not we
    # should go through with writing the files, and restarting the daemons. If
    # a user has specified that a mesh must exist, or no updates occur, we
    # don't change anything.
    my $dont_change = 0;

    my @local_addresses = map { $_->address } @{ $self->requesting_agent->addresses };

    foreach my $mesh_params (@{ $self->meshes }) {
        # Grab the mesh from the server
        my ($status, $res) = load_mesh({
                                      configuration_url => $mesh_params->{configuration_url},
                                      validate_certificate => $mesh_params->{validate_certificate},
                                      ca_certificate_file => $mesh_params->{ca_certificate_file},
                                      ca_certificate_path => $mesh_params->{ca_certificate_path},
                                      requesting_agent => $self->requesting_agent
                                   });
        if ($status != 0) {
            if ($mesh_params->{required}) {
                $dont_change = 1;
            }

            my $msg = "Problem with mesh configuration: ".$res;
            $logger->error($msg);
            $self->__add_error({ error_msg => $msg });
            next;
        }

        my $meshes = $res;

        foreach my $mesh (@$meshes) {
            # Make sure that the mesh is valid
            eval {
                $mesh->validate_mesh();
            };
            if ($@) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Invalid mesh configuration: ".$@;
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, error_msg => $msg });
                next;
            }

            if ($mesh->has_unknown_attributes) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Mesh has unknown attributes: ".join(", ", keys %{ $mesh->get_unknown_attributes });
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, error_msg => $msg });
                next;
            }

            # Find the host block associated with this machine
            my $hosts = $mesh->lookup_hosts({ addresses => \@local_addresses });
            my $host_classes = $mesh->lookup_host_classes_by_addresses({ addresses => \@local_addresses });

            unless ($hosts->[0] or $host_classes->[0]) {
                if ($mesh_params->{permit_non_participation}) {
                    my $msg = "This machine is not included in any tests for this mesh: ".join(", ", @local_addresses);
                    $logger->info($msg);
                    next;
                }

                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Can't find any host blocks associated with the addresses on this machine: ".join(", ", @local_addresses);
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, error_msg => $msg });
                next;
            }

            if (scalar(@$hosts) > 1) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Multiple 'host' elements associated with the addresses on this machine: ".join(", ", @local_addresses);
                $logger->warn($msg);
            }

            my %addresses = map { $_ => 1 } @local_addresses;

            # Add any addresses found in host blocks
            foreach my $host (@$hosts) {
                if ($host->has_unknown_attributes) {
                    if ($mesh_params->{required}) {
                        $dont_change = 1;
                    }

                    my $msg = "Host block associated with this machine has unknown attributes: ".join(", ", keys %{ $host->get_unknown_attributes });
                    $logger->error($msg);
                    $self->__add_error({ mesh => $mesh, error_msg => $msg });
                    next;
                }

                foreach my $addr_obj (@{ $host->addresses }) {
                    $addresses{$addr_obj->address} = 1;
                }
            }

            @local_addresses = keys %addresses;

	    # Find the tests that this machine is expected to run with all the
	    # addresses obtained
            my $tests = $mesh->lookup_tests_by_addresses({ addresses => \@local_addresses });
            if (scalar(@$tests) == 0) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "No tests for this host to run: ".join(", ", @local_addresses);
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, host => $hosts->[0], error_msg => $msg });
                next;
            }

            # Add the tests to the various service configurations
            eval {
                $generator->add_mesh_tests({ mesh => $mesh,
                                             tests => $tests,
                                             addresses => \@local_addresses,
                                             local_host => $hosts->[0],
                                             host_classes => $host_classes,
                                             requesting_agent => $self->requesting_agent
                                           });
            };
            if ($@) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Problem adding tasks: $@";
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, host => $hosts->[0], error_msg => $msg });
            }
        }
    }

    if ($dont_change) {
        my $msg = "Problem with required meshes, not changing configuration";
        $logger->error($msg);
        $self->__add_error({ error_msg => $msg });
        return;
    }

    my $config = $generator->get_config();

    $status = $self->__write_file({ file => $self->tasks_conf, contents => $config });

    return;
}

sub __add_error {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         mesh => 0,
                                         host => 0,
                                         error_msg => 1,
                                      });

    my @errors = ();
    @errors = @{ $self->errors } if ($self->errors);

    push @errors, $parameters;

    $self->errors(\@errors);

    return;
}

sub __write_file {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { file => 1, contents => 1 } );
    my $file  = $parameters->{file};
    my $contents = $parameters->{contents};

    unless ($self->__compare_file({ file => $file, contents => $contents })) {
        $logger->debug($file." is unchanged.");
        return;
    }

    $logger->debug("Writing ".$file);

    eval {
        open(FILE, ">".$file) or die("Couldn't open $file");
        print FILE $contents;
        close(FILE);
    };
    if ($@) {
        my $msg = "Problem writing to $file: $@";
        $logger->error($msg);

        foreach my $mesh_params (@{ $self->meshes }) {
            $self->__add_error({ mesh => $mesh_params->{mesh}, host => $mesh_params->{host}, error_msg => $msg });
        }

        return;
    }

    return 1;
}

sub __compare_file {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { file => 1, contents => 1 } );
    my $file  = $parameters->{file};
    my $contents = $parameters->{contents};

    $logger->debug("Checking for changes in ".$file);

    my $differ = 1;

    if (open(FILE, $file)) {
        $logger->debug("Reading ".$file);
        my $file_contents = do { local $/; <FILE> };
        $differ = 0 if ($file_contents eq $contents);
        $logger->debug($file." changed") if ($differ);
        close(FILE);
    }

    return $differ;
}

sub __get_addresses {
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
             &Net::IP::ip_is_ipv6( $address ) ) {
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