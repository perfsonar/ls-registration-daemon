package perfSONAR_PS::LSRegistrationDaemon::Interface;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Client::LS::PSRecords::PSInterface;

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    
    return $self->SUPER::init( $conf );
}

sub is_up {
    #die "Subclass must implement is_up"; 
    return 1;
}

=head2 service_name ($self)

This internal function generates the name to register this service as. It calls
the object-specific function "type" when creating the function.

=cut

sub description {
    my ( $self ) = @_;

    return $self->if_name() . '';
}
            
sub if_name {
    my ( $self ) = @_;

    return $self->{CONF}->{if_name};
}

sub address {
    my ( $self ) = @_;

    return $self->{CONF}->{address};
}

sub mac_address {
    my ( $self ) = @_;

    return $self->{CONF}->{mac_address};
}

sub mtu {
    my ( $self ) = @_;

    return $self->{CONF}->{mtu};
}

sub subnet {
    my ( $self ) = @_;

    return $self->{CONF}->{subnet};
}

sub capacity {
    my ( $self ) = @_;

    return $self->{CONF}->{capacity};
}

sub if_type {
    my ( $self ) = @_;

    return $self->{CONF}->{if_type};
}

sub urn {
    my ( $self ) = @_;

    return $self->{CONF}->{urn};
}

sub domain {
    my ( $self ) = @_;

    return $self->{CONF}->{domain};
}

sub build_registration {
    my ( $self ) = @_;
    
    my $iface = new perfSONAR_PS::Client::LS::PSRecords::PSInterface();
    $iface->init(
        interfaceName => $self->if_name(), 
        interfaceAddresses => $self->address(), 
        subnet => $self->subnet(), 
        capacity => $self->capacity(), 
        macAddress=> $self->mac_address(), 
        domains=> $self->domain(),
    );
    $iface->setInterfaceMTU($self->mtu()) if(defined $self->mtu());
    $iface->setInterfaceType($self->if_type()) if(defined $self->if_type());
    $iface->setUrns($self->urn()) if(defined $self->urn());
    
    return $iface;
}

sub build_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'interface::';
    $checksum .= $self->_add_checksum_val($self->if_name()); 
    $checksum .= $self->_add_checksum_val($self->address()); 
    $checksum .= $self->_add_checksum_val($self->subnet()); 
    $checksum .= $self->_add_checksum_val($self->capacity()); 
    $checksum .= $self->_add_checksum_val($self->mac_address());
    $checksum .= $self->_add_checksum_val($self->domain());
    $checksum .= $self->_add_checksum_val($self->mtu());
    $checksum .= $self->_add_checksum_val($self->if_type());
    $checksum .= $self->_add_checksum_val($self->urn());
    
    $checksum = md5_base64($checksum);
    $self->{LOGGER}->info("Checksum is " . $checksum);
    
    return  $checksum;
}

sub build_duplicate_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'interface::';
    $checksum .= $self->_add_checksum_val($self->if_name()); 
    $checksum .= $self->_add_checksum_val($self->address()); 
    $checksum = md5_base64($checksum);
    
    return $checksum;
}

sub _add_checksum_val {
    my ($self, $val) = @_;
    
    my $result = '';
    
    if(!defined $val){
        return $result;
    }
    
    if(ref($val) eq 'ARRAY'){
        $result = join ',', sort @{$val};
    }else{
        $result = $val;
    }
    
    return $result;
}
1;
