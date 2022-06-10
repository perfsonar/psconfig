package perfSONAR_PS::PSConfig::Remote;

use Mouse;
use perfSONAR_PS::Client::PSConfig::JQTransform;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

=item url()

Gets/sets the URL of the JSON file to download

=cut

sub url {
    my ($self, $val) = @_;
    return $self->_field_url('url', $val);
}

=item configure_archives()

Gets/sets whether archives should be used from this remote file. Must be 0 or 1.

=cut

sub configure_archives {
    my ($self, $val) = @_;
    return $self->_field_bool('configure-archives', $val);
}

=item bind_address()

Gets/sets the local address (as string) to use when connecting to remote url

=cut

sub bind_address {
    my ($self, $val) = @_;
    return $self->_field_host('bind-address', $val);
}

=item ssl_ca_file()

Gets/sets the typical certificate authority (CA) file found on BSD. Used to verify server SSL certificate when using https.

=cut

sub ssl_ca_file {
    my ($self, $val) = @_;
    return $self->_field('ssl-ca-file', $val);
}

=item transform()

Get/sets JQTransform object with jq for transforming JSON before processing

=cut

sub transform {
    my ($self, $val) = @_;
    return $self->_field_class('transform', 'perfSONAR_PS::Client::PSConfig::JQTransform', $val);
}


__PACKAGE__->meta->make_immutable;

1;
