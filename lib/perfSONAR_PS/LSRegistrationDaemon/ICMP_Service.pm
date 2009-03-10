package perfSONAR_PS::LSRegistrationDaemon::ICMP_Service;

use strict;
use warnings;

use Net::Ping;

use perfSONAR_PS::Utils::DNS qw(reverse_dns resolve_address);
use perfSONAR_PS::Utils::Host qw(get_ips);

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';

use fields 'ADDRESSES';

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
            my @addrs = resolve_address( $addr );
            foreach my $addr ( @addrs ) {
                $addr_map{$addr} = 1;
            }
        }

        @addresses = keys %addr_map;
    }
    else {
        @addresses = get_ips();
    }

    $self->{ADDRESSES} = \@addresses;

    return $self->SUPER::init( $conf );
}

sub get_service_addresses {
    my ( $self ) = @_;

    my @addrs = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my %addr = ();
        $addr{"value"} = $addr;
        if ( $addr =~ /:/ ) {
            $addr{"type"} = "ipv6";
        }
        else {
            $addr{"type"} = "ipv4";
        }

        push @addrs, \%addr;
    }

    return \@addrs;
}

sub get_node_addresses {
    my ( $self ) = @_;

    return $self->get_service_addresses();
}

sub is_up {
    my ( $self ) = @_;

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        if ( $addr =~ /:/ ) {
            next;
        }
        else {
            $self->{LOGGER}->debug( "Pinging: " . $addr );
            my $ping = Net::Ping->new( "external" );
            if ( $ping->ping( $addr, 1 ) ) {
                return 1;
            }
        }
    }

    return 0;
}

1;
