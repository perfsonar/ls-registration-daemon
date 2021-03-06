package perfSONAR_PS::LSRegistrationDaemon::Services::MA;

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

use base 'perfSONAR_PS::LSRegistrationDaemon::Services::HTTP_Service';

use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);
use perfSONAR_PS::Client::Esmond::ApiFilters;
use perfSONAR_PS::Client::Esmond::ApiConnect;
use perfSONAR_PS::Client::Esmond::Metadata;
use perfSONAR_PS::LSRegistrationDaemon::PSMetadata;
use perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerFactory;

use fields 'SERVICE_EVENT_TYPES';

sub known_variables {
    my ($self) = @_;

    my @variables = $self->SUPER::known_variables();

    push @variables, (
        { variable => "autodiscover_ca_file", type => "scalar" },
        { variable => "autodiscover_ca_path", type => "scalar" },
        { variable => "autodiscover_index_time_range", type => "scalar" },
        { variable => "autodiscover_indices", type => "scalar" },
        { variable => "autodiscover_tests", type => "scalar" },
        { variable => "autodiscover_time_range", type => "scalar" },
        { variable => "autodiscover_url", type => "scalar" },
        { variable => "autodiscover_verify_hostname", type => "scalar" },
        { variable => "test", type => "array" },
    );

    return @variables;
}

=head2 init_dependencies($self)

Overridden method that initializes MA test registrations
=cut
sub init_dependencies {
    my ( $self ) = @_;
    my %service_event_type_map = ();
    
    #load tests
    my @ma_tests = ();
    my @discovered_tests = ();
    if($self->{CONF}->{test} && ref($self->{CONF}->{test}) ne 'ARRAY'){
        push @discovered_tests, $self->{CONF}->{test};
    }elsif($self->{CONF}->{test}){
        push @discovered_tests, @{$self->{CONF}->{test}};
    }

    #auto grab MA tests
    if($self->{CONF}->{'autodiscover_tests'}){
        #if we auto discover tests there is no manually setting allowed. This prevents memory leak.
        my $auto_url = $self->{CONF}->{'autodiscover_url'};
        my $indexer_factory = perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerFactory->new();
        my $indexer_time_range = $self->{CONF}->{'autodiscover_index_time_range'};
        $indexer_time_range = 86400 if(!$indexer_time_range); #default to 24 hours
        $auto_url = @{$self->service_locator()}[0] if(!$auto_url);
        if(!defined $self->{CONF}->{'autodiscover_indices'}){
            $self->{CONF}->{'autodiscover_indices'} = 1; #configure indices by default
        }
        my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(
            ca_certificate_file => $self->{CONF}->{'autodiscover_ca_file'},
            ca_certificate_path => $self->{CONF}->{'autodiscover_ca_path'},
            verify_hostname => $self->{CONF}->{'autodiscover_verify_hostname'},
        );
        if(!defined $self->{CONF}->{'autodiscover_time_range'}){
            $self->{CONF}->{'autodiscover_time_range'} = 86400*7; #default to 1 week
        }
        $filters->time_range($self->{CONF}->{'autodiscover_time_range'});
        my $client = new perfSONAR_PS::Client::Esmond::ApiConnect(url => $auto_url, filters => $filters );
        my $md = $client->get_metadata();
        if($client->error){
            $self->{LOGGER}->warn("Unable to get MA tests " . $client->error);
        }else{
            foreach my $m(@{$md}){
                #index results if possible            
                my @indices = ();
                if($self->{CONF}->{'autodiscover_indices'}){
                    foreach my $event_type(@{$m->event_types()}){
                        my $indexer = $indexer_factory->create_indexer($event_type);
                        next unless($indexer);
                        my $et = $m->get_event_type($event_type);
                        $et->filters->time_range($indexer_time_range);
                        my $data = $et->get_data();
                        next if($et->error);
                        my $values = $indexer->create_index($data);
                        push @indices, {
                            type => $event_type,
                            value => $values
                        };
                    }
                }
                #add new test
                push @discovered_tests, {
                    'ma_locator' => $self->service_locator(),
                    'metadata_uri' => $m->uri(),
                    'source' => $m->source(),
                    'destination' => $m->destination(),
                    'measurement_agent' => $m->measurement_agent(),
                    'tool_name' => $m->tool_name(),
                    'event_type' => $m->event_types(),
                    'result_index' => \@indices,
                };
            } 
        }
    }
    
    #Create metadata registrations
    foreach my $ma_test(@discovered_tests){
        my $ma_test_reg = perfSONAR_PS::LSRegistrationDaemon::PSMetadata->new();
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
    $self->{DEPENDENCIES} = \@ma_tests;

    return 0;
}

=head2 refresh($self)

Overridden method that detects new MA test registrations

=cut
sub refresh {
    my ( $self ) = @_;

    #if disabled then return
    if($self->{CONF}->{disabled}){
        return 0;
    }

    #grab any new metadata. this is a memory hog. saving for another day.
    #$self->init_dependencies();

    return $self->SUPER::refresh();
}

=head2 service_event_type($self)

Returns the service event types
=cut
sub service_event_type {
    my ( $self ) = @_;

    return $self->{'SERVICE_EVENT_TYPES'};
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

sub build_registration {
    my ( $self ) = @_;
    
    my $service = $self->SUPER::build_registration();
    $service->setServiceEventType($self->service_event_type());

    return $service;
}

sub checksum_fields {
    return [
        "service_locator",
        "service_type",
        "service_name",
        "service_event_type",
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
    ];    
}

sub duplicate_checksum_fields {
    return [
        "service_locator",
        "service_type",
        "service_event_type",
        "domain",
    ];
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::LSRegistrationDaemon::TCP_Service>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS git repository is located at:

  https://code.google.com/p/perfsonar-ps/

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
