package perfSONAR_PS::LSRegistrationDaemon::ToolkitInterface;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Interface';
use Digest::MD5 qw(md5_base64);


=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    
    #check required values
    if(!$conf->{if_name} && !$conf->{external_address_if_name}){
         die "Must specify name or external_address_iface for toolkit interfaces";
    }
    if(!$conf->{address} && !$conf->{external_address} &&
        !$conf->{external_address_ipv4} && !$conf->{external_address_ipv6}){
         die "Must specify address or external_address for toolkit interfaces";
    }
    
    #set values
    if(!$conf->{if_name}){
        $conf->{if_name} = $conf->{external_address_if_name};
    }
    
    #lookup mtu and mac
    my $ethernet_info = {};
    if(!$conf->{mac_address} || !$conf->{mtu}){
        $ethernet_info = $self->_discover_ethernet_info($conf->{if_name});
    }
    
    if(!$conf->{mac_address}){
        $conf->{mac_address} = $ethernet_info->{mac_address};
    }
    
    if(!$conf->{mtu}){
        $conf->{mtu} = $ethernet_info->{mtu};
    }
    
    if(!$conf->{capacity}){
        $conf->{capacity} = $conf->{external_address_if_speed};
    }
    #lookup interface speed if not set elsewhere
    if(!$conf->{capacity}){
       my $speed = $self->_discover_interface_speed($conf->{if_name});
       $conf->{capacity} = $speed if($speed);
    }
    
    if(!$conf->{address}){
        my $addr_map = {};
        $self->_add_address($addr_map, $conf->{external_address});
        $self->_add_address($addr_map, $conf->{external_address_ipv4});
        $self->_add_address($addr_map, $conf->{external_address_ipv6});
        my @tmp = keys %{$addr_map};
        $conf->{address} = \@tmp;
    }
    
    return $self->SUPER::init( $conf );
}
            
sub _add_address(){
    my ( $self, $map, $address ) = @_;
    if(!$address){
        return;
    }
    
    if(ref($address) ne 'ARRAY'){
        $address = [ $address ];
    }
    
    foreach my $a(@{$address}){
        $map->{$a} = 1;
    }
}

sub _discover_ethernet_info(){
    my ( $self, $iface ) = @_;
    if(!$iface){
        return;
    }
    
    my $ethernet_info = {};
    open( my $IFCONFIG, "-|", "/sbin/ifconfig $iface" ) or return;
    while ( <$IFCONFIG> ) {
        if ( /^(\S+)\s*Link encap:([^ ]+)/ ) {
            if ( lc( $2 ) ne "ethernet" ) {
                next;
            }
        }

        if ( /HWaddr ([a-fA-F0-9]+\:[a-fA-F0-9]+\:[a-fA-F0-9]+\:[a-fA-F0-9]+\:[a-fA-F0-9]+\:[a-fA-F0-9]+)/ ) {
            $ethernet_info->{mac_address} = $1;
        }
        if ( /MTU:(\d+)/ ) {
            $ethernet_info->{mtu} = $1;
        }
    }
    close( $IFCONFIG );
    
    return $ethernet_info;
}

sub _discover_interface_speed {
    my ($self, $interface_name) = @_;
    
    my $speed = 0;
    my $ETHTOOL;
    open( $ETHTOOL, "-|", "/sbin/ethtool $interface_name" ) or return;
    while ( <$ETHTOOL> ) {
        if ( /^\s*Speed:\s+(\d+)\s*(\w)/ ) {
            $speed = $1;
            my $units = $2;
            if($units eq 'M'){
                $speed *= 10**6;
            }elsif($units eq 'G'){
                $speed *= 10**9;
            }elsif($units eq 'T'){
                $speed *= 10**12;
            }
            last;
        }
    }
    close( $ETHTOOL );
    
    return $speed;
}

1;
