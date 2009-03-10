package perfSONAR_PS::LSRegistrationDaemon::TCP_Service;

use strict;
use warnings;

use perfSONAR_PS::Utils::DNS qw(resolve_address);
use perfSONAR_PS::Utils::Host qw(get_ips);

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';

use fields 'ADDRESSES', 'PORT';

use IO::Socket;
use IO::Socket::INET6;
use IO::Socket::INET;

sub init {
    my ( $self, $conf ) = @_;

    unless ( $conf->{address} ) {
        $self->{LOGGER}->warn( "No address specified, assuming local service" );
    }

    my @addresses;

    if ( $conf->{address} ) {
        @addresses = ();

        my @tmp = ();
        if ( ref( $conf->{address} ) eq "ARRAY" ) {
            @tmp = @{ $conf->{address} };
        }
        else {
            push @tmp, $conf->{address};
        }

        my %addr_map = ();
        foreach my $addr ( @tmp ) {
            $addr_map{$addr} = 1;

            #            my @addrs = resolve_address($addr);
            #            foreach my $addr (@addrs) {
            #                $addr_map{$addr} = 1;
            #            }
        }

        @addresses = keys %addr_map;
    }
    elsif ( $conf->{is_local} ) {
        @addresses = get_ips();
    }

    $self->{ADDRESSES} = \@addresses;

    if ( $conf->{port} ) {
        $self->{PORT} = $conf->{port};
    }

    return $self->SUPER::init( $conf );
}

sub is_up {
    my ( $self ) = @_;

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $sock;

        $self->{LOGGER}->debug( "Connecting to: " . $addr . ":" . $self->{PORT} );

        if ( $addr =~ /:/ ) {
            $sock = IO::Socket::INET6->new( PeerAddr => $addr, PeerPort => $self->{PORT}, Proto => 'tcp', Timeout => 5 );
        }
        else {
            $sock = IO::Socket::INET->new( PeerAddr => $addr, PeerPort => $self->{PORT}, Proto => 'tcp', Timeout => 5 );
        }

        if ( $sock ) {
            $sock->close;

            return 1;
        }
    }

    return 0;
}

sub get_service_addresses {
    my ( $self ) = @_;

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

sub get_node_addresses {
    my ( $self ) = @_;

    my @addrs = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        unless ( $addr =~ /:/ or $addr =~ /\d+\.\d+\.\d+\.\d+/ ) {

            # it's probably a hostname, try looking it up.
        }

        if ( $addr =~ /:/ ) {
            my %addr = ();
            $addr{"value"} = $addr;
            $addr{"type"}  = "ipv6";
            push @addrs, \%addr;
        }
        elsif ( $addr =~ /\d+\.\d+\.\d+\.\d+/ ) {
            my %addr = ();
            $addr{"value"} = $addr;
            $addr{"type"}  = "ipv4";
            push @addrs, \%addr;
        }
    }

    return \@addrs;
}

1;
