package perfSONAR_PS::PSConfig::MaDDash::Agent::Grid;

use Mouse;
use Log::Log4perl qw(get_logger);

use perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig;
use perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority;
use perfSONAR_PS::PSConfig::MaDDash::TaskSelector;
use perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig;
use perfSONAR_PS::PSConfig::MaDDash::Checks::Config;
use perfSONAR_PS::PSConfig::MaDDash::Visualization::Config;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

has 'check_plugin' => (is => 'rw', isa => 'perfSONAR_PS::PSConfig::MaDDash::Checks::Config|Undef');
has 'visualization_plugin' => (is => 'rw', isa => 'perfSONAR_PS::PSConfig::MaDDash::Visualization::Config|Undef');

my $logger;
if(Log::Log4perl->initialized()) {
    #this is intended to be a lib reliant on someone else initializing env
    #detect if they did but quietly move on if not
    #anything using $logger will need to check if defined
    $logger = get_logger(__PACKAGE__);
}

=item display_name()

Sets/gets display-name string

=cut

sub display_name{
    my ($self, $val) = @_;
    return $self->_field('display-name', $val);
}

=item selector()

Sets/gets selector object

=cut

sub selector{
    my ($self, $val) = @_;
    return $self->_field_class('selector', 'perfSONAR_PS::PSConfig::MaDDash::TaskSelector', $val);
}

=item check()

Sets/gets check object

=cut

sub check{
    my ($self, $index, $val) = @_;
    return $self->_field_class('check', 'perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig', $val);
}

=item visualization()

Sets/gets visualization object

=cut

sub visualization{
    my ($self, $index, $val) = @_;
    return $self->_field_class('visualization', 'perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig', $val);
}

=item priority()

Sets/gets priority object

=cut

sub priority{
    my ($self, $index, $val) = @_;
    return $self->_field_class('priority', 'perfSONAR_PS::PSConfig::MaDDash::Agent::GridPriority', $val);
}

=item load_check_plugin()

Sets check_plugin given a map of check plugin objects where the key is the type

=cut

sub load_check_plugin{
    my ($self, $plugin_map) = @_;
    
    $self->check_plugin($self->_load_plugin($plugin_map, $self->check(), "check"));
}

=item load_visualization_plugin()

Sets visualization plugin given a map of visualization plugin objects where the key is the type

=cut

sub load_visualization_plugin{
    my ($self, $plugin_map) = @_;
    
    $self->visualization_plugin($self->_load_plugin($plugin_map, $self->visualization(), "visualization"));
}

=item matches()

Returns whether the given object matches this grid

=cut

sub matches{
    my ($self, $jq_obj) = @_;
    
    #make sure we have viz and check plugins
    my $check = $self->check_plugin();
    my $viz = $self->visualization_plugin();
    unless($check && $viz){
        return;
    }
    
    #check requires()
    my $check_requires = $check->requires();
    my $viz_requires = $viz->requires();
    unless($check_requires && $viz_requires){
        return;
    }
    
    #check the requires() of each plugin
    unless($check_requires->matches($jq_obj) && $viz_requires->matches($jq_obj)){
        return 0;
    }
    
    #check task selector, but only if it's set
    my $sel = $self->selector(); #optional
    if($sel && !$sel->matches($jq_obj)){
        return 0;
    }
    
    return 1;
}


sub _load_plugin{
    my ($self, $plugin_map, $plugin_config, $plugin_label) = @_;
    
    #make sure have required args
    unless($plugin_map && $plugin_config && $plugin_config->type()){
        return;
    }
    
    #lookup 
    my $type = $plugin_config->type();
    if($plugin_map->{$type}){
        return $plugin_map->{$type};
    }elsif($logger){
        $logger->warn("Unable to find $plugin_label plugin of type $type. Skipping grid " . $self->map_name() . '.');
    }
    
    return;
}





__PACKAGE__->meta->make_immutable;

1;
