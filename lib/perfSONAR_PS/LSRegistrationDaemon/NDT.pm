package perfSONAR_PS::LSRegistrationDaemon::NDT;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use constant DEFAULT_PORT => 7123;

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

        $uri = "http://";
        if ( $addr =~ /:/ ) {
            $uri .= "[$addr]";
        }
        else {
            $uri .= "$addr";
        }

        $uri .= ":" . $self->{PORT};

        my %addr = ();
        $addr{"value"} = $uri;
        $addr{"type"}  = "url";

        push @addresses, \%addr;
    }

    return \@addresses;
}

sub type {
    my ( $self ) = @_;

    return "NDT Server";
}

sub service_type {
    my ( $self ) = @_;

    return "ndt";
}

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/ndt/1.0";
}

1;
