package perfSONAR_PS::LSRegistrationDaemon::Host;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Digest::MD5 qw(md5_base64);

use Sys::Hostname;
use Sys::MemInfo qw(totalmem);

use perfSONAR_PS::NPToolkit::Config::Version;
use perfSONAR_PS::Utils::Host qw(get_operating_system_info get_processor_info get_tcp_configuration get_ethernet_interfaces discover_primary_address);

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
   
    if ($conf->{autodiscover} and not $conf->{is_local}) {
        die "Non-local host set to 'autodiscover'";
    }

    if ($conf->{autodiscover_interfaces} and not $conf->{is_local}) {
        die "Non-local host set to 'autodiscover_interfaces'";
    }

    if ($conf->{autodiscover}) {
        unless ($conf->{host_name}) {
            my $primary_address_info = discover_primary_address(
                                           interface => $conf->{primary_interface},
                                           allow_rfc1918 => $conf->{allow_internal_addresses},
                                           disable_ipv4_reverse_lookup => $conf->{disable_ipv4_reverse_lookup},
                                           disable_ipv6_reverse_lookup => $conf->{disable_ipv6_reverse_lookup},
                                       );
            $conf->{host_name} = $primary_address_info->{primary_address};
        }

        unless ($conf->{host_name}) {
            $conf->{host_name} = hostname;
        }

        $conf->{memory} = (&totalmem()/(1024*1024)) . ' MB' unless $conf->{memory};

        my $os_info = get_operating_system_info();
        if ($os_info) {
            $conf->{os_name} = $os_info->{distribution_name} unless $conf->{os_name};
            $conf->{os_version} = $os_info->{distribution_version} unless $conf->{os_version};
            $conf->{os_kernel} = $os_info->{os_name}." ".$os_info->{kernel_version} unless $conf->{os_kernel};
        }
 
        my $cpu_info = get_processor_info();
        if ($cpu_info) {
            if ($cpu_info->{speed} and not $conf->{processor_speed}) {
                $conf->{processor_speed} = $cpu_info->{speed} . ' MHz';
            }
            $conf->{processor_count} = $cpu_info->{count} unless $conf->{processor_count};
            $conf->{processor_cores} = $cpu_info->{cores} unless $conf->{processor_cores};
        }
   
        my $tcp_info = get_tcp_configuration(); 
        if ($tcp_info) {
            $conf->{tcp_cc_algorithm} = $tcp_info->{tcp_cc_algorithm} unless $conf->{tcp_cc_algorithm};
            if($tcp_info->{tcp_max_buffer_send} and not $conf->{tcp_max_buffer_send}){
                $conf->{tcp_max_buffer_send} = $tcp_info->{tcp_max_buffer_send} . ' bytes';
            }
            if($tcp_info->{tcp_max_buffer_recv} and not $conf->{tcp_max_buffer_recv}){
                $conf->{tcp_max_buffer_recv} = $tcp_info->{tcp_max_buffer_recv} . ' bytes';
            }
            if($tcp_info->{tcp_autotune_max_buffer_send} and not $conf->{tcp_autotune_max_buffer_send}){
                $conf->{tcp_autotune_max_buffer_send} = $tcp_info->{tcp_autotune_max_buffer_send} . ' bytes';
            }
            if($tcp_info->{tcp_autotune_max_buffer_recv} and not $conf->{tcp_autotune_max_buffer_recv}){
                $conf->{tcp_autotune_max_buffer_recv} = $tcp_info->{tcp_autotune_max_buffer_recv} . ' bytes';
            }
            $conf->{tcp_cc_backlog} = $tcp_info->{tcp_cc_backlog} unless $conf->{tcp_cc_backlog};
        }

        # Grab the Toolkit version    
        my $toolkit_version_conf = perfSONAR_PS::NPToolkit::Config::Version->new();
        $toolkit_version_conf->init();
        $conf->{toolkit_version} = $toolkit_version_conf->get_version() if $toolkit_version_conf->get_version();
    }
 
    return $self->SUPER::init( $conf );
}


sub init_children {
    my ( $self ) = @_;
    $self->SUPER::init_children();

    $self->{CONF}->{interface} = [] unless $self->{CONF}->{interface};
    $self->{CONF}->{interface} = [ $self->{CONF}->{interface} ] unless ref($self->{CONF}->{interface}) eq "ARRAY";


    if ($self->{CONF}->{autodiscover_interfaces}) {
        $self->{CONF}->{interface} = [] unless $self->{CONF}->{interface};
        $self->{CONF}->{interface} = [ $self->{CONF}->{interface} ] unless ref($self->{CONF}->{interface}) eq "ARRAY";

        # XXX: handle the external address vs. internal address stuff?

        my @interfaces = get_ethernet_interfaces();
        foreach my $interface (@interfaces) {
            push @{ $self->{CONF}->{interface} }, {
                autodiscover => 1,
                if_name => $interface
            };
        }
    }

    #create interfaces
    my @interfaces = ();

    foreach my $iface(@{$self->{CONF}->{interface}}){
        my $iface_reg = perfSONAR_PS::LSRegistrationDaemon::Interface->new();
        $iface_reg->init(mergeConfig($self->{CONF}, $iface));
        push @interfaces, $iface_reg;
    }

    $self->{INTERFACES} = \@interfaces;

    $self->{CHILD_REGISTRATIONS} = $self->{INTERFACES};
}

sub is_up {
    #die "Subclass must implement is_up"; 
    return 1;
}

sub autodiscover {
    my ($self) = @_;

    return $self->{CONF}->{autodiscover};
}

sub is_local {
    my ($self) = @_;

    return $self->{CONF}->{is_local};
}

sub description {
    my ( $self ) = @_;

    return $self->host_name() . '';
}

sub host_name {
    my ( $self ) = @_;

    return $self->{CONF}->{host_name} if $self->{CONF}->{host_name};

    return $self->{CONF}->{name};
}

sub interface {
    my ( $self ) = @_;
   
    my @ifaces = ();
    foreach my $iface (@{ $self->{INTERFACES} }) { 
        push @ifaces, $iface->{KEY} if $iface->{KEY};
    }

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
    unless ($self->{CONF}->{administrator}) {
        return '';
    }
    
    my $admin = perfSONAR_PS::LSRegistrationDaemon::Person->new();
    my $admin_conf = mergeConfig($self->{CONF}, $self->{CONF}->{administrator});
    $admin_conf->{disabled} = 1;

    if($admin->init( $admin_conf ) != 0) {
        $self->{LOGGER}->error( "Error: Couldn't create person object for host admin" );
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
