package perfSONAR_PS::LSRegistrationDaemon::Traceroute;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::ICMP_Service';

sub type {
    my ( $self ) = @_;

    return "Traceroute Responder";
}

sub service_type {
    my ( $self ) = @_;

    return "traceroute";
}

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/traceroute/1.0";
}

1;
