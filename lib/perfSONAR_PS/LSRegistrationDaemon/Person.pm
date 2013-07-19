package perfSONAR_PS::LSRegistrationDaemon::Person;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use perfSONAR_PS::Client::LS::PSRecords::PSPerson;
use perfSONAR_PS::Client::LS::PSQueryObjects::PSPersonQueryObject;
use SimpleLookupService::Client::Query;
use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);

use fields 'INTERFACES';

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    if(!$conf->{full_name} && $conf->{administrator_email}){
        $conf->{full_name} = $conf->{administrator_email};
    }elsif(!$conf->{full_name}){
        $self->{LOGGER}->error("full_name or administrator_email is a required configuration option");
    	return -1;
    }
    
    return $self->SUPER::init( $conf );
}

##
# Overload to lookup contact prior to trying to register
sub refresh {
    my ( $self ) = @_;
    
    #lookup host
    my $person_query = perfSONAR_PS::Client::LS::PSQueryObjects::PSPersonQueryObject->new();
    $person_query->init();
    $person_query->setPersonName($self->name());
    $person_query->setEmailAddresses($self->email());
    
    my $query_client = SimpleLookupService::Client::Query->new();
    $query_client->init(server => $self->{LS_CLIENT}, query => $person_query);
    my($result_code, $results) = $query_client->query();
    if($result_code != 0 || @{$results} == 0){
        #not found
        $self->{STATUS} = 'UNREGISTERED';
        $self->{NEXT_REFRESH} = 0 if($self->{NEXT_REFRESH} == -1);
    }elsif($self->{KEY}){
        #found and we already have a uri
        my $last_uri = '';
        foreach my $person(@{$results}){
            $last_uri = $person->getRecordUri();
            last if($last_uri eq $self->{KEY});
        }
        if($last_uri ne $self->{KEY}){
            $self->delete_key();
            $self->{KEY} = $last_uri;
            $self->add_key();
        }
    }else{
        #found and we have never seen before
         $self->{KEY} = $results->[0]->getRecordUri();
         $self->{NEXT_REFRESH} = -1; #this means someone else registered it
    }
    
    $self->SUPER::refresh() if($self->{NEXT_REFRESH} != -1);
}

sub is_up {
    #die "Subclass must implement is_up"; 
    return 1;
}


sub description {
    my ( $self ) = @_;

    return $self->name() . '';
}

sub name {
    my ( $self ) = @_;

    return $self->{CONF}->{full_name};
}


sub email {
    my ( $self ) = @_;

    return $self->{CONF}->{administrator_email};
}

sub phone_numbers {
    my ( $self ) = @_;

    return $self->{CONF}->{administrator_phone};
}

sub organization {
    my ( $self ) = @_;

    return $self->{CONF}->{administrator_organization};
}

sub site_name {
    my ( $self ) = @_;

    return $self->{CONF}->{site_name};
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
    
    my $person = new perfSONAR_PS::Client::LS::PSRecords::PSPerson();
    $person->init(
        personName => $self->name(),
        emails => $self->email()
    );
    if(defined $self->phone_numbers()){
        $person->setPhoneNumbers($self->phone_numbers());
    }
    if(defined $self->organization()){
        $person->setOrganization($self->organization());
    }
    if(defined $self->site_name()){
        $person->setSiteName($self->site_name());
    }
    if(defined $self->city()){
        $person->setCity($self->city());
    }
    if(defined $self->region()){
        $person->setRegion($self->region());
    }
    if(defined $self->country()){
        $person->setCountry($self->country());
    }
    if(defined $self->zip_code()){
        $person->setZipCode($self->zip_code());
    }
    if(defined $self->latitude()){
        $person->setLatitude($self->latitude());
    }
    if(defined $self->longitude()){
        $person->setLongitude($self->longitude());
    }
    
    return $person;
}

sub build_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'person::';
    $checksum .= $self->_add_checksum_val($self->name()); 
    $checksum .= $self->_add_checksum_val($self->email()); 
    $checksum .= $self->_add_checksum_val($self->phone_numbers()); 
    $checksum .= $self->_add_checksum_val($self->organization()); 
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
    
    my $checksum = 'person::';
    $checksum .= $self->_add_checksum_val($self->name()); 
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
