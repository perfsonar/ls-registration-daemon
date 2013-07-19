package perfSONAR_PS::LSRegistrationDaemon::PSTest;

use strict;
use warnings;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';
use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Client::LS::PSRecords::PSTest;
use perfSONAR_PS::Common qw(mergeConfig);

use fields 'SOURCE', 'DESTINATION';

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash.
=cut
sub init {
    my ( $self, $conf ) = @_;
    
    if(!$conf->{source}){
        $self->{LOGGER}->error("Must specify source for test");
        return -1;
    }
    if(!$conf->{destination}){
        $self->{LOGGER}->error("Must specify destination for test");
        return -1;
    }
    if(!$conf->{event_type}){
        $self->{LOGGER}->error("Must specify event_type for test");
        return -1;
    }
    if(!$conf->{source_if_name}){
        $conf->{source_if_name} = "iface:" . $conf->{source};
    }
    if(!$conf->{destination_if_name}){
        $conf->{destination_if_name} = "iface:" . $conf->{destination};
    }
    
    return $self->SUPER::init( $conf );
}

sub init_children {
    my ( $self ) = @_;
    $self->SUPER::init_children();
    my @child_registrations = ();
    
    #determine if source already registered
    if($self->{CONF}->{register_source}){
        $self->{SOURCE} = perfSONAR_PS::LSRegistrationDaemon::Interface->new();
        $self->{SOURCE}->init(mergeConfig($self->{CONF}, {
            if_name => $self->{CONF}->{source_if_name},
            address => $self->{CONF}->{source}
        }));
        push @child_registrations, $self->{SOURCE};
    }

    #determine if destination already registered
    if($self->{CONF}->{register_destination}){
        $self->{DESTINATION} = perfSONAR_PS::LSRegistrationDaemon::Interface->new();
        $self->{DESTINATION}->init(mergeConfig($self->{CONF}, {
            if_name => $self->{CONF}->{destination_if_name},
            address => $self->{CONF}->{destination}
        }));
        push @child_registrations, $self->{DESTINATION};
    }

    $self->{CHILD_REGISTRATIONS} = \@child_registrations;
}


sub is_up {
    return 1;
}

sub description {
    my ( $self ) = @_;

    return $self->test_name();
}
            
sub test_name {
    my ( $self ) = @_;

    return $self->_add_checksum_val($self->{CONF}->{source}) . '-' . $self->_add_checksum_val($self->{CONF}->{destination}) ;
}

sub source_key {
    my ( $self ) = @_;
    
    #if child registered it, then return key
    if($self->{SOURCE}){
        return $self->{SOURCE}->{KEY};
    } 
    
    #otherwise lookup in db
    my $source = perfSONAR_PS::LSRegistrationDaemon::Interface->new();
    $source->init(mergeConfig($self->{CONF}, {
        if_name => $self->{CONF}->{source_if_name},
        address => $self->{CONF}->{source},
        disabled => 1
    }));
      
    return $source->find_duplicate();
}

sub destination_key {
    my ( $self ) = @_;

    #if child registered it, then return key
    if($self->{DESTINATION}){
        return $self->{DESTINATION}->{KEY};
    } 
    
    #otherwise lookup in db
    my $destination = perfSONAR_PS::LSRegistrationDaemon::Interface->new();
    $destination->init(mergeConfig($self->{CONF}, {
        if_name => $self->{CONF}->{destination_if_name},
        address => $self->{CONF}->{destination},
        disabled => 1
    }));
      
    return $destination->find_duplicate();
}

sub source {
    my ( $self ) = @_;

    return $self->{CONF}->{source};
}

sub destination {
    my ( $self ) = @_;

    return $self->{CONF}->{destination};
}

sub event_type {
    my ( $self ) = @_;

    return $self->{CONF}->{event_type};
}

sub build_registration {
    my ( $self ) = @_;
    
    my $pstest = new perfSONAR_PS::Client::LS::PSRecords::PSTest();
    $pstest->init(
            eventType => $self->event_type(), 
            source => $self->source_key(), 
            destination => $self->destination_key(), 
            testname => $self->test_name()
    );
    
    return $pstest;
}

sub build_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'pstest::';
    $checksum .= $self->_add_checksum_val($self->test_name()); 
    $checksum .= $self->_add_checksum_val($self->event_type()); 
    $checksum .= $self->_add_checksum_val($self->source_key()); 
    $checksum .= $self->_add_checksum_val($self->destination_key()); 
    
    $checksum = md5_base64($checksum);
    $self->{LOGGER}->info("Checksum is " . $checksum);
    
    return  $checksum;
}

sub build_duplicate_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'pstest::';
    $checksum .= $self->_add_checksum_val($self->test_name()); 
    $checksum .= $self->_add_checksum_val($self->event_type()); 
    
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
