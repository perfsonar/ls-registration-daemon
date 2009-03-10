package perfSONAR_PS::LSRegistrationDaemon::Phoebus;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use constant DEFAULT_PORT => 5006;

sub init {
    my ( $self, $conf ) = @_;

    my $port = $conf->{port};
    if ( not $port ) {
        $conf->{port} = DEFAULT_PORT;
    }

    return $self->SUPER::init( $conf );
}

sub get_service_addresses {
    my ( $self ) = @_;

    # we override the TCP_Service addresses function so that we can generate
    # URLs.

    my @addresses = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $uri;

        $uri = "tcp://";
        if ( $addr =~ /:/ ) {
            $uri .= "[$addr]";
        }
        else {
            $uri .= "$addr";
        }

        $uri .= ":" . $self->{PORT};

        my %addr = ();
        $addr{"value"} = $uri;
        $addr{"type"}  = "uri";

        push @addresses, \%addr;
    }

    return \@addresses;
}

sub type {
    my ( $self ) = @_;

    return "Phoebus Depot";
}

sub service_type {
    my ( $self ) = @_;

    return "phoebus";
}

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/phoebus/1.0";
}

1;
