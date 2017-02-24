package perfSONAR_PS::LSRegistrationDaemon::Host;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Digest::MD5 qw(md5_base64);
use POSIX;

use Sys::Hostname;
use Socket;
use Socket6;
use Data::Validate::IP qw(is_ipv4);

use perfSONAR_PS::NPToolkit::Config::Version;
use perfSONAR_PS::Utils::Host qw(get_operating_system_info get_processor_info get_tcp_configuration get_ethernet_interfaces discover_primary_address get_ips get_dmi_info get_health_info);

use perfSONAR_PS::Client::LS::PSRecords::PSHost;
use perfSONAR_PS::LSRegistrationDaemon::Interface;
use perfSONAR_PS::Common qw(mergeConfig);

use perfSONAR_PS::LSRegistrationDaemon::Person;

use perfSONAR_PS::LSRegistrationDaemon::Services::Phoebus;
use perfSONAR_PS::LSRegistrationDaemon::Services::REDDnet;
use perfSONAR_PS::LSRegistrationDaemon::Services::BWCTL;
use perfSONAR_PS::LSRegistrationDaemon::Services::OWAMP;
use perfSONAR_PS::LSRegistrationDaemon::Services::MA;
use perfSONAR_PS::LSRegistrationDaemon::Services::MeshConfig;
use perfSONAR_PS::LSRegistrationDaemon::Services::PScheduler;
use perfSONAR_PS::LSRegistrationDaemon::Services::Dashboard;
use perfSONAR_PS::LSRegistrationDaemon::Services::MP_BWCTL;
use perfSONAR_PS::LSRegistrationDaemon::Services::MP_OWAMP;
use perfSONAR_PS::LSRegistrationDaemon::Services::NDT;
use perfSONAR_PS::LSRegistrationDaemon::Services::NPAD;
use perfSONAR_PS::LSRegistrationDaemon::Services::GridFTP;
use perfSONAR_PS::LSRegistrationDaemon::Services::Ping;
use perfSONAR_PS::LSRegistrationDaemon::Services::Traceroute;

use fields 'INTERFACES', 'SERVICES';

sub known_variables {
    my ($self) = @_;

    my @variables = $self->SUPER::known_variables();

    push @variables, (
        { variable => "interface", type => "array" },
        { variable => "service", type => "array" },
        { variable => "site_project", type => "array" },

        { variable => "administrator", type => "hash" },

        { variable => "allow_internal_addresses", type => "scalar" },
        { variable => "autodiscover", type => "scalar" },
        { variable => "autodiscover_interfaces", type => "scalar" },
        { variable => "city", type => "scalar" },
        { variable => "country", type => "scalar" },
        { variable => "disable_ipv4_reverse_lookup", type => "scalar" },
        { variable => "disable_ipv6_reverse_lookup", type => "scalar" },
        { variable => "domain", type => "array" },
        { variable => "host_name", type => "array" },
        { variable => "is_local", type => "scalar" },
        { variable => "latitude", type => "scalar" },
        { variable => "longitude", type => "scalar" },
        { variable => "memory", type => "scalar" },
        { variable => "name", type => "scalar" },
        { variable => "os_kernel", type => "scalar" },
        { variable => "os_name", type => "scalar" },
        { variable => "os_version", type => "scalar" },
        { variable => "processor_cores", type => "scalar" },
        { variable => "processor_count", type => "scalar" },
        { variable => "processor_speed", type => "scalar" },
        { variable => "processor_cpuid", type => "scalar" },
        { variable => "region", type => "scalar" },
        { variable => "site_name", type => "scalar" },
        { variable => "tcp_autotune_max_buffer_recv", type => "scalar" },
        { variable => "tcp_autotune_max_buffer_send", type => "scalar" },
        { variable => "tcp_cc_algorithm", type => "scalar" },
        { variable => "tcp_max_backlog", type => "scalar" },
        { variable => "tcp_max_buffer_recv", type => "scalar" },
        { variable => "tcp_max_buffer_send", type => "scalar" },
        { variable => "tcp_max_achievable", type => "scalar" },
        { variable => "toolkit_version", type => "scalar" },
        { variable => "zip_code", type => "scalar" },
        { variable => "role", type => "array" },
        { variable => "bundle_type", type => "scalar" },
        { variable => "bundle_version", type => "scalar" },
        { variable => "install_method", type => "scalar" },
        { variable => "access_policy", type => "scalar" },
        { variable => "access_policy_notes", type => "scalar" },
        { variable => "is_virtual_machine", type => "scalar" },
        { variable => "manufacturer", type => "scalar" },
        { variable => "system_product_name", type => "scalar" },
    );

    return @variables;
}


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
            $conf->{host_name} = [];
            my $primary_address_info = discover_primary_address(
                                           interface => $conf->{primary_interface},
                                           allow_rfc1918 => $conf->{allow_internal_addresses},
                                           disable_ipv4_reverse_lookup => $conf->{disable_ipv4_reverse_lookup},
                                           disable_ipv6_reverse_lookup => $conf->{disable_ipv6_reverse_lookup},
                                       );
            push @{$conf->{host_name}}, $primary_address_info->{primary_address} if($primary_address_info->{primary_address});
            push @{$conf->{host_name}}, $primary_address_info->{primary_dns_name} if($primary_address_info->{primary_dns_name});
        }

        unless ($conf->{host_name}) {
            push @{$conf->{host_name}}, hostname;
        }
        
        unless ($conf->{domain}){
            my @iface_ips = get_ips();
            my %domain_map = ();
            foreach my $iface_ip(@iface_ips){
                my $iface_afamily = (is_ipv4($iface_ip) ? AF_INET : AF_INET6);
                my $iface_iaddr = inet_pton($iface_afamily, $iface_ip);
                my $iface_host = gethostbyaddr($iface_iaddr, $iface_afamily);
                if($iface_host){
                    my @domain_parts = split /\./, $iface_host;
                    shift @domain_parts;
                    while(@domain_parts >= 2){
                        $domain_map{join '.', @domain_parts} = 1;
                        shift @domain_parts;
                    }
                }
            }
            my @tmp_domains = keys %domain_map;
            $conf->{domain} = \@tmp_domains;
        }
        $conf->{memory} = floor(get_health_info()->{memstats}->{memtotal}/1024) . ' MB'
            unless $conf->{memory};

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
            $conf->{processor_cpuid} = $cpu_info->{model_name} unless $conf->{processor_cpuid};
        }
        
        my $dmi_info = get_dmi_info();
        if ($dmi_info) {
            $conf->{manufacturer} = $dmi_info->{'sys_vendor'} unless $conf->{manufacturer};
            $conf->{product_name} = $dmi_info->{'product_name'} unless $conf->{product_name};
            $conf->{is_virtual_machine}  = $dmi_info->{'is_virtual_machine'} unless defined $conf->{is_virtual_machine};
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

        # Grab the bundle version
        unless($conf->{bundle_version} && $conf->{bundle_type} && $conf->{install_method}) {
            my $toolkit_version_conf = perfSONAR_PS::NPToolkit::Config::Version->new();
            $toolkit_version_conf->init();
            $conf->{bundle_version} = $toolkit_version_conf->get_version() if(!$conf->{bundle_version} && $toolkit_version_conf->get_version());
            $conf->{bundle_type} = $toolkit_version_conf->get_install_type() if(!$conf->{bundle_type} && $toolkit_version_conf->get_install_type());
            $conf->{install_method} = $toolkit_version_conf->get_install_method() if(!$conf->{install_method} && $toolkit_version_conf->get_install_method());
        }
    }
 
    return $self->SUPER::init( $conf );
}


sub init_dependencies {
    my ( $self ) = @_;

    $self->{CONF}->{interface} = [] unless $self->{CONF}->{interface};
    $self->{CONF}->{interface} = [ $self->{CONF}->{interface} ] unless ref($self->{CONF}->{interface}) eq "ARRAY";


    if ($self->{CONF}->{autodiscover_interfaces}) {
        $self->{CONF}->{interface} = [] unless $self->{CONF}->{interface};
        $self->{CONF}->{interface} = [ $self->{CONF}->{interface} ] unless ref($self->{CONF}->{interface}) eq "ARRAY";

        # XXX: handle the external address vs. internal address stuff?
        $self->{LOGGER}->debug("Adding interface");

        my @interfaces = get_ethernet_interfaces();
        foreach my $interface (@interfaces) {
            my @external_addresses = ();
            my $addresses = discover_primary_address(
                                interface => $interface,
                                allow_rfc1918 => $self->{CONF}->{allow_internal_addresses},
                                disable_ipv4_reverse_lookup => $self->{CONF}->{disable_ipv4_reverse_lookup},
                                disable_ipv6_reverse_lookup => $self->{CONF}->{disable_ipv6_reverse_lookup},
                            );

            push @external_addresses, $addresses->{primary_address} if $addresses->{primary_address};
            push @external_addresses, $addresses->{primary_ipv4} if $addresses->{primary_ipv4};
            push @external_addresses, $addresses->{primary_ipv6} if $addresses->{primary_ipv6};
            next unless scalar(@external_addresses) > 0;
            my $iface_conf = {
                if_name => $interface,
                address => \@external_addresses
            };
            $iface_conf->{capacity} = $addresses->{primary_iface_speed} if($addresses->{primary_iface_speed});
            $iface_conf->{mtu} = $addresses->{primary_iface_mtu} if($addresses->{primary_iface_mtu});
            $iface_conf->{mac_address} = $addresses->{primary_iface_mac} if($addresses->{primary_iface_mac});

            push @{ $self->{CONF}->{interface} }, $iface_conf;
        }
    }

    #create interfaces
    my @interfaces = ();

    foreach my $iface(@{$self->{CONF}->{interface}}){
        $self->{LOGGER}->debug("Creating new interface object");
        my $iface_reg = perfSONAR_PS::LSRegistrationDaemon::Interface->new();
        $iface_reg->init(mergeConfig($self->{CONF}, $iface));
        push @interfaces, $iface_reg;
    }

    $self->{INTERFACES} = \@interfaces;

    $self->{DEPENDENCIES} = $self->{INTERFACES};

    return 0;
}

sub init_subordinates {
    my ($self) = @_;

    # Parse service configurations
    
    $self->{CONF}->{service} = [] unless $self->{CONF}->{service};
    $self->{CONF}->{service} = [ $self->{CONF}->{service} ] unless ref($self->{CONF}->{service}) eq "ARRAY";

    my @services = ();

    foreach my $curr_service_conf ( @{ $self->{CONF}->{service} } ) {
        my $service_conf = mergeConfig( $self->{CONF}, $curr_service_conf );

        if ($service_conf->{inherits}) {
            unless ($service_conf->{service_template} and 
                       $service_conf->{service_template}->{$service_conf->{inherits}}
                   ) {
                $self->{LOGGER}->error( "Error: Service template '".$service_conf->{inherits}."' not found" );
                return -1;
            }
            my $template = $service_conf->{service_template}->{$service_conf->{inherits}};

            $service_conf = mergeConfig( $template, $service_conf );
        }

        # Set the host parameter
        $service_conf->{host} = $self;

        unless ( $service_conf->{type} ) {

            # complain
            $self->{LOGGER}->error( "Error: No service type specified" );
            return -1;
        }

        my $service;

        if ( lc( $service_conf->{type} ) eq "bwctl" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::BWCTL->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "owamp" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::OWAMP->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "ping" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::Ping->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "traceroute" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::Traceroute->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "phoebus" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::Phoebus->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "reddnet" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::REDDnet->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "ndt" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::NDT->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "npad" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::NPAD->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "gridftp" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::GridFTP->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "ma" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::MA->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "pscheduler" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::PScheduler->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "dashboard" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::Dashboard->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "mp_bwctl" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::MP_BWCTL->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "mp_owamp" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::MP_OWAMP->new();
        }
        elsif ( lc( $service_conf->{type} ) eq "mesh_config" ) {
            $service = perfSONAR_PS::LSRegistrationDaemon::Services::MeshConfig->new();
        }
        else {
            # error
            $self->{LOGGER}->error( "Error: Unknown service type: " . $service_conf->{type} );
            return -1;
        }

        if ( $service->init( $service_conf ) != 0 ) {
            # complain
            $self->{LOGGER}->error( "Error: Couldn't initialize service type: ".$service->type());
            return -1;
        }

        push @services, $service;
    }

    $self->{SERVICES} = \@services;

    $self->{SUBORDINATES} = $self->{SERVICES};

    return 0;
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
    
    if(@{$self->host_name()} > 0){
        return $self->host_name()->[0] . '';
    }else{
        return '';
    }
}

sub host_name {
    my ( $self ) = @_;

    return $self->{CONF}->{host_name} if $self->{CONF}->{host_name};

    return [ $self->{CONF}->{name} ];
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

sub processor_cpuid {
    my ( $self ) = @_;

    return $self->{CONF}->{processor_cpuid};
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

sub tcp_max_achievable {
    my ( $self ) = @_;

    return $self->{CONF}->{tcp_max_achievable};
}

sub domain {
    my ( $self ) = @_;

    return $self->{CONF}->{domain};
}

sub toolkit_version {
    my ( $self ) = @_;
    
    return $self->{CONF}->{toolkit_version};
}

sub role {
    my ( $self ) = @_;
    
    return $self->{CONF}->{role};
}

sub bundle_type {
    my ( $self ) = @_;
    
    return $self->{CONF}->{bundle_type};
}

sub bundle_version {
    my ( $self ) = @_;
    
    return $self->{CONF}->{bundle_version};
}

sub install_method {
    my ( $self ) = @_;
    
    return $self->{CONF}->{install_method};
}

sub access_policy {
    my ( $self ) = @_;
    
    return $self->{CONF}->{access_policy};
}

sub access_policy_notes {
    my ( $self ) = @_;
    
    return $self->{CONF}->{access_policy_notes};
}

sub is_virtual_machine {
    my ( $self ) = @_;
    
    return $self->{CONF}->{is_virtual_machine};
}

sub manufacturer {
    my ( $self ) = @_;
    
    return $self->{CONF}->{manufacturer};
}

sub product_name {
    my ( $self ) = @_;
    
    return $self->{CONF}->{product_name};
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
    	cpuId => $self->processor_cpuid(),
    	osName=> $self->os_name(), 
    	osVersion=> $self->os_version(), 
    	osKernel => $self->os_kernel(), 
    	tcpCongestionAlgorithm => $self->tcp_cc_algorithm(),
    	tcpMaxBufferSend => $self->tcp_max_buffer_send(), 
    	tcpMaxBufferRecv => $self->tcp_max_buffer_recv(), 
    	tcpAutoMaxBufferSend => $self->tcp_autotune_max_buffer_send(), 
    	tcpAutoMaxBufferRecv => $self->tcp_autotune_max_buffer_recv(), 
    	tcpMaxBacklog => $self->tcp_max_backlog(), 
    	tcpMaxAchievable => $self->tcp_max_achievable(), 
    	vm => $self->is_virtual_machine() . "", #does not register unless a string
    	manufacturer => $self->manufacturer(),
    	productName => $self->product_name(),
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
    $service->setRole($self->role()) if(defined $self->role());
    $service->setBundle($self->bundle_type()) if(defined $self->bundle_type());
    $service->setBundleVersion($self->bundle_version()) if(defined $self->bundle_version());
    $service->setInstallMethod($self->install_method()) if(defined $self->install_method());
    $service->setAccessPolicy($self->access_policy()) if(defined $self->access_policy());
    $service->setAccessNotes($self->access_policy_notes()) if(defined $self->access_policy_notes());
    $service->setToolkitVersion($self->toolkit_version()) if(defined $self->toolkit_version());
    #handle backward compatibility with toolkit version (deprecated in 3.5)
    if(defined $self->bundle_version() && !defined $self->toolkit_version()){
         $service->setToolkitVersion($self->bundle_version());
    }elsif(defined $self->toolkit_version() && !defined $self->bundle_version()){
         $service->setBundleVersion($self->toolkit_version());
    }
    $service->setCommunities($self->site_project()) if($self->site_project());;
    
    return $service;
}

sub checksum_prefix {
    return "host";
}

sub checksum_fields {
    return [
        "host_name",
        "interface",
        "memory",
        "processor_speed",
        "processor_count", 
        "processor_cores",
        "processor_cpuid",
        "os_name",
        "os_version",
        "os_kernel",
        "tcp_cc_algorithm",
        "tcp_max_buffer_send",
        "tcp_max_buffer_recv",
        "tcp_autotune_max_buffer_send",
        "tcp_autotune_max_buffer_recv",
        "tcp_max_backlog",
        "tcp_max_achievable",
        "domain",
        "toolkit_version",
        "role",
        "bundle_type",
        "bundle_version",
        "install_method",
        "access_policy",
        "access_policy_notes",
        "is_virtual_machine",
        "administrator", 
        "site_name",
        "city",
        "region",
        "country",
        "zip_code",
        "latitude",
        "longitude",
        "site_project",
    ];
}

sub duplicate_checksum_fields {
    return [
        "host_name"
    ];
}

1;
