use strict;
use warnings;

our $VERSION = 4.1;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;
use Data::Dumper;
use Symbol 'gensym';
use IPC::Open3;
use Params::Validate;

#####
# Subroutine for running commands
sub assert_cmd {
    my $parameters = validate(  @_, { 
        args => 0,
        expected_status => 0,
        expected_stdout => 0,
        expected_stderr => 0,
     });
    my $args = $parameters->{args};
    my $expected_status = $parameters->{expected_status};
    my $expected_stdout = $parameters->{expected_stdout};
    my $expected_stderr = $parameters->{expected_stderr};
    
    my @cmd = ("$Bin/../bin/psconfig", "validate", "--skip-pscheduler");
    push @cmd, @{$args} if($args);
    
    #run command
    my $status = -1;
    my($stdin, $stdout, $stderr);
    eval{
        $stderr = gensym;
        my $pid = open3($stdin, $stdout, $stderr, @cmd);
        waitpid( $pid, 0 );
        $status = $? >> 8;
    };
    if($@){
        my $cmd_string = join ' ', @cmd;
        $status = -1;
        diag "Error running $cmd_string: " . $@;
    }
    
    if(defined $expected_status){
        is($status, $expected_status);
    }
    
    if(defined $expected_stdout){
        my $stdout_str = do { local $/; <$stdout> };
        is($stdout_str, $expected_stdout);
    }
    
    if(defined $expected_stderr){
        my $stderr_str = do { local $/; <$stderr> };
        is($stderr_str, $expected_stderr);
    }
}

######
# Some basic unit tests to check return status of command
#
my $input_dir = "$Bin/inputs";
my $valid_json_file = "$input_dir/valid.json";
my $invalid_json_file = "$input_dir/invalid.json";
my $valid_includes_json_file = "$input_dir/valid.json";
my $invalid_includes_json_file = "$input_dir/valid.json";

assert_cmd(args => [$valid_json_file], expected_status => 0);
assert_cmd(args => [$invalid_json_file], expected_status => 1);

########
#finish testing
########
done_testing();
