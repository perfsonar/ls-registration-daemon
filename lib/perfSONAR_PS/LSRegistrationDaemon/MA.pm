package perfSONAR_PS::LSRegistrationDaemon::MA;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::MA - The MA class provides checks for
measurement archive services.

=head1 DESCRIPTION

This module provides the request functions to check an MA service, and the
information necessary for the Base module to construct an MA service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);
use perfSONAR_PS::LSRegistrationDaemon::PSTest;

use constant DEFAULT_PORT => 8085;

use fields 'MA_TESTS', 'SERVICE_EVENT_TYPES';

=head2 init($self, $conf)

Sets the default port and provides generic service initializations
=cut

sub init {
    my ( $self, $conf ) = @_;

    my $port = $conf->{port};
    if ( not $port ) {
        $conf->{port} = DEFAULT_PORT;
    }

    return $self->SUPER::init( $conf );
}

=head2 init($self, $conf)

Overridden method that initializes MA test registrations
=cut
sub init_children {
    my ( $self ) = @_;
    my %service_event_type_map = ();
    
    $self->SUPER::init_children();
    
    #create tests
    my @ma_tests = ();
    if($self->{CONF}->{test} && ref($self->{CONF}->{test}) ne 'ARRAY'){
        my @tmp = ();
        push @tmp, $self->{CONF}->{test};
        $self->{CONF}->{test} = \@tmp;
    }
    foreach my $ma_test(@{$self->{CONF}->{test}}){
        my $ma_test_reg = perfSONAR_PS::LSRegistrationDaemon::PSTest->new();
        if( $ma_test_reg->init(mergeConfig($self->{CONF}, $ma_test)) == 0){
            push @ma_tests, $ma_test_reg;
        }
        
        #capture MA event type
        if($ma_test->{event_type} && ref($ma_test->{event_type}) ne 'ARRAY'){
            my @tmp = ();
            push @tmp, $ma_test->{event_type};
            $ma_test->{event_type} = \@tmp;
        }
        foreach my $et(@{$ma_test->{event_type}}){
            $service_event_type_map{$et} = 1;
        } 
    }
    
    #set ma type
    my @tmp_ets = keys %service_event_type_map;
    $self->{'SERVICE_EVENT_TYPES'} = \@tmp_ets;
    $self->{MA_TESTS} = \@ma_tests;
    
    $self->{CHILD_REGISTRATIONS} = $self->{MA_TESTS};
}


=head2 service_event_type($self)

Returns the service event types
=cut
sub service_event_type {
    my ( $self ) = @_;

    return $self->{'SERVICE_EVENT_TYPES'};
}

=head2 service_event_type($self)

Returns the MA types
=cut
sub ma_type {
    my ( $self ) = @_;

    return $self->{CONF}->{ma_type};
}

=head2 service_event_type($self)

Returns the MA types
=cut
sub ma_tests {
    my ( $self ) = @_;

    my @tests = map {$_->{"KEY"}} @{$self->{MA_TESTS}};
    return \@tests; 
}



=head2 get_service_addresses ($self)

This function returns the list of addresses for this service. This overrides
the TCP_Service get_service_addresses function so that MA URLs are returned as
URLs.

=cut

sub get_service_addresses {
    my ( $self ) = @_;

    my @addresses = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $uri;

        $uri = "http://";
        if ( $addr =~ /:/ ) {
            $uri .= "[$addr]";
        }
        else {
            $uri .= "$addr";
        }

        $uri .= ":" . $self->{PORT};

        my %addr = ();
        $addr{"value"} = $uri;
        $addr{"type"}  = "url";

        push @addresses, \%addr;
    }

    return \@addresses;
}

=head2 type($self)

Returns the human readable description of the service "Measurement Archive".

=cut

sub type {
    my ( $self ) = @_;

    return "Measurement Archive";
}

=head2 service_type($self)

Returns the MA service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "ma";
}

=head2 event_type($self)

Depreactated. MA does not have specific event_type so just returns empty string

=cut

sub event_type {
    my ( $self ) = @_;

    return "";
}

sub build_registration {
    my ( $self ) = @_;
    
    my $service = $self->SUPER::build_registration();
    $service->setServiceEventType($self->service_event_type());
    $service->setMAType($self->ma_type());
    $service->setMATests($self->ma_tests());

    return $service;
}

sub build_checksum {
    my ( $self ) = @_;
    
    my $checksum = 'service::'; #add prefix to distinguish from other types
    $checksum .= $self->_add_checksum_val($self->service_locator()); 
    $checksum .= $self->_add_checksum_val($self->service_type()); 
    $checksum .= $self->_add_checksum_val($self->service_name()); 
    $checksum .= $self->_add_checksum_val($self->service_event_type()); 
    $checksum .= $self->_add_checksum_val($self->ma_type()); 
    $checksum .= $self->_add_checksum_val($self->ma_tests()); 
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

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::LSRegistrationDaemon::TCP_Service>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: MA.pm 5533 2013-02-10 06:28:27Z asides $

=head1 AUTHOR

Andy Lake, andy@es.net
Aaron Brown, aaron@internet2.edu

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2007-2010, Internet2

All rights reserved.

=cut
