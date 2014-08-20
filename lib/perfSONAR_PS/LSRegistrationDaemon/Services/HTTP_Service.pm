package perfSONAR_PS::LSRegistrationDaemon::Services::HTTP_Service;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Services::HTTP_Service - The class provides basic generators
for HTTP services

=head1 DESCRIPTION

Abstract class for HTTP services

=cut

use strict;
use warnings;

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::Services::TCP_Service';

use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);

use constant DEFAULT_PORT => 80;

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


=head2 event_type($self)

Deprecatated.

=cut

sub event_type {
    my ( $self ) = @_;

    return "";
}

=head2 service_locator ($self)

This function returns the list of addresses for this service. This overrides
the TCP_Service service_locator function so that results are returned as
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
