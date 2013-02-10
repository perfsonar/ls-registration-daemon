package perfSONAR_PS::LSRegistrationDaemon::Ping;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Ping - The Ping class provides checks for
Ping responders.

=head1 DESCRIPTION

This module provides the request functions to check a service, and the
information necessary for the Base module to construct a ping service
instance. It is just a slim wrapper over the ICMP_Service module.

=cut

use strict;
use warnings;

our $VERSION = 3.3;

use base 'perfSONAR_PS::LSRegistrationDaemon::ICMP_Service';

=head2 type($self)

Returns the human readable description of the service "Ping Responder".

=cut

sub type {
    my ( $self ) = @_;

    return "Ping Responder";
}

=head2 service_type($self)

Returns the ping service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "ping";
}

=head2 event_type($self)

Returns the ping event type.

=cut

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/ping/1.0";
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::LSRegistrationDaemon::ICMP_Service>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

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
