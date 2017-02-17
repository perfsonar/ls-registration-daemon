package perfSONAR_PS::LSRegistrationDaemon::Services::MP_OWAMP;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Services::MP_OWAMP - This class provides checks for
measurement point services.

=head1 DESCRIPTION

Registers an MP service

=cut

use strict;
use warnings;

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::Services::HTTP_Service';

use Digest::MD5 qw(md5_base64);
use perfSONAR_PS::Common qw(mergeConfig);

use constant DEFAULT_PORT => 8090;

=head2 type($self)

Returns the human readable description of the service "Measurement Archive".

=cut

sub type {
    my ( $self ) = @_;

    return "OWAMP Measurement Point";
}

=head2 service_type($self)

Returns the MP service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "mp-owamp";
}

sub checksum_fields {
    return [
        "service_locator",
        "service_type",
        "service_name",
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
