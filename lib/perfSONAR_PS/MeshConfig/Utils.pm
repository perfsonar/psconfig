package perfSONAR_PS::MeshConfig::Utils;

use strict;
use warnings;

our $VERSION = 3.1;

use JSON;
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use URI::Split qw(uri_split);

use perfSONAR_PS::Client::Utils qw(send_http_request build_err_msg);

use perfSONAR_PS::MeshConfig::Config::Mesh;

use File::Temp qw(tempfile);

use base 'Exporter';

our @EXPORT_OK = qw( load_mesh build_json);

my $logger = get_logger(__PACKAGE__);

sub load_mesh {
    my $parameters = validate( @_, { 
                                     configuration_url => 1,
                                     validate_certificate => 0,
                                     ca_certificate_file => 0,
                                     ca_certificate_path => 0,
                                     relaxed_checking    => 0,
                                     requesting_agent    => 0,
                                   });
    my $configuration_url      = $parameters->{configuration_url};
    my $validate_certificate   = $parameters->{validate_certificate};
    my $ca_certificate_file    = $parameters->{ca_certificate_file};
    my $ca_certificate_path    = $parameters->{ca_certificate_path};
    my $relaxed_checking       = $parameters->{relaxed_checking};
    my $requesting_agent       = $parameters->{requesting_agent};

    my ($status, $res);

    ($status, $res) = __load_json({ url                  => $configuration_url,
                                    validate_certificate => $validate_certificate,
                                    ca_certificate_file  => $ca_certificate_file,
                                    ca_certificate_path  => $ca_certificate_path,
                                 });

    unless ($status == 0) {
        return ($status, $res);
    }

    my $json = $res;

    $json = [ $json ] if (ref($json) ne "ARRAY");

    my @meshes = ();

    foreach my $mesh_hash (@$json) {
        # parse any "include" attributes
        ($status, $res) = __process_include_directives({ 
                                                         hash                 => $mesh_hash,
                                                         validate_certificate => $validate_certificate,
                                                         ca_certificate_file  => $ca_certificate_file,
                                                         ca_certificate_path  => $ca_certificate_path,
                                                      });
        unless ($status == 0) {
            return ($status, $res);
        }


        my $config;
        eval {
            my $strict = ($relaxed_checking?0:1);

            $config = perfSONAR_PS::MeshConfig::Config::Mesh->parse($mesh_hash, $strict, $requesting_agent);
        };
        if ($@) {
            my $msg = "Invalid mesh configuration: ".$@;
            $logger->error($msg);
            return (-1, $msg);
        }

        push @meshes, $config;
    }

    return (0, \@meshes);
}

sub __process_include_directives {
    my $parameters = validate( @_, { 
                                     hash                 => 1,
                                     validate_certificate => 0,
                                     ca_certificate_file  => 0,
                                     ca_certificate_path  => 0,
                                   });

    my $hash                   = $parameters->{hash};
    my $validate_certificate   = $parameters->{validate_certificate};
    my $ca_certificate_file    = $parameters->{ca_certificate_file};
    my $ca_certificate_path    = $parameters->{ca_certificate_path};

    if ($hash->{include}) {
        foreach my $url (@{ $hash->{include} }) {
            $logger->debug("Loading $url");
            my ($status, $res) = __load_json({ url                  => $url,
                                               validate_certificate => $validate_certificate,
                                               ca_certificate_file  => $ca_certificate_file,
                                               ca_certificate_path  => $ca_certificate_path,
                                            });

            unless ($status == 0) {
                return ($status, $res);
            }

            my $json = $res;

            ($status, $res) = __merge_hash(hash => $hash, new_hash => $json);
        }

        delete($hash->{include});
    }

    foreach my $key (keys %{ $hash }) {
        if (ref($hash->{$key}) eq "ARRAY") {
            foreach my $element (@{ $hash->{$key} }) {
                if (ref($element) eq "HASH") {
                    my ($status, $res) = __process_include_directives({ hash                 => $element,
                                                                        validate_certificate => $validate_certificate,
                                                                        ca_certificate_file  => $ca_certificate_file,
                                                                        ca_certificate_path  => $ca_certificate_path,
                                                                     });
                    unless ($status == 0) {
                        return ($status, $res);
                    }
                }
            }
        }
        elsif (ref($hash->{$key}) eq "HASH") {
            my ($status, $res) = __process_include_directives({ hash                 => $hash->{$key},
                                                                validate_certificate => $validate_certificate,
                                                                ca_certificate_file  => $ca_certificate_file,
                                                                ca_certificate_path  => $ca_certificate_path,
                                                             });
            unless ($status == 0) {
                return ($status, $res);
            }
        }
    }

    return (0, "");
}

sub __merge_hash {
    my $parameters = validate( @_, { 
                                     hash     => 1,
                                     new_hash => 1,
                                   });
    my $hash     = $parameters->{hash};
    my $new_hash = $parameters->{new_hash};

    foreach my $key (keys %{ $new_hash }) {
        unless ($hash->{$key}) {
            $hash->{$key} = $new_hash->{$key};
            next;
        }

        if (ref($hash->{$key}) ne ref($hash->{$key})) {
            my $msg = "Problem merging '$key' elements";
            $logger->error($msg);
            return (-1, $msg);
        }

        if (ref($hash->{$key}) eq "ARRAY") {
            $logger->debug("Appending $key array");
            push @{ $hash->{$key} }, @{ $new_hash->{$key} };
        }
        elsif (ref($hash->{$key}) eq "HASH") {
            $logger->debug("Merging $key hashes");
            my ($status, $res) = __merge_hash($hash->{$key}, $new_hash->{$key});
            unless ($status == 0) {
                return ($status, $res);
            }
        }
        else {
            $logger->debug("Using $key value from original hash");
        }
    }

    return (0, "");
}

sub __load_json {
    my $parameters = validate( @_, { 
                                     url                  => 1,
                                     validate_certificate => 0,
                                     ca_certificate_file  => 0,
                                     ca_certificate_path  => 0,
                                   });
    my $url                    = $parameters->{url};
    my $validate_certificate   = $parameters->{validate_certificate};
    my $ca_certificate_file    = $parameters->{ca_certificate_file};
    my $ca_certificate_path    = $parameters->{ca_certificate_path};

    my $uri = URI->new($url);
    my $json_text = '';
    if ($uri->scheme eq "file") {
        eval {
            open(FILE, $uri->path) or die("Couldn't open ".$uri->path);
            while(<FILE>) { 
                $json_text .= $_;
            }
            close(FILE);
        };
        if ($@) {
            return (-1, $@);
        }
    }
    else { 
        my $res = send_http_request({ 
                                  connection_type     => 'GET',
                                  timeout             => 60,
                                  url                 => $url,
                                  verify_hostname     => $validate_certificate,
                                  ca_certificate_file => $ca_certificate_file,
                                  ca_certificate_path => $ca_certificate_path,
                                });
        if(!$res->is_success){
            my $msg = build_err_msg(http_response => $res);
            $logger->debug("Problem retrieving mesh configuration from $url: ".$msg);
            return (-1, $msg);
        }
        $json_text = $res->content;
    }
    my $json;
    eval {
        $json = JSON->new->decode($json_text);
    };
    if ($@) {
        my $msg = "Problem parsing json for $url: ".$@;
        $logger->error($msg);
        return (-1, $msg);
    }

    return (0, $json);
}

sub build_json {
    my $parameters = validate( @_, { 
                                     configuration        => 1,
                                     skip_validation      => 1,
                                     resolve_includes     => 1,
                                   });
    
    my $configuration = $parameters->{configuration};
    my $skip_validation = $parameters->{skip_validation};
    my $resolve_includes = $parameters->{resolve_includes};
                  
    # Parse everything except the 'test', 'group' and 'test_spec' elements.
    my $json_configuration = __parse_hash($configuration, [ "test", "group", "test_spec" ]);

    # Go through and parse all the test specs, keeping track of their id.
    my %test_specs = ();
    foreach my $test_spec_id (keys %{ $configuration->{"test_spec"} }) {
        my $desc = $configuration->{"test_spec"}->{$test_spec_id};
        
        $test_specs{$test_spec_id} = __parse_hash($desc, [], "test_spec");
    }

    # Go through and parse all the groups, keeping track of their id.
    my %groups = ();
    foreach my $group_id (keys %{ $configuration->{"group"} }) {
        my $desc = $configuration->{"group"}->{$group_id};
        
        $groups{$group_id} = __parse_hash($desc, [], "group");
    }

    if ($configuration->{"test"}) {
        my @tests = ();

        $configuration->{"test"} = [] unless $configuration->{"test"};

        if (ref($configuration->{"test"}) ne "ARRAY") {
            $configuration->{"test"} = [ $configuration->{"test"} ];
        }

        # Parse all the tests, and merge their group and test_spec so that the test is
        # of the appropriate json format.
        foreach my $test (@{ $configuration->{"test"} }) {
        
            $test = __parse_hash($test, [], "test");
            my $group = $test->{group};
            my $test_spec = $test->{test_spec};

            delete($test->{group});
            delete($test->{test_spec});

            unless ($test_specs{$test_spec}) {
               die("missing test spec: ".$test_spec);
            }

            unless ($groups{$group}) {
               die("missing group: ".$group);
            }

            my %test_spec = %{ $test_specs{$test_spec} };
            my %group = %{ $groups{$group} };

        # Fill in any parameters that override parameters from the test spec
            if ($test->{parameters}) {
                for my $param (keys %{ $test->{parameters} }) {
                    $test_spec{$param} = $test->{parameters}->{$param};
                }
            }

            $test->{parameters} = \%test_spec;
            $test->{members}    = \%group;

            # In the .json, no_agents are specified at the group level.
            if ($test->{no_agents}) {
                $test->{members}->{no_agents} = $test->{no_agents};
                delete($test->{no_agents});
            }

            push @tests, $test;
        }

        $json_configuration->{tests} = \@tests;
    }

    # Normalize the host class 'match' and 'exclude' blocks.
    # 
    # Instead of:
    #    <match>
    #       <filter>...</filter>
    #       <filter>...</filter>
    #       <filter>...</filter>
    #    </match>
    #
    # These are just an array of 'filter' objects named 'match_filters' or
    # 'exclude_filters'.
    if ($json_configuration->{"host_classes"}) {
        foreach my $host_class (@{ $json_configuration->{"host_classes"} }) {
            foreach my $type ("match", "exclude") {
                next unless ($host_class->{$type});

                my $filters = $host_class->{$type}->{filters};

                delete($host_class->{$type});

                next unless $filters;

                $host_class->{$type."_filters"} = $filters;
            }
        }
    }


    # Validate the mesh by outputing a temporary file, and loading the mesh as
    # normal.
    if ($resolve_includes or not $skip_validation) {
        my ($fh, $tmp_json) = tempfile();
        
        print { $fh } JSON->new->pretty(1)->encode($json_configuration);

        close $fh;

        my ($status, $res) = load_mesh({ configuration_url => "file://".$tmp_json });

        unlink($tmp_json);

        my $meshes = $res;

        unless ($skip_validation) {
            if ($status == 0) {
                eval {
                    # Parse the resulting hash to  make sure it's correct. We use strict checking
                    foreach my $mesh (@$meshes) {
                        # Parse the resulting hash to  make sure it's correct. We use strict checking
                        $mesh->validate_mesh();
                    }
                };
                if ($@) {
                    $status = -1;
                    $res    = $@;
                }
            }

            unless ($status == 0) {
                return (-1, "Resulting mesh is invalid: $res\n");
            }
        }

        if ($resolve_includes) {
            unless ($status == 0) {
                return (-1, "Problem resolving includes: $res\n");
            }

            my $json_configuration;

            if (length($meshes) == 1) {
                my @unparsed_meshes = ();
                foreach my $mesh (@$meshes) {
                    push @unparsed_meshes, $mesh->unparse();
                }

                $json_configuration = \@unparsed_meshes;
            }
            else {
                $json_configuration = $res->unparse();
            }
        }
    }
    
    return (0, $json_configuration);
}


# Go through the hash, and convert any 'array' variables into an array, and
# rename their 'key'.
sub __parse_hash {
    my ($hash, $skip, $in_key) = @_;
    
    # We maintain a mapping of the array variables to their 'real' name so we know
    # what to rename them to.
    my %array_variables = (
                        "include"       => { },
                        "administrator" => { new_key => "administrators" },
                        "test" => { new_key => "tests" },
                        "reference" => { new_key => "references" },
                        "measurement_archive" => { new_key => "measurement_archives" },
                        "address" => { new_key => "addresses", except => [ "address", "addresses" ] },
                        "tag" => { new_key => "tags", except => [ "filter", "filters" ] },
                        "map" => { new_key => "maps" },
                        "bind_map" => { new_key => "bind_maps" },
                        "field" => { new_key => "fields" },
                        "member" => { new_key => "members" },
                        "a_member" => { new_key => "a_members" },
                        "b_member" => { new_key => "b_members" },
                        "site" => { new_key => "sites" },
                        "organization" => { new_key => "organizations" },
                        "host" => { new_key => "hosts" },
                        "no_agent" => { except => [ "hosts" ], new_key => "no_agents" },
                        "filter" => { new_key => "filters" },
                        "data_source" => { new_key => "data_sources" },
						"time_slot" => { new_key => "time_slots" },
                        "host_class" => { new_key => "host_classes", except => [ "filter", "filters" ] },
                    );


    $in_key = "" unless $in_key;

    my %skip_map = map { $_ => 1 } @$skip;

    my %new_hash = ();

    foreach my $key  (keys %$hash) {
        my $value = $hash->{$key};

        next if ($skip_map{$key});

        if ($array_variables{$key}) {
            my $skip;
            if ($array_variables{$key}->{except}) {
                foreach my $except (@{ $array_variables{$key}->{except} }) {
                    $skip = 1 if ($except eq $in_key);
                }
            }

            unless ($skip) {
                if ($array_variables{$key}->{new_key}) {
                    $key = $array_variables{$key}->{new_key};
                }

                $value = [ $value ] unless (ref($value) eq "ARRAY");
            }
        }

        if (ref($value) eq "ARRAY") {
            my @new_value = ();

            foreach my $element (@$value) {
                if (ref($element) eq "HASH") {
                    push @new_value, __parse_hash($element, [], $key);
                }
                else {
                    push @new_value, $element;
                }
            }

            $value = \@new_value;
        }
        elsif (ref($value) eq "HASH") {
            $value = __parse_hash($value, [], $key);
        }

        $new_hash{$key} = $value;
    }

    return \%new_hash;
}

1;
