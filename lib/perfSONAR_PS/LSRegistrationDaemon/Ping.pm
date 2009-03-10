package perfSONAR_PS::LSRegistrationDaemon::Ping;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::ICMP_Service';

sub type {
    my ( $self ) = @_;

    return "Ping Responder";
}

sub service_type {
    my ( $self ) = @_;

    return "ping";
}

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/ping/1.0";
}

1;
