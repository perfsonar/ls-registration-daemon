package perfSONAR_PS::LSRegistrationDaemon::TCP_Service;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::TCP_Service - The TCP_Service class
provides a simple sub-class for checking if generic TCP services are running.

=head1 DESCRIPTION

This module is meant to be inherited by other classes that define the TCP
services. It defines the function get_service_addresses, get_node_addresses and
a simple is_up routine that checks it can connect to the service with a simple
TCP connect.

=cut

use strict;
use warnings;

use Net::CIDR;
use Net::IP;

use perfSONAR_PS::Utils::DNS qw(resolve_address reverse_dns);
use perfSONAR_PS::Utils::Host qw(get_ips);

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::Service';

use fields 'ADDRESSES', 'PORT';

use IO::Socket;
use IO::Socket::INET6;
use IO::Socket::INET;

=head2 init($self, $conf)

This function checks if an address has been configured, if not, it reads the
local addresses, and uses those to perform the later checks.

=cut

sub init {
    my ( $self, $conf ) = @_;

    unless ( $conf->{address} ) {
        $self->{LOGGER}->warn( "No address specified, assuming local service" );
    }

    my @addresses;

    if ( $conf->{address} || $conf->{external_address}) {
        @addresses = ();
        
        my $address = $conf->{address} ? $conf->{address} : $conf->{external_address};
        
        my @tmp = ();
        if ( ref( $address ) eq "ARRAY" ) {
            @tmp = @{ $address };
        }
        else {
            push @tmp, $address;
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
    else {
        my @all_addresses = get_ips();
        foreach my $ip (@all_addresses) {
            if (Net::IP::ip_is_ipv6( $ip )) {
                push @addresses, $ip;
            }
            else {
                my @private_list = ( '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16' );

                next unless ($conf->{allow_internal_addresses} or not Net::CIDR::cidrlookup( $ip, @private_list ));

                push @addresses, $ip;
            }
        }
    }

    $self->{ADDRESSES} = \@addresses;

    if ( $conf->{port} ) {
        $self->{PORT} = $conf->{port};
    }

    return $self->SUPER::init( $conf );
}

=head2 is_up ($self)

This function uses IO::Socket::INET or IO::Socket::INET6 to make a TCP
connection to the addresses and ports. If it can connect to any of them, it
returns that the service is up. If not, it returns that the service is down.

=cut

sub is_up {
    my ( $self ) = @_;

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $sock;

        $self->{LOGGER}->debug( "Connecting to: " . $addr . ":" . $self->{PORT} );

        $sock = IO::Socket::INET6->new( PeerAddr => $addr, PeerPort => $self->{PORT}, Proto => 'tcp', Timeout => 5 );

        if ( $sock ) {
            if ($self->connected_cb($sock)) {
                $sock->close;

                return 1;
            }

            $sock->close;
        }
    }

    return 0;
}

sub connected_cb {
     my ( $self, $sock ) = @_;

     return 1;
}

=head2 get_service_addresses ($self)

This function returns the list of addresses for the service is running on.

=cut

sub get_service_addresses {
    my ( $self ) = @_;

    my @addresses = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $uri;

        my $dns = reverse_dns( $addr );

        $uri = "tcp://";
		if ( $dns ) {
			$uri .= "$dns";
        }
        elsif ( $addr =~ /:/ ) {
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

=head2 get_service_addresses ($self)

This function returns the list of addresses for the service is running on.

=cut

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

sub service_locator {
    my ( $self ) = @_;
    
    my @urls = map {$_->{"value"}} @{$self->get_service_addresses()};
    return \@urls;
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::Utils::DNS>,L<perfSONAR_PS::Utils::Host>,
L<perfSONAR_PS::LSRegistrationDaemon::Base>,L<IO::Socket>,
L<IO::Socket::INET>,L<IO::Socket::INET6>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2007-2010, Internet2

All rights reserved.

=cut
