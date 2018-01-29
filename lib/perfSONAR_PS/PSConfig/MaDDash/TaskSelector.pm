package perfSONAR_PS::PSConfig::MaDDash::TaskSelector;

use Mouse;

use perfSONAR_PS::PSConfig::JQTransform;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

=item test_type()

Get/sets test-type as ArrayRef

=cut

sub test_type{
    my ($self, $val) = @_;
    return $self->_field_list('test-type', $val);
}

=item add_test_type()

Adds test-type to list

=cut

sub add_test_type{
    my ($self, $val) = @_;
    $self->_add_list_item('test-type', $val);
}

=item task_name()

Get/sets task-name as ArrayRef

=cut

sub task_name{
    my ($self, $val) = @_;
    return $self->_field_list('task-name', $val);
}

=item add_task_name()

Adds task-name to list

=cut

sub add_task_name{
    my ($self, $val) = @_;
    $self->_add_list_item('task-name', $val);
}

=item archive_type()

Get/sets archive-type as ArrayRef

=cut

sub archive_type{
    my ($self, $val) = @_;
    return $self->_field_list('archive-type', $val);
}

=item add_archive_type()

Adds archive-type to list

=cut

sub add_archive_type{
    my ($self, $val) = @_;
    $self->_add_list_item('archive-type', $val);
}

=item jq()

Get/sets JQTransform object for selecting tasks

=cut

sub jq {
    my ($self, $val) = @_;
    return $self->_field_class('jq', 'perfSONAR_PS::PSConfig::JQTransform', $val);
}

=item matches()

Returns whether the given object matches this selector

=cut

sub matches{
    my ($self, $jq_obj) = @_;
    
    #return if no jq_obj
    unless($jq_obj){
        return;
    }
    
    #check test types
    my $sel_test_types = $self->test_type();
    if($sel_test_types && @{$sel_test_types}){
        unless($jq_obj->{'test'} && $jq_obj->{'test'}->{'type'}){
            return;
        }
        my $matches = 0;
        my $test_type = $jq_obj->{'test'}->{'type'};
        foreach my $sel_test_type(@{$sel_test_types}){
            if($sel_test_type eq $test_type){
                $matches = 1;
                last;
            }
        }
        return 0 unless($matches);
    }
    
    #check task name types
    my $sel_task_names = $self->task_name();
    if($sel_task_names && @{$sel_task_names}){
        return unless($jq_obj->{'task-name'});
        my $matches = 0;
        my $task_name = $jq_obj->{'task-name'};
        foreach my $sel_task_name(@{$sel_task_names}){
            if($task_name eq $sel_task_name){
                $matches = 1;
                last;
            }
        }
        return 0 unless($matches);
    }
    
    #check archive type
    my $sel_archive_types = $self->archive_type();
    if($sel_archive_types && @{$sel_archive_types}){
        return unless($jq_obj->{'archives'});
        my $matches = 0;
        my $archives = $jq_obj->{'archives'};
        my $archive_types = {};
        #build map of archives for efficiency
        foreach my $archive(@{$archives}){
            $archive_types->{$archive->{'archiver'}} = 1;
        }
        #see if we have a matching type
        foreach my $sel_archive_type(@{$sel_archive_types}){
            if($archive_types->{$sel_archive_type}){
                $matches = 1;
                last;
            }
        }
        return 0 unless($matches);
    }
    
    #check jq
    my $jq = $self->jq();
    if($jq){
        #try to apply transformation
        my $jq_result = $jq->apply($jq_obj);
        if(!$jq_result){
            return 0;
        }
    }
        
    return 1;
}




__PACKAGE__->meta->make_immutable;

1;
