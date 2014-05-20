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

use base 'perfSONAR_PS::LSRegistrationDaemon::Services::TCP_Service';

use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);
use perfSONAR_PS::Client::Esmond::ApiFilters;
use perfSONAR_PS::Client::Esmond::ApiConnect;
use perfSONAR_PS::Client::Esmond::Metadata;
use perfSONAR_PS::LSRegistrationDaemon::PSMetadata;
use perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerFactory;

use constant DEFAULT_PORT => 80;

use fields 'MA_TESTS', 'SERVICE_EVENT_TYPES';

=head2 init($self, $conf)

Sets the default port and provides generic service initializations
=cut

sub init {
    my ( $self, $conf ) = @_;
    
    if(!$conf->{port} && !$conf->{http_port} && !$conf->{https_port}){
        $conf->{port} = DEFAULT_PORT;
        $conf->{http_port} = DEFAULT_PORT;
    }elsif(!$conf->{port} && !$conf->{http_port}){
        $conf->{port} = $conf->{https_port};
    }elsif(!$conf->{port}){
        $conf->{port} = $conf->{http_port};
    }elsif(!$conf->{http_port}){
        $conf->{http_port} = $conf->{port};
    }

    return $self->SUPER::init( $conf );
}

=head2 init($self, $conf)

Overridden method that initializes MA test registrations
=cut
sub init_dependencies {
    my ( $self ) = @_;
    my %service_event_type_map = ();
    
    #load tests
    my @ma_tests = ();
    if(!$self->{CONF}->{test}){
        $self->{CONF}->{test} = [];
    }elsif($self->{CONF}->{test} && ref($self->{CONF}->{test}) ne 'ARRAY'){
        my @tmp = ();
        push @tmp, $self->{CONF}->{test};
        $self->{CONF}->{test} = \@tmp;
    }
    
    #auto grab MA tests
    if($self->{CONF}->{'auto_config_tests'}){
        my $auto_url = $self->{CONF}->{'auto_config_url'};
        my $indexer_factory = perfSONAR_PS::LSRegistrationDaemon::EventTypeIndexer::EventTypeIndexerFactory->new();
        my $indexer_time_range = $self->{CONF}->{'auto_config_index_time_range'};
        $indexer_time_range = 86400 if(!$indexer_time_range); #default to 24 hours
        $auto_url = @{$self->service_locator()}[0] if(!$auto_url);
        if(!defined $self->{CONF}->{'auto_config_indices'}){
            $self->{CONF}->{'auto_config_indices'} = 1; #configure indices by default
        }
        my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(
            ca_certificate_file => $self->{CONF}->{'auto_config_ca_file'},
            ca_certificate_path => $self->{CONF}->{'auto_config_ca_path'},
            verify_hostname => $self->{CONF}->{'auto_config_verify_hostname'},
        );
        $filters->time_range($self->{CONF}->{'auto_config_time_range'}) if($self->{CONF}->{'auto_config_time_range'});
        my $client = new perfSONAR_PS::Client::Esmond::ApiConnect(url => $auto_url, filters => $filters );
        my $md = $client->get_metadata();
        foreach my $m(@{$md}){
            #index results if possible            
            my @indices = ();
            if($self->{CONF}->{'auto_config_indices'}){
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
            #create new test
            push @{$self->{CONF}->{test}}, {
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
    
    foreach my $ma_test(@{$self->{CONF}->{test}}){
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
    $self->{MA_TESTS} = \@ma_tests;
    
    $self->{DEPENDENCIES} = $self->{MA_TESTS};

    return 0;
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

=head2 event_type($self)

Depreactated. MA does not have specific event_type so just returns empty string

=cut

sub event_type {
    my ( $self ) = @_;

    return "";
}

=head2 service_locator ($self)

This function returns the list of addresses for this service. This overrides
the TCP_Service service_locator function so that MA URLs are returned as
URLs.

=cut

sub service_locator {
    my ( $self ) = @_;

    my @addresses = ();
    
    #http port addrs
    if($self->{CONF}->{http_port} || ! $self->{CONF}->{https_port}){
        $self->_generate_service_url('http', $self->{CONF}->{http_port}, 80, \@addresses);
    }
    
    #https addrs
    if($self->{CONF}->{https_port}){
        $self->_generate_service_url('https', $self->{CONF}->{https_port}, 443, \@addresses);
    }

    return \@addresses;
}

sub _generate_service_url {
    my ($self, $proto, $port, $default_port, $addresses) = @_;
    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $uri = "${proto}://";
        if ( $addr =~ /:/ ) {
            $uri .= "[$addr]";
        } else {
            $uri .= "$addr";
        }

        $uri .= ":" . $port if($port != $default_port);
        $uri .= $self->{CONF}->{url_path} if($self->{CONF}->{url_path});

        push @{$addresses}, $uri;
    }
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
