package perfSONAR_PS::PSConfig::CLI::Lookup::Output;

use Mouse;

extends 'perfSONAR_PS::Client::PSConfig::BaseMetaNode';

=item tags()

Gets/sets the tags as an ArrayRef

=cut

sub tags{
    my ($self, $val) = @_;
    return $self->_field('tags', $val);
}

=item add_tag()

Adds a tag to the list

=cut

sub add_tag{
    my ($self, $val) = @_;
    $self->_add_list_item('tags', $val);
}

=item no_agent()

Gets/sets no-agent

=cut

sub no_agent{
    my ($self, $val) = @_;
    return $self->_field_bool('no-agent', $val);
}


=item archives()

Get/sets archives as HashRef

=cut

sub archives{
    my ($self, $val) = @_;
    
    return $self->_field_class_map('archives', 'perfSONAR_PS::Client::PSConfig::Archive', $val);
}

=item archive()

Get/sets archive at specified field

=cut

sub archive{
    my ($self, $field, $val) = @_;
    
    return $self->_field_class_map_item('archives', $field, 'perfSONAR_PS::Client::PSConfig::Archive', $val);
}

=item archive_names()

Gets keys of archives HashRef

=cut

sub archive_names{
    my ($self) = @_;
    return $self->_get_map_names("archives");
} 

=item remove_archive()

Removes archive at specified field

=cut

sub remove_archive {
    my ($self, $field) = @_;
    $self->_remove_map_item('archives', $field);
}

=item contexts()

Get/sets contexts as HashRef

=cut

sub contexts{
    my ($self, $val) = @_;
    
    return $self->_field_class_map('contexts', 'perfSONAR_PS::Client::PSConfig::Context', $val);
}

=item context()

Get/sets context at specified field

=cut

sub context{
    my ($self, $field, $val) = @_;
    
    return $self->_field_class_map_item('contexts', $field, 'perfSONAR_PS::Client::PSConfig::Context', $val);
}

=item context_names()

Gets keys of contexts HashRef

=cut

sub context_names{
    my ($self) = @_;
    return $self->_get_map_names("contexts");
} 

=item remove_context()

Removes context at specified field

=cut

sub remove_context {
    my ($self, $field) = @_;
    $self->_remove_map_item('contexts', $field);
}



__PACKAGE__->meta->make_immutable;

1;
