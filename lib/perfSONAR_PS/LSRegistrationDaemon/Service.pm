package perfSONAR_PS::LSRegistrationDaemon::Service;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Digest::MD5 qw(md5_base64);

use perfSONAR_PS::Common qw(mergeConfig);
use perfSONAR_PS::Utils::Host qw(discover_primary_address);
use perfSONAR_PS::Client::LS::PSRecords::PSService;

use fields 'HOST';

sub known_variables {
    my ($self) = @_;

    my @variables = $self->SUPER::known_variables();

    push @variables, (
        { variable => "address", type => "array" },
        { variable => "site_project", type => "array" },
        { variable => "authentication_type", type => "array" },
        { variable => "administrator", type => "hash" },

        { variable => "allow_internal_addresses", type => "scalar" },
        { variable => "autodiscover_addresses", type => "scalar" },
        { variable => "city", type => "scalar" },
        { variable => "country", type => "scalar" },
        { variable => "disable_ipv4_reverse_lookup", type => "scalar" },
        { variable => "disable_ipv6_reverse_lookup", type => "scalar" },
        { variable => "domain", type => "array" },
        { variable => "is_local", type => "scalar" },
        { variable => "latitude", type => "scalar" },
        { variable => "longitude", type => "scalar" },
        { variable => "region", type => "scalar" },
        { variable => "site_name", type => "scalar" },
        { variable => "zip_code", type => "scalar" },
        { variable => "service_locator", type => "scalar" },
        { variable => "service_name", type => "scalar" },
        { variable => "service_version", type => "scalar" },
    );

    return @variables;
}

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;

    $self->fill_addresses($conf) unless $conf->{address};

    $self->{HOST} = $conf->{host};

    return $self->SUPER::init( $conf );
}

sub fill_addresses {
    my ($self, $conf) = @_;

    if ($conf->{autodiscover_addresses} and not $conf->{is_local}) {
        die "Non-local service set to 'autodiscover'";
    }

    $conf->{address} = [] unless $conf->{address};
    $conf->{address} = [ $conf->{address} ] unless ref($conf->{address}) eq "ARRAY";

    if ($conf->{autodiscover_addresses}) {
        my $addresses = discover_primary_address(
                            interface => $conf->{primary_interface},
                            allow_rfc1918 => $conf->{allow_internal_addresses},
                            disable_ipv4_reverse_lookup => $conf->{disable_ipv4_reverse_lookup},
                            disable_ipv6_reverse_lookup => $conf->{disable_ipv6_reverse_lookup},
                        );

        push @{ $conf->{address} }, $addresses->{primary_address} if $addresses->{primary_address};
        push @{ $conf->{address} }, $addresses->{primary_ipv4} if $addresses->{primary_ipv4};
        push @{ $conf->{address} }, $addresses->{primary_ipv6} if $addresses->{primary_ipv6};
    }

    # Make sure that addresses are unique
    my %addresses = ();
    foreach my $address (@{ $conf->{address} }) {
        $addresses{$address} = 1;
    }
    my @addresses = keys %addresses;

    $conf->{address} = \@addresses;


}

sub service_type {
    die "Subclass must implement service_type";
}

sub is_up {
    die "Subclass must implement is_up"; 
}

=head2 service_name ($self)

This internal function generates the name to register this service as. It calls
the object-specific function "type" when creating the function.

=cut

sub service_name {
    my ( $self ) = @_;

    if ( $self->{CONF}->{service_name} ) {
        return $self->{CONF}->{service_name};
    }

    my $retval = q{};
    if ( $self->{CONF}->{site_name} ) {
        $retval .= $self->{CONF}->{site_name} . " ";
    }
    $retval .= $self->type();

    return $retval;
}

sub description {
    my ( $self ) = @_;

    return $self->service_name();
}

sub service_host {
    my ( $self ) = @_;

    my $key = $self->{HOST}->{KEY};
    $key = "" unless $key;
 
    return $key;
}

sub service_version {
    my ( $self ) = @_;

    return $self->{CONF}->{service_version};
}

sub service_locator {
    my ( $self ) = @_;

    return $self->{CONF}->{service_locator};
}

sub authentication_type {
    my ( $self ) = @_;

    return $self->{CONF}->{authentication_type};
}


sub domain {
    my ( $self ) = @_;

    return $self->{CONF}->{domain};
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
        $self->{LOGGER}->error( "Error: Couldn't create person object for service admin" );
        return '';
    }
    
    return $admin->find_duplicate();
}

sub site_name {
    my ( $self ) = @_;

    return $self->{CONF}->{site_name};
}

sub communities {
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
    
    my $service = new perfSONAR_PS::Client::LS::PSRecords::PSService();
    $service->init(
        serviceLocator => $self->service_locator(), 
        serviceType => $self->service_type(), 
        serviceName => $self->service_name(), 
        serviceVersion => $self->service_version(), 
        serviceHost => $self->service_host(),
    	domains => $self->domain(),
    	administrators => $self->administrator(), 
    	siteName => $self->site_name(),
    	city => $self->city(),
    	region => $self->region(),
    	country => $self->country(),
    	zipCode => $self->zip_code(),
    	latitude => $self->latitude(),
    	longitude => $self->longitude(),
    );
    $service->setServiceEventType($self->event_type()) if($self->event_type());
    $service->setCommunities($self->communities()) if($self->communities());
    $service->setAuthnType($self->authentication_type()) if($self->authentication_type());
    
    return $service;
}

sub checksum_prefix {
    return "service";
}

sub checksum_fields {
    return [
        "service_locator",
        "service_type",
        "service_name",
        "service_version",
        "service_host",
        "domain",
        "administrator",
        "site_name",
        "communities",
        "city",
        "region",
        "country",
        "zip_code",
        "latitude",
        "longitude",
        "authentication_type"
    ];
}

sub duplicate_checksum_fields {
    return [
        "service_locator",
        "service_type",
        "domain",
    ];
}

1;
