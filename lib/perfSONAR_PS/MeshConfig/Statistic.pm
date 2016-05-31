package perfSONAR_PS::MeshConfig::Statistic;

use strict;
use warnings;

our $VERSION = 0.1;

use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use Data::Dumper qw(Dumper);
use Text::TabularDisplay;

use perfSONAR_PS::MeshConfig::Utils qw(load_mesh);

use Moose;

=head1 NAME

	perfSONAR_PS::MeshConfig::Statistic;

=head1 DESCRIPTION

	Creates  statistic information from the mesh config json file. It supports as output string or json.

=head1 API

=head1 TODO
	* Why my $addr_obj = $members->lookup_address(address => $member) returns a undefined addr_obj?
	* Implement as json
	* Implement BWCTL tests percentage of time tests
	

=cut

has 'statistics_tree' => (is => 'rw', isa => 'HashRef');
has 'meshes'        => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::Mesh]', default => sub { [] });

my $logger = get_logger(__PACKAGE__);
my $local_inits = "local_initiations";
my $remote_inits = "remote_initiations";

sub init {
	my ($self, @args) = @_;
    my $parameters = validate( @args, {
    	configuration_file => 1,
    });
    
    $logger->info("Starting statistic report.");
    my ($status, $res) = load_mesh({ configuration_url => "file://".$parameters->{configuration_file} });
    if ($status != 0) {
    	my $msg = "Problem with mesh configuration: ".$res;
		$logger->error($msg);
    }
    
	$self->meshes($res);
}

sub build_statistics{
	my $self = shift;
	my $meshes = $self->meshes;
	my %statistics_tree = ();
		
	foreach my $mesh (@$meshes) {
		$self->__check_mesh($mesh);
		
		foreach my $test (@{ $mesh->tests }) {
			my $force_bidirectional = 1;
			
			if ($test->disabled) {
				$logger->debug("Skipping disabled test: ".$test->description);
            	next;
			}
			
			if ($test->parameters->can("force_bidirectional") and $test->parameters->force_bidirectional){
				$logger->debug("Test with force_bidirectional");
				$force_bidirectional = 2;
			}
			
			my $tool = $test->parameters->type;
			my %initiations = %{$self->__get_test_initiations($test->members)};
			
			foreach my $address ( keys %initiations) {
				
				if ( $statistics_tree{$address}{$tool}{$local_inits} >= 0)	{
					#add initiations to current initiations
					$statistics_tree{$address}{$tool}{$local_inits} += ( $initiations{$address}{$local_inits} * $force_bidirectional);
					$statistics_tree{$address}{$tool}{$remote_inits} += ( $initiations{$address}{$remote_inits} * $force_bidirectional);					
				} else {
					$statistics_tree{$address}{$tool}{$local_inits} = ( $initiations{$address}{$local_inits} * $force_bidirectional);
					$statistics_tree{$address}{$tool}{$remote_inits} = ( $initiations{$address}{$local_inits} * $force_bidirectional);
				}			
			}
			
		}	
	}
	$self->statistics_tree(\%statistics_tree);
}

#TODO: Export statistics as JSON for other applications.
sub as_json {
	
}

sub as_string {
	my ($self) = @_;
	my $tool_bwctl = "perfsonarbuoy/bwctl";
	my $tool_owamp = "perfsonarbuoy/owamp";
	my $tool_traceroute = "traceroute";
	my %statistics_tree = %{$self->statistics_tree};
	
	my $table = Text::TabularDisplay->new(qw(address, perfsonarbuoy/bwctl perfsonarbuoy/owamp traceroute));
	
	foreach my $address ( keys %statistics_tree ){
		my $col_source = "";
		my $col_interface = "";
		my $col_bwctl = "";
		my $col_owamp = "";
		my $col_traceroute = "";
						
		my ( $num_bwctl, $num_owamp, $num_traceroute) = 0;
		my ( $num_bwctl_remote, $num_owamp_remote, $num_traceroute_remote) = 0;
		
		$num_bwctl = $statistics_tree{$address}{$tool_bwctl}{$local_inits};
		$num_bwctl_remote = $statistics_tree{$address}{$tool_bwctl}{$remote_inits};
		my $total_bwctl = $num_bwctl + $num_bwctl_remote;
		
		$num_owamp = $statistics_tree{$address}{$tool_owamp}{$local_inits};
		$num_owamp_remote = $statistics_tree{$address}{$tool_owamp}{$remote_inits};
		my $total_owamp = $num_owamp + $num_owamp_remote;
		
		$num_traceroute = $statistics_tree{$address}{$tool_traceroute}{$local_inits};
		$num_traceroute_remote = $statistics_tree{$address}{$tool_traceroute}{$remote_inits};
		my $total_traceroute = $num_traceroute + $num_traceroute_remote;
		
		$col_interface = $address;
		$col_bwctl = $num_bwctl . " " . $num_bwctl_remote . " " . $total_bwctl;
		$col_owamp = $num_owamp . " " . $num_owamp_remote . " " . $total_owamp;
		$col_traceroute = $num_traceroute ." " . $num_traceroute_remote . " " . $total_traceroute;
			
		
		$table->add($col_interface, $col_bwctl, $col_owamp, $col_traceroute);
	}
	
	return $table->render();
}

sub __check_mesh{
	my ($self, $mesh) = @_;
	eval {
		$mesh->validate_mesh();
	};
	if ($@) {
		my $msg = "Invalid mesh configuration: ".$@;
		$logger->error($msg);
	}
	if ($mesh->has_unknown_attributes) {
		my $msg = "Mesh has unknown attributes: ".join(", ", keys %{ $mesh->get_unknown_attributes });
		$logger->error($msg);
	}
}

sub __get_test_initiations {
	my ($self, $members) = @_;
	my $group_type = $members->type;
		
	if ($group_type eq "mesh"){
		$self->__get_test_initiations_mesh($members);
	}
	elsif ($group_type eq "star"
	or $group_type eq "disjoint"){
		$self->__get_test_initiations_disjoint($members);
	}
	elsif ($group_type eq "ordered_mesh") {
		$self->__get_test_initiations_ordered_mesh($members);
	}else{
		die("Unknown group type " . $group_type);
	}
	
}

=head2 __get_test_initiations_mesh(members)
	This method counts the test initiations for a mesh group. Every member initiates a tests 
	with other members. When a  member is defined as no_agent then the local_initiations is 
	set to 0. It teturns a hash with the addresses as a key and local_initiations or 
	remote_initiations as value.
=cut
sub __get_test_initiations_mesh {
	my ($self, $members) = @_;
	my %initiations = ();
	my @members_has_agent = @{$self->get_members_with_agent($members->members, $members)};
	
	foreach my $member (@{$members->members}) {
		my $addr_obj = $members->lookup_address(address => $member);
		if ( defined $addr_obj and $addr_obj->parent->no_agent) {
			#no agent do not initiate locally
			$initiations{$member}{$local_inits} = 0;			
		}else {
			#initiate to all members
			$initiations{$member}{$local_inits} = scalar(@{$members->members}) - 1;
		}
		$initiations{$member}{$remote_inits} = scalar(@members_has_agent);		
	}
	return \%initiations;	
}

=head2 __get_test_initiations_disjoint(members)
	Calculate the initiations  of tests for a disjoint group. A star group is a special cae of 
	disjoint group definition. Where the center address is an single a_member and the other members
	are b_members. It returns a hash with the addresses as a key and local_initiations or 
	remote_initiations as values. 
=cut
sub __get_test_initiations_disjoint {
	my ($self, $members) = @_;
	my %initiations = ();
	my @a_members = @{$members->a_members};
	my @members_has_agent = ();
	my @b_members = @{$members->b_members};
	
	# a_members as local inits
	@members_has_agent = @{$self->get_members_with_agent(\@b_members, $members)};	
	foreach my $member (@a_members) {
		my $addr_obj = $members->lookup_address(address => $member);
		if ( defined $addr_obj and $addr_obj->parent->no_agent) {
			#no agent do not initiate locally
			$initiations{$member}{$local_inits} = 0;			
		}else {
			$initiations{$member}{$local_inits} = scalar(@b_members);
		}
		# remote initiations
		$initiations{$member}{$remote_inits} = scalar(@members_has_agent);		
	}
	
	#And for b_members
	@members_has_agent = @{$self->get_members_with_agent(\@a_members, $members)};	
	foreach my $member (@b_members) {
		my $addr_obj = $members->lookup_address(address => $member);
		if ( defined $addr_obj and $addr_obj->parent->no_agent) {
			#no agent do not initiate locally
			$initiations{$member}{$local_inits} = 0;			
		}else {
			$initiations{$member}{$local_inits} = scalar(@a_members);
		}
		# remote initiations
		$initiations{$member}{$remote_inits} = scalar(@members_has_agent);		
	}
	
	return \%initiations;	
}

=head2 __get_test_initiations_ordered_mesh
	This method returns the initiations for ordered mesh group type. The first member initiate local 
	to all members without itself. Every member initiates locally n-i tests where n the amount 
	of member is and i is the iterator i=(1,2,..n).  For remote initiations has the first 
	member 0 remote initiations and the last member has the highest remote initiations n - i 
	where i=(n,...1). The call parameter for this method is a member object. It returns 
	a hash with the local and remote initiations as values and the address as key. 
=cut
sub __get_test_initiations_ordered_mesh {
	my ($self, $members) = @_;
	my %initiations = ();
	my @members = $members->members;
	my @members_has_agent = @{$self->get_members_with_agent(@members, $members)};
	my $num_of_members = scalar(@members);
	my $num_of_members_with_agent = scalar(@members_has_agent);
	
	for (my $i=0; $i < $num_of_members; $i++) {
		my $member = $members[$i];
		my $addr_obj = $members->lookup_address(address => $member);
		if ( defined $addr_obj and $addr_obj->parent->no_agent) {
			#no agent do not initiate locally
			$initiations{$member}{$local_inits} = 0;			
		}else {
			$initiations{$member}{$local_inits} = $num_of_members - $i - 1;
		}
	}
	
	#TODO: wite a test to check this
	#remote initiations
	for (my $i=$num_of_members - 1; $i >= 0; $i--) {
		my $member = $members[$i];
		if ( $i > $num_of_members_with_agent){
			$initiations{$member}{$remote_inits} = $num_of_members_with_agent;
		} else {
			$initiations{$member}{$remote_inits} = $i;
		}
				
	}
	return \%initiations;
	
}

sub get_members_with_agent {
	my ($self, $members, $members_obj) = @_;
	my @members_has_agent = ();
	my @members = @{$members};
		
	foreach my $member (@members) {
		my $addr_obj = $members_obj->lookup_address(address => $member);
		if (defined $addr_obj) {
		 	if (not $addr_obj->parent->no_agent) {
				push(@members_has_agent, $member);
			}
		}
	}
	return \@members_has_agent;
	
}

sub __get_bwctl_time_percentage {
	
}
