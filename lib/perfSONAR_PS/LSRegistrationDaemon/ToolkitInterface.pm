package perfSONAR_PS::LSRegistrationDaemon::ToolkitInterface;

use base 'perfSONAR_PS::LSRegistrationDaemon::Interface';
use Digest::MD5 qw(md5_base64);


=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    $self->SUPER::init( $conf );
    
    #external_address_ipv4 172.16.130.142
    #external_address_ipv6 2001:400:6001:1158::3
    #external_address_iface eth0
    
    #check required values
    if(!$self->{CONF}->{if_name} && !$self->{CONF}->{external_address_if_name}){
         die "Must specify name or external_address_iface for toolkit interfaces";
    }
    if(!$self->{CONF}->{address} && !$self->{CONF}->{external_address} &&
        !$self->{CONF}->{external_address_ipv4} && !$self->{CONF}->{external_address_ipv6}){
         die "Must specify address or external_address for toolkit interfaces";
    }
    
    #set values
    if(!$self->{CONF}->{if_name}){
        $self->{CONF}->{if_name} = $self->{CONF}->{external_address_if_name};
    }
    
    if(!$self->{CONF}->{address}){
        my $addr_map = {};
        $self->_add_address($addr_map, $self->{CONF}->{external_address});
        $self->_add_address($addr_map, $self->{CONF}->{external_address_ipv4});
        $self->_add_address($addr_map, $self->{CONF}->{external_address_ipv6});
        my @tmp = keys %{$addr_map};
        $self->{CONF}->{address} = \@tmp;
    }
    
    return 0;
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

1;