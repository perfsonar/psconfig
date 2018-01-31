package perfSONAR_PS::PSConfig::MaDDash::Template;

=head1 NAME

perfSONAR_PS::PSConfig::MaDDash::Template - A library for filling in template variables in JSON

=head1 DESCRIPTION

A library for filling in template variables in JSON

=cut

use Mouse;
use JSON;
use perfSONAR_PS::Client::PSConfig::Config;
use perfSONAR_PS::Utils::ISO8601 qw( duration_to_seconds );

extends 'perfSONAR_PS::Client::PSConfig::Parsers::BaseTemplate';

our $VERSION = 4.1;

has 'row' => (is => 'rw', isa => 'Str');
has 'col' => (is => 'rw', isa => 'Str');
has 'check_config' => (is => 'rw', isa => 'perfSONAR_PS::PSConfig::MaDDash::Agent::CheckConfig');
has 'visualization_config' => (is => 'rw', isa => 'perfSONAR_PS::PSConfig::MaDDash::Agent::VisualizationConfig');
has 'check_defaults' => (is => 'rw', isa => 'perfSONAR_PS::PSConfig::MaDDash::Checks::CheckDefaults');
has 'viz_defaults' => (is => 'rw', isa => 'perfSONAR_PS::PSConfig::MaDDash::Visualization::VizDefaults');
has 'check_vars' => (is => 'rw', isa => 'HashRef', default => sub { {} });
has 'viz_vars' => (is => 'rw', isa => 'HashRef', default => sub { {} });

sub _expand_var {
    my ($self, $template_var) = @_;
    my $val;

    if($template_var eq 'row'){
        $val = $self->_parse_row();
    }elsif($template_var eq 'col'){
        $val = $self->_parse_col();
    }elsif($template_var eq 'check.warning'){
        $val = $self->_parse_warning();
    }elsif($template_var eq 'check.critical'){
        $val = $self->_parse_critical();
    }elsif($template_var eq 'check.timeout'){
        $val = $self->_parse_timeout();
    }elsif($template_var eq 'check.timeout.seconds'){
        $val = $self->_parse_timeout_seconds();
    }elsif($template_var =~ /^check.params\.(.+)$/){
        $val = $self->_parse_check_param($1);
    }elsif($template_var =~ /^check.vars\.(.+)$/){
        $val = $self->_parse_var($self->check_vars(), $1, 'check');
    }elsif($template_var =~ /^viz.params\.(.+)$/){
        $val = $self->_parse_viz_param($1);
    }elsif($template_var =~ /^viz.vars\.(.+)$/){
        $val = $self->_parse_var($self->viz_vars(), $1, 'vizualization');
    }elsif($template_var =~ '^jq (.+)$'){
        $val = $self->_parse_jq($1);
    }else{
        $self->_set_error("Unrecognized template variable $template_var");
    }
    
    return $val;
}

sub _parse_row {
    my ($self) = @_;

    return $self->__format_return_string($self->row());
}

sub _parse_col {
    my ($self) = @_;

    return $self->__format_return_string($self->col());
}

sub _parse_warning {
    my ($self) = @_;

    #check params first
    my $val = $self->check_defaults()->warning_threshold();
    if($self->check_config()->warning_threshold()){
        $val = $self->check_config()->warning_threshold();
    }

    return $self->__format_return_string($val);
}

sub _parse_critical {
    my ($self) = @_;

    #check params first
    my $val = $self->check_defaults()->critical_threshold();
    if($self->check_config()->critical_threshold()){
        $val = $self->check_config()->critical_threshold();
    }
    
    return $self->__format_return_string($val);
}

sub _parse_timeout {
    my ($self) = @_;

    #check params first
    my $val = $self->check_defaults()->timeout();
    if($self->check_config()->timeout()){
        $val = $self->check_config()->timeout();
    }
    
    return $self->__format_return_string($val);
}

sub _parse_timeout_seconds {
    my ($self) = @_;

    #get time
    my $timeout = $self->check_defaults()->timeout();
    if($self->check_config()->timeout()){
        $timeout = $self->check_config()->timeout();
    }
    
    #convert to seconds
    my $seconds;
    eval{
        $seconds = duration_to_seconds($timeout);
    };
    if($@){
         $self->_set_error("Unable to convert $timeout to seconds: $@");
    }
    
    return $seconds;
}

sub _parse_check_param {
    my ($self, $param_name) = @_;

    #check params first
    my $val = $self->check_defaults()->param($param_name);
    if($self->check_config()->param($param_name)){
        $val = $self->check_config()->param($param_name);
    }
    
    return $self->__format_return_string($val);
}

sub _parse_viz_param {
    my ($self, $param_name) = @_;

    #check params first
    my $val = $self->viz_defaults()->param($param_name);
    if($self->viz_config()->param($param_name)){
        $val = $self->viz_config()->param($param_name);
    }
    
    return $self->__format_return_string($val);
}

sub _parse_var {
    my ($self, $vars, $var_name, $label) = @_;

    #check params first
    my $val;
    if(exists $vars->{$var_name} && defined $vars->{$var_name}){
        $val = $vars->{$var_name};
    }elsif(exists $vars->{$var_name}){
        #if undefined, that's ok
        $val = "";
    }else{
        #bad variable name
        $self->_set_error("Unrecognized $label variable '$var_name' provided");
        return;
    }
    
    return $self->__format_return_string($val);
}

sub __format_return_string {
    my ($self, $val) = @_;
    
    return $val;
}



__PACKAGE__->meta->make_immutable;

1;

