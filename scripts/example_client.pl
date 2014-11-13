#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($RealBin);

use lib "$RealBin/../lib";

use Log::Log4perl qw(:easy);
use perfSONAR_PS::MeshConfig::Utils qw(load_mesh);

Log::Log4perl->easy_init($DEBUG);

my $url = shift;

unless ($url) {
    print "No configuration url specified\n";
    print "Usage: $0 [configuration url]\n";
    exit -1;
}

my ($status, $res) = load_mesh({ configuration_url => $url });

die($res) if ($status != 0);

# Grab the first mesh if there are multiple at a given URL
my $mesh = $res->[0];

$mesh->validate_mesh();

my %ma_urls = ();

foreach my $test (@{ $mesh->tests }) {
    my $pairs = $test->members->source_destination_pairs;
    foreach my $pair (@$pairs) {
        # Skip tests that can't occur
        next if ($pair->{source}->{no_agent} and $pair->{destination}->{no_agent});

        # PingER is a special case...
        next if ($test->parameters->type eq "pinger" and $pair->{source}->{no_agent});

        my $tester_addr = $pair->{source}->{no_agent}?$pair->{destination}->{address}:$pair->{source}->{address};

        my $hosts = $mesh->lookup_hosts({ addresses => [ $tester_addr ] });

        my $host  = $hosts->[0];

        my $ma    = $host->lookup_measurement_archive({ type => $test->parameters->type, recursive => 1 });
        unless ($ma) {
            print "No MA for ".$test->parameters->type.": ".$pair->{source}->{address}." -> ".$pair->{destination}->{address}."\n";
            next;
        }

        $ma_urls{$ma->read_url} = [] unless $ma_urls{$ma->read_url};
        push @{ $ma_urls{$ma->read_url} }, { type => $test->parameters->type, source => $pair->{source}->{address}, destination => $pair->{destination}->{address} };
    }
}

foreach my $ma (keys %ma_urls) {
    print "Measurement Archive: ".$ma."\n";
    foreach my $test (@{ $ma_urls{$ma} }) {
        print " - ".$test->{type}.": ".$test->{source}." -> ".$test->{destination}."\n";
    }
    print "\n";
}
