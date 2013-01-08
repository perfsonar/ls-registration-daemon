package perfSONAR_PS::LSRegistrationDaemon::Service;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Client::LS::PSRecords::PSService;

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    
    return $self->SUPER::init( $conf );
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

sub service_version {
    my ( $self ) = @_;

    return $self->{CONF}->{service_version};
}

sub service_locator {
    my ( $self ) = @_;

    return $self->{CONF}->{service_locator};
}


sub domain {
    my ( $self ) = @_;

    return $self->{CONF}->{domain};
}

sub administrator {
    my ( $self ) = @_;

    return $self->{CONF}->{administrator};
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
    $service->setServiceEventType($self->event_type());
    $service->setCommunities($self->communities());
    
    return $service;
}

sub build_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'service::'; #add prefix to distinguish from other types
    $checksum .= $self->_add_checksum_val($self->service_locator()); 
    $checksum .= $self->_add_checksum_val($self->service_type()); 
    $checksum .= $self->_add_checksum_val($self->service_name()); 
    $checksum .= $self->_add_checksum_val($self->service_version()); 
    $checksum .= $self->_add_checksum_val($self->domain());
    $checksum .= $self->_add_checksum_val($self->administrator()); 
    $checksum .= $self->_add_checksum_val($self->site_name());
    $checksum .= $self->_add_checksum_val($self->communities());
    $checksum .= $self->_add_checksum_val($self->city());
    $checksum .= $self->_add_checksum_val($self->region());
    $checksum .= $self->_add_checksum_val($self->country());
    $checksum .= $self->_add_checksum_val($self->zip_code());
    $checksum .= $self->_add_checksum_val($self->latitude());
    $checksum .= $self->_add_checksum_val($self->longitude());
    
    $checksum = md5_base64($checksum);
    $self->{LOGGER}->info("Checksum is " . $checksum);
    
    return  $checksum;
}

sub build_duplicate_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'service::';#add prefix to distinguish from other types
    $checksum .= $self->_add_checksum_val($self->service_locator()); 
    $checksum .= $self->_add_checksum_val($self->service_type());  
    $checksum .= $self->_add_checksum_val($self->domain());
    
    $checksum = md5_base64($checksum);
    $self->{LOGGER}->info("Duplicate checksum is " . $checksum);
    
    return  $checksum;
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