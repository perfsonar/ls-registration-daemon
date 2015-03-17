package perfSONAR_PS::LSRegistrationDaemon::Services::Dashboard;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Dashboard - The Dashboard class provides checks for
dashboard services such as MaDDash.

=head1 DESCRIPTION

This module provides the request functions to check a dashboard service, and the
information necessary for the Base module to construct an dashboard service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::Services::HTTP_Service';

use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);

sub known_variables {
    my ($self) = @_;

    my @variables = $self->SUPER::known_variables();

    push @variables, (
        { variable => "webui_url", type => "array" },
        { variable => "autodiscover_webui_url", type => "scalar" },
    );

    return @variables;
}


=head2 type($self)

Returns the human readable description of the service "Dashboard".

=cut

sub type {
    my ( $self ) = @_;

    return "Dashboard";
}

=head2 service_type($self)

Returns the MA service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "dashboard";
}

=head2 service_type($self)

Returns the web UI URL

=cut

sub webui_url {
    my ( $self ) = @_;
    
    if($self->{CONF}->{autodiscover_webui_url}){
        my @addresses = ();
        
        if($self->{CONF}->{http_port} || ! $self->{CONF}->{https_port}){
            $self->_generate_webui_url('http', $self->{CONF}->{http_port}, 80, \@addresses);
        }
    
        #https addrs
        if($self->{CONF}->{https_port}){
            $self->_generate_webui_url('https', $self->{CONF}->{https_port}, 443, \@addresses);
        }
        
        return \@addresses;
    }
    
    return $self->{CONF}->{webui_url};
}

sub _generate_webui_url {
    my ($self, $proto, $port, $default_port, $addresses) = @_;
    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $uri = "${proto}://";
        if ( $addr =~ /:/ ) {
            $uri .= "[$addr]";
        } else {
            $uri .= "$addr";
        }

        $uri .= ":" . $port if($port != $default_port);
        $uri .= '/maddash-webui'; #assume standard MaDDash location

        push @{$addresses}, $uri;
    }
}

sub build_registration {
    my ( $self ) = @_;
    
    my $service = $self->SUPER::build_registration();
    $service->addField(key=>'service-webui-url', value=> $self->webui_url()) if($self->webui_url());

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
        "webui_url",
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
