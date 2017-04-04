package perfSONAR_PS::LSRegistrationDaemon::Services::ICMP_Service;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Services::ICMP_Service - The ICMP_Service class
provides a simple sub-class for checking if ICMP services are running.

=head1 DESCRIPTION

This module is meant to be inherited by other classes that define the ICMP
services. It defines the function get_service_addresses, get_node_addresses and
a simple is_up routine that checks if a service is responding to pings.
=cut

use strict;
use warnings;

our $VERSION = 3.3;

use Net::Ping;

use Net::CIDR;
use Net::IP;

use perfSONAR_PS::Utils::DNS qw(reverse_dns resolve_address);
use perfSONAR_PS::Utils::Host qw(get_ips);

use base 'perfSONAR_PS::LSRegistrationDaemon::Service';

use fields 'ADDRESSES';

=head2 init($self, $conf)

This function checks if an address has been configured, if not, it reads the
local addresses, and uses those to perform the later checks.

=cut

sub init {
    my ( $self, $conf ) = @_;

    $self->fill_addresses($conf) unless $conf->{address};

    $conf->{address} = [ $conf->{address} ] unless ref($conf->{address}) eq "ARRAY";

    unless ( scalar(@{ $conf->{address} }) > 0 ) {
        my $err_msg = "No address available for service";
        $err_msg .= " on " . $conf->{primary_interface} if($conf->{primary_interface});
        $err_msg .= ". All private addresses were ignored. Please set allow_internal_addresses if you wish to use a private address." unless($conf->{allow_internal_addresses});
        $self->{LOGGER}->error($err_msg);
        return -1;
    }

    $self->{ADDRESSES} = $conf->{address};

    return $self->SUPER::init( $conf );
}

=head2 service_locator ($self)

This function returns the list of addresses for this service.

=cut

sub service_locator {
    my ( $self ) = @_;

    return $self->{ADDRESSES};
}

=head2 is_up ($self)

This function uses Net::Ping::External to ping the service. If any of the
addresses match, it returns true, if not, it returns false.

=cut

sub is_up {
    my ( $self ) = @_;

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        ($addr) = ($addr =~ /(.*)/); #untaint
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

__END__

=head1 SEE ALSO

L<Net::Ping>, L<Net::Ping::External>, L<perfSONAR_PS::Utils::DNS>,
L<perfSONAR_PS::Utils::Host>, L<perfSONAR_PS::LSRegistrationDaemon::Base>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS git repository is located at:

  https://code.google.com/p/perfsonar-ps/

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
