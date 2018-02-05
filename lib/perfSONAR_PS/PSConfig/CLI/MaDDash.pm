package perfSONAR_PS::PSConfig::CLI::MaDDash;


use strict;
use warnings;

use perfSONAR_PS::PSConfig::MaDDash::Checks::ConfigConnect;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::ConfigConnect;

use base 'Exporter';

our @EXPORT_OK = qw( load_maddash_plugins );

sub load_maddash_plugins {
    my($directory, $name) = @_;

    my $plugin_map = {};
    unless(opendir(PLUGIN_FILES, $directory)){
        return;
    }
    while (my $plugin_file = readdir(PLUGIN_FILES)) {
        next unless($plugin_file =~ /\.json$/);
        my $abs_file = "$directory/$plugin_file";
        my $client;
        #not ideal, but all the rest of code is exactly the same so probably worth it
        if($name eq 'check'){
            $client = new perfSONAR_PS::PSConfig::MaDDash::Checks::ConfigConnect(url => $abs_file);
        }elsif($name eq 'visualization'){
            $client = new perfSONAR_PS::PSConfig::MaDDash::Visualization::ConfigConnect(url => $abs_file);
        }else{
            next;
        }
        my $plugin = $client->get_config();
        if($client->error()){
            next;
        } 
        #validate
        my @errors = $plugin->validate();
        if(@errors){
            next;
        }
        $plugin_map->{$plugin->type()} = $plugin;
    }

    return $plugin_map;
}

1;