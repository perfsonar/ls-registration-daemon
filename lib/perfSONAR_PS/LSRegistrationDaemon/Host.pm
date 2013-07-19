package perfSONAR_PS::LSRegistrationDaemon::Host;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Client::LS::PSRecords::PSHost;
use perfSONAR_PS::LSRegistrationDaemon::Interface;
use perfSONAR_PS::Common qw(mergeConfig);

use fields 'INTERFACES';

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    
    return $self->SUPER::init( $conf );
}


sub init_children {
    my ( $self ) = @_;
    $self->SUPER::init_children();
    
    #create interfaces
    my @interfaces = ();
    if($self->{CONF}->{interface} && ref($self->{CONF}->{interface}) ne 'ARRAY'){
        my @tmp = ();
        push @tmp, $self->{CONF}->{interface};
        $self->{CONF}->{interface} = \@tmp;
    }
    foreach my $iface(@{$self->{CONF}->{interface}}){
        my $iface_reg = $self->create_interface($iface->{type});
        $iface_reg->init(mergeConfig($self->{CONF}, $iface));
        push @interfaces, $iface_reg;
    }
    $self->{INTERFACES} = \@interfaces;
    
    $self->{CHILD_REGISTRATIONS} = $self->{INTERFACES};
}

sub create_interface {
    my ($self, $type) = @_;
    
    return perfSONAR_PS::LSRegistrationDaemon::Interface->new();
}

sub is_up {
    #die "Subclass must implement is_up"; 
    return 1;
}


sub description {
    my ( $self ) = @_;

    return $self->host_name() . '';
}

sub host_name {
    my ( $self ) = @_;

    return $self->{CONF}->{name};
}

sub interface {
    my ( $self ) = @_;
    
    my @ifaces = map {$_->{"KEY"}} @{$self->{INTERFACES}};
    return \@ifaces; 
}

sub memory {
    my ( $self ) = @_;

    return $self->{CONF}->{memory};
}

sub processor_speed {
    my ( $self ) = @_;

    return $self->{CONF}->{processor_speed};
}

sub processor_count {
    my ( $self ) = @_;

    return $self->{CONF}->{processor_count};
}

sub processor_cores {
    my ( $self ) = @_;

    return $self->{CONF}->{processor_cores};
}

sub os_name {
    my ( $self ) = @_;

    return $self->{CONF}->{os_name};
}

sub os_version {
    my ( $self ) = @_;

    return $self->{CONF}->{os_version};
}

sub os_kernel {
    my ( $self ) = @_;

    return $self->{CONF}->{os_kernel};
}

sub tcp_cc_algorithm {
    my ( $self ) = @_;

    return $self->{CONF}->{tcp_cc_algorithm};
}

sub tcp_max_buffer_send {
    my ( $self ) = @_;

    return $self->{CONF}->{tcp_max_buffer_send};
}

sub tcp_max_buffer_recv {
    my ( $self ) = @_;

    return $self->{CONF}->{tcp_max_buffer_recv};
}

sub tcp_autotune_max_buffer_send {
    my ( $self ) = @_;

    return $self->{CONF}->{tcp_autotune_max_buffer_send};
}

sub tcp_autotune_max_buffer_recv {
    my ( $self ) = @_;

    return $self->{CONF}->{tcp_autotune_max_buffer_recv};
}

sub tcp_max_backlog {
    my ( $self ) = @_;

    return $self->{CONF}->{tcp_max_backlog};
}

sub domain {
    my ( $self ) = @_;

    return $self->{CONF}->{domain};
}

sub toolkit_version {
    my ( $self ) = @_;
    
    return $self->{CONF}->{toolkit_version};
}

sub administrator {
    my ( $self ) = @_;
    
    #Skip host registration if value not set
    if( !$self->{CONF}->{full_name} && !$self->{CONF}->{administrator_email} ){
        return '';
    }
    
    my $admin = perfSONAR_PS::LSRegistrationDaemon::Person->new();
    my $admin_conf = { 
        full_name => $self->{CONF}->{full_name}, 
        administrator_email => $self->{CONF}->{administrator_email}, 
        disabled => 1,
        ls_key_db => $self->{CONF}->{ls_key_db}
    };
    if($admin->init( $admin_conf ) != 0) {
        $self->{LOGGER}->error( "Error: Couldn't create person object for service admin" );
        return '';
    }
    
    return $admin->find_duplicate();
}

sub site_name {
    my ( $self ) = @_;

    return $self->{CONF}->{site_name};
}

sub site_project {
    my ( $self ) = @_;

    return $self->{CONF}->{site_project};
}

sub city {
    my ( $self ) = @_;

    return $self->{CONF}->{city};
}

sub region {
    my ( $self ) = @_;

    return $self->{CONF}->{region};
}

sub country {
    my ( $self ) = @_;

    return $self->{CONF}->{country};
}

sub zip_code {
    my ( $self ) = @_;

    return $self->{CONF}->{zip_code};
}

sub latitude {
    my ( $self ) = @_;

    return $self->{CONF}->{latitude};
}

sub longitude {
    my ( $self ) = @_;

    return $self->{CONF}->{longitude};
}

sub build_registration {
    my ( $self ) = @_;
    
    my $service = new perfSONAR_PS::Client::LS::PSRecords::PSHost();
    $service->init(
        hostName => $self->host_name(), 
        interfaces => $self->interface(),
        memory => $self->memory(), 
    	processorSpeed => $self->processor_speed(), 
    	processorCount => $self->processor_count(), 
    	processorCore => $self->processor_cores(),
    	osName=> $self->os_name(), 
    	osVersion=> $self->os_version(), 
    	osKernel => $self->os_kernel(), 
    	tcpCongestionAlgorithm => $self->tcp_cc_algorithm(),
    	tcpMaxBufferSend => $self->tcp_max_buffer_send(), 
    	tcpMaxBufferRecv => $self->tcp_max_buffer_recv(), 
    	tcpAutoMaxBufferSend => $self->tcp_autotune_max_buffer_send(), 
    	tcpAutoMaxBufferRecv => $self->tcp_autotune_max_buffer_recv(), 
    	tcpMaxBacklog => $self->tcp_max_backlog(), 
        administrators=> $self->administrator(), 
        domains => $self->domain(),
    	siteName => $self->site_name(), 
    	city => $self->city(), 
    	region => $self->region(),
    	country => $self->country(), 
    	zipCode => $self->zip_code(),
    	latitude => $self->latitude(), 
    	longitude => $self->longitude(),
    );
    if(defined $self->toolkit_version()){
        $service->setToolkitVersion($self->toolkit_version());
    }
    $service->setCommunities($self->site_project()) if($self->site_project());
    
    return $service;
}

sub build_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'host::';
    $checksum .= $self->_add_checksum_val($self->host_name()); 
    $checksum .= $self->_add_checksum_val($self->interface()); 
    $checksum .= $self->_add_checksum_val($self->memory()); 
    $checksum .= $self->_add_checksum_val($self->processor_speed()); 
    $checksum .= $self->_add_checksum_val($self->processor_count()); 
    $checksum .= $self->_add_checksum_val($self->processor_cores());
    $checksum .= $self->_add_checksum_val($self->os_name());
    $checksum .= $self->_add_checksum_val($self->os_version());
    $checksum .= $self->_add_checksum_val($self->os_kernel());
    $checksum .= $self->_add_checksum_val($self->tcp_cc_algorithm());
    $checksum .= $self->_add_checksum_val($self->tcp_max_buffer_send());
    $checksum .= $self->_add_checksum_val($self->tcp_max_buffer_recv());
    $checksum .= $self->_add_checksum_val($self->tcp_autotune_max_buffer_send());
    $checksum .= $self->_add_checksum_val($self->tcp_autotune_max_buffer_recv());
    $checksum .= $self->_add_checksum_val($self->tcp_max_backlog());
    $checksum .= $self->_add_checksum_val($self->domain());
    $checksum .= $self->_add_checksum_val($self->toolkit_version());
    $checksum .= $self->_add_checksum_val($self->administrator()); 
    $checksum .= $self->_add_checksum_val($self->site_name());
    $checksum .= $self->_add_checksum_val($self->city());
    $checksum .= $self->_add_checksum_val($self->region());
    $checksum .= $self->_add_checksum_val($self->country());
    $checksum .= $self->_add_checksum_val($self->zip_code());
    $checksum .= $self->_add_checksum_val($self->latitude());
    $checksum .= $self->_add_checksum_val($self->longitude());
    $checksum .= $self->_add_checksum_val($self->site_project());
    
    $checksum = md5_base64($checksum);
    $self->{LOGGER}->info("Checksum is " . $checksum);
    
    return  $checksum;
}

sub build_duplicate_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'host::';
    $checksum .= $self->_add_checksum_val($self->host_name()); 
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
