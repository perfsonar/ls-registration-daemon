package perfSONAR_PS::LSRegistrationDaemon::NPAD;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use constant DEFAULT_PORT => 8200;

sub init {
    my ( $self, $conf ) = @_;

    my $res;
    if ( $conf->{config_file} ) {
        my $res = read_npad_config( $conf->{config_file} );
        if ( $res->{error} ) {
            $self->{LOGGER}->error( "Problem reading npad configuation: " . $res->{error} );
            $self->{STATUS} = "BROKEN";
            return -1;
        }
    }
    else {
        my %tmp = ();
        $res = \%tmp;
    }

    if ( not $conf->{port} and not $res->{port} ) {
        $conf->{port} = DEFAULT_PORT;
    }
    elsif ( not $conf->{port} ) {
        $conf->{port} = $res->{port};
    }

    return $self->SUPER::init( $conf );
}

sub read_npad_config {
    my ( $file ) = @_;

    my %conf;

    my $port;

    my $FH;
    open( $FH, "<", $file ) or return \%conf;
    while ( <$FH> ) {
        if ( /key="webPort".*value="\([^"]\)"/ ) {
            $port = $1;
        }
    }
    close( $FH );

    $conf{port} = $port;

    return \%conf;
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

    return "NPAD Server";
}

sub service_type {
    my ( $self ) = @_;

    return "npad";
}

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/npad/1.0";
}

1;
