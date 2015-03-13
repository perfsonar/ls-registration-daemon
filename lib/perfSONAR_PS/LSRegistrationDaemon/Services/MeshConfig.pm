package perfSONAR_PS::LSRegistrationDaemon::Services::MeshConfig;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::MeshConfig - The MeshConfig class provides checks for
mesh configuration files.

=head1 DESCRIPTION

This module provides the request functions to register a MeshConfig service, and the
information necessary for the Base module to construct an MeshConfig service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::Services::HTTP_Service';

use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);
use LWP::UserAgent;
use JSON qw(from_json);

sub known_variables {
    my ($self) = @_;

    my @variables = $self->SUPER::known_variables();

    push @variables, (
        { variable => "autodiscover_url", type => "scalar" },
        { variable => "autodiscover_ca_file", type => "scalar" },
        { variable => "autodiscover_ca_path", type => "scalar" },
        { variable => "autodiscover_verify_hostname", type => "scalar" },
        { variable => "autodiscover_fields", type => "scalar" },
        { variable => "autodiscover_timeout", type => "scalar" },
        { variable => "skip_autodiscover_admins", type => "scalar" },
        { variable => "test_member", type => "array" },
    );

    return @variables;
}

=head2 init_dependencies($self)

Overridden method that initializes MA test registrations
=cut
sub init_dependencies {
    my ( $self ) = @_;
    
    #if we don't need to autodiscover, then nothing to do
    if(!$self->{CONF}->{'autodiscover_fields'}){
        return 0;
    }
    
    #build user agent
    my $ua = LWP::UserAgent->new;
    if defined ($self->{CONF}->{'autodiscover_timeout'}){
        $ua->timeout($self->{CONF}->{'autodiscover_timeout'});
    }else{
        $ua->timeout(60);#default to 60 seconds
    }
    $ua->env_proxy();
    $client->ssl_opts(verify_hostname => $self->{CONF}->{'autodiscover_verify_hostname'}) if defined ($self->{CONF}->{'autodiscover_verify_hostname'});
    $client->ssl_opts(SSL_ca_file => $self->{CONF}->{'autodiscover_ca_certificate_file'}) if($self->{CONF}->{'autodiscover_ca_certificate_file'});
    $client->ssl_opts(SSL_ca_path => $self->{CONF}->{'autodiscover_ca_certificate_path'}) if($self->{CONF}->{'autodiscover_ca_certificate_path'});
    
    #Determine URL
    my $autodiscover_urls =  [];
    if($self->{CONF}->{'autodiscover_url'}){
        $autodiscover_urls = [ $self->{CONF}->{'autodiscover_url'} ];
    }else{
        $autodiscover_urls = $self->service_locator();
    }
    
    #grab JSON
    my $mesh_json = '';
    foreach my $autodiscover_url(@{$autodiscover_urls}){
        my $response = $ua->get($autodiscover_url);
        if ($response->is_success) {
            $mesh_json = from_json($response->content);
            last;
        }else {
            $self->{LOGGER}->warn("Trying next MeshConfig URL. $autodiscover_url returned" . $response->status_line);
        }
    }
        
    #parse JSON
    unless $mesh_json{
        $self->{LOGGER}->error("Unable to download MeshConfig file. Autodiscovery failed. Proceeding without autodiscovered information");
        return 0;
    }
    
    #get description and set to service name
    $self->{CONF}->{service_name} = $mesh_json->{description} if($mesh_json->{description});
    
    #get test members
    my %address_map = ();
    if($mesh_json->{'organizations'}){
        foreach my $organization(@{$mesh_json->{'organizations'}}){
            if($organization->{'sites'}){
                foreach my $site(@{$organization->{'sites'}}){
                    if($site->{'hosts'}){
                        foreach my $host(@{$site->{'hosts'}}){
                            if($host->{'addresses'}){
                                foreach my $addr(@{$host->{'addresses'}}){
                                    $address_map{$addr} = 1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    my @test_members = keys %address_map;
    $self->{CONF}->{'test_member'} = \@test_members;
    
    #get administrators
    if($mesh_json->{'administrators'} && !$self->{CONF}->{'skip_autodiscover_admins'}){
        foreach my $admins(@{$mesh_json->{'administrators'}}){
            #only allow one administrator in LS reg at the moment
            #have skip option in case people don't like the one that gets picked
            if($admins->{'name'} && $admins->{'email'}){ 
                $self->{CONF}->{administrator} = {
                    'name' => $admins->{'name'},
                    'email' => $admins->{'email'},
                };
                last;
            }
        }
    }
    
    return 0;
}



=head2 test_member($self)

Returns the test members in the file's meshes
=cut
sub test_member {
    my ( $self ) = @_;

    return $self->{CONF}->{'test_member'};
}

=head2 type($self)

Returns the human readable description of the service "Measurement Archive".

=cut

sub type {
    my ( $self ) = @_;

    return "MeshConfig";
}

=head2 service_type($self)

Returns the MA service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "meshconfig";
}

sub build_registration {
    my ( $self ) = @_;
    
    my $service = $self->SUPER::build_registration();
    $service->addField(key=>'service-meshconfig-member', value=> $self->test_member()) if($self->test_member());

    return $service;
}

sub checksum_fields {
    return [
        "service_locator",
        "service_type",
        "service_name",
        "test_member",
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
