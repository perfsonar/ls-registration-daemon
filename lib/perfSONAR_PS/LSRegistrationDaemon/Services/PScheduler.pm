package perfSONAR_PS::LSRegistrationDaemon::Services::PScheduler;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::PScheduler - The PScheduler class provides checks for
pSceduler services.

=head1 DESCRIPTION

This module provides the request functions to check an pScheduler service, and the
information necessary for the Base module to construct an pScheduler service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::Services::HTTPS_Service';

use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);
use perfSONAR_PS::Client::PScheduler::ApiConnect;
use perfSONAR_PS::Client::PScheduler::ApiFilters;

sub known_variables {
    my ($self) = @_;

    my @variables = $self->SUPER::known_variables();

    push @variables, (
        { variable => "autodiscover_ca_file", type => "scalar" },
        { variable => "autodiscover_ca_path", type => "scalar" },
        { variable => "autodiscover_tests", type => "scalar" },
        { variable => "autodiscover_tools", type => "scalar" },
        { variable => "autodiscover_url", type => "scalar" },
        { variable => "autodiscover_verify_hostname", type => "scalar" },
        { variable => "test", type => "array" },
        { variable => "tool", type => "array" },
    );

    return @variables;
}

=head2 init($self, $conf)

Gets pScheduler specific fields
=cut

sub init {
    my ( $self, $conf ) = @_;
    
    #init super first
    my $init_result = $self->SUPER::init( $conf );
    return $init_result if($init_result != 0);
    
    #Autodiscover tools and test types
    if($conf->{'autodiscover_tests'} || $conf->{'autodiscover_tools'} ){
        my $auto_url = $conf->{'autodiscover_url'};
        $auto_url = @{$self->service_locator()}[0] if(!$auto_url);
        my $filters = new perfSONAR_PS::Client::PScheduler::ApiFilters(
                ca_certificate_file => $conf->{'autodiscover_ca_file'},
                ca_certificate_path => $conf->{'autodiscover_ca_path'},
                verify_hostname => $conf->{'autodiscover_verify_hostname'},
            );
        my $client = new perfSONAR_PS::Client::PScheduler::ApiConnect("url" => $auto_url, "filters" => $filters);
        if($conf->{'autodiscover_tests'}){
            my $tests =  $client->get_tests();
            if($client->error()){
                $self->{LOGGER}->warn("Unable to get pScheduler test types: " . $client->error);
            }else{
                $conf->{test} = [];
                foreach my $test(@{$tests}){
                    push @{$conf->{test}}, $test->name();
                }
            }
        }
        if($conf->{'autodiscover_tools'}){
            my $tools =  $client->get_tools();
            if($client->error()){
                $self->{LOGGER}->warn("Unable to get pScheduler tool list: " . $client->error);
            }else{
                $conf->{tool} = [];
                foreach my $tool(@{$tools}){
                    push @{$conf->{tool}}, $tool->name();
                }
            }
        }
    }
    
    return 0;
}

=head2 type($self)

Returns the human readable description of the service "pScheduler".

=cut

sub type {
    my ( $self ) = @_;

    return "pScheduler";
}

=head2 service_type($self)

Returns the pScheduler service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "pscheduler";
}

=head2 tool($self)

Returns the tools pScheduler supports
=cut
sub tool {
    my ( $self ) = @_;

    return $self->{CONF}->{'tool'};
}

=head2 test($self)

Returns the tests pScheduler supports
=cut
sub test {
    my ( $self ) = @_;

    return $self->{CONF}->{'test'};
}

sub build_registration {
    my ( $self ) = @_;
    
    my $service = $self->SUPER::build_registration();
    $service->setPSchedulerTests($self->test()) if($self->test());
    $service->setPSchedulerTools($self->tool()) if($self->tool());

    return $service;
}

sub checksum_fields {
    return [
        "service_locator",
        "service_type",
        "service_name",
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
        "test",
        "tool"
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
