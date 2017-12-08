package perfSONAR_PS::PSConfig::Remote;

use Mouse;

extends 'perfSONAR_PS::Client::PSConfig::BaseNode';

sub url {
    my ($self, $val) = @_;
    return $self->_field_url('url', $val);
}

sub configure_archives {
    my ($self, $val) = @_;
    return $self->_field_bool('configure-archives', $val);
}

sub ssl_validate_certificate {
    my ($self, $val) = @_;
    return $self->_field_bool('ssl-validate-certificate', $val);
}

sub ssl_ca_file {
    my ($self, $val) = @_;
    return $self->_field('ssl-ca-file', $val);
}

sub ssl_ca_path {
    my ($self, $val) = @_;
    return $self->_field('ssl-ca-path', $val);
}

#TODO: Implement JQ support
sub transform {
    my ($self, $val) = @_;
    return $self->_field_anyobj('transform', $val);
}


__PACKAGE__->meta->make_immutable;

1;
