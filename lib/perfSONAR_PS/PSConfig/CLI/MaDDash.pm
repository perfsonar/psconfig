package perfSONAR_PS::PSConfig::CLI::MaDDash;


use strict;
use warnings;

use perfSONAR_PS::PSConfig::MaDDash::Checks::ConfigConnect;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::ConfigConnect;

use base 'Exporter';

our @EXPORT_OK = qw( load_maddash_plugins );

sub load_maddash_plugins {
    my($directory, $name, $file) = @_;
    
    my $err = "";
    my $plugin_map = {};
    if($file){
        #if just looking at one file
        my ($plugin, $tmp_err) = load_maddash_plugin_file($name, $file);
        $plugin_map->{$plugin->type()} = $plugin if($plugin);
        $err .= $tmp_err;
    }else{
        unless(opendir(PLUGIN_FILES, $directory)){
            $err .= "Unable to open directory $directory.";
        }
        #walk through directory
        while (my $plugin_file = readdir(PLUGIN_FILES)) {
            next unless($plugin_file =~ /\.json$/);
            my $abs_file = "$directory/$plugin_file";
            my ($plugin, $tmp_err) = load_maddash_plugin_file($name, $abs_file);
            $plugin_map->{$plugin->type()} = $plugin if($plugin);
            $err .= $tmp_err;
        }
    }
    
    return ($plugin_map, $err);
}

sub load_maddash_plugin_file {
    my($name, $abs_file) = @_;
    
    my $err = "";
    my $client;
    #not ideal, but all the rest of code is exactly the same so probably worth it
    if($name eq 'check'){
        $client = new perfSONAR_PS::PSConfig::MaDDash::Checks::ConfigConnect(url => $abs_file);
    }elsif($name eq 'visualization'){
        $client = new perfSONAR_PS::PSConfig::MaDDash::Visualization::ConfigConnect(url => $abs_file);
    }else{
        $err .= "Programming error, unrecognized plugin type. File a bug, this should not happen.\n\n";
        return (undef, $err);
    }
    my $plugin = $client->get_config();
    if($client->error()){
        $err .= "Error reading $name plug-in file: " . $client->error() . "\n\n";
        return (undef, $err);
    } 
    #validate
    my @errors = $plugin->validate();
    if(@errors){
        #print errors here
        $abs_file =~ s/\/\//\//g;
        $err .= "\n$abs_file is not valid. The following errors were encountered: \n";
        foreach my $error(@errors){
            $err .= "    JSON Path: " . $error->path . "\n";
            $err .= "    Error: " . $error->message . "\n";
        }
        return (undef, $err);
    }
    
    return ($plugin, $err);
}

1;