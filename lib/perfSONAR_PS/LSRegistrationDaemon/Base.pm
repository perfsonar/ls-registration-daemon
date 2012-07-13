package perfSONAR_PS::LSRegistrationDaemon::Base;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Base - The Base class from which all LS
Registration Agents inherit.

=head1 DESCRIPTION

This module provides the Base for all the LS Registration Agents. It includes
most of the common components, like service checking, LS message construction
and LS registration. The Agents implement the functions specific to them, like
service status checking or event type.

=cut

use strict;
use warnings;

our $VERSION = 3.2;

use Log::Log4perl qw/get_logger/;

use perfSONAR_PS::Utils::DNS qw(reverse_dns);
use perfSONAR_PS::Client::LS::REST;
use perfSONAR_PS::Client::LS::Requests::Registration;

use fields 'CONF', 'STATUS', 'LOGGER', 'KEY', 'NEXT_REFRESH', 'LS_CLIENT';

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=cut

=head2 new()

This call instantiates new objects. The object's "init" function must be called
before any interaction can occur.

=cut

sub new {
    my $class = shift;

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( $class );

    return $self;
}

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash. It allocates an LS client, and sets its status to
"UNREGISTERED".

=cut

sub init {
    my ( $self, $conf ) = @_;

    $self->{CONF}   = $conf;
    $self->{STATUS} = "UNREGISTERED";
    $self->{LS_CLIENT} = new perfSONAR_PS::Client::LS::REST();

    if ($self->{CONF}->{require_site_name} and not $self->{CONF}->{site_name}) {
    	$self->{LOGGER}->error("site_name is a required configuration option");
    	return -1;
    }

    if ($self->{CONF}->{require_site_location} and not $self->{CONF}->{site_location}) {
    	$self->{LOGGER}->error("site_location is a required configuration option");
    	return -1;
    }

    return 0;
}

=head2 service_name ($self)

This internal function generates the name to register this service as. It calls
the object-specific function "type" when creating the function.

=cut

sub service_name {
    my ( $self ) = @_;

    if ( $self->{CONF}->{service_name} ) {
        return $self->{CONF}->{service_name};
    }

    my $retval = q{};
    if ( $self->{CONF}->{site_name} ) {
        $retval .= $self->{CONF}->{site_name} . " ";
    }
    $retval .= $self->type();

    return $retval;
}

=head2 service_name ($self)

This internal function generates the human-readable description of the service
to register. It calls the object-specific function "type" when creating the
function.

=cut

sub service_desc {
    my ( $self ) = @_;

    if ( $self->{CONF}->{service_name} ) {
        return $self->{CONF}->{service_name};
    }

    my $retval = $self->type();
    if ( $self->{CONF}->{site_name} ) {
        $retval .= " at " . $self->{CONF}->{site_name};
    }

    if ( $self->{CONF}->{site_location} ) {
        $retval .= " in " . $self->{CONF}->{site_location};
    }

    return $retval;
}

=head2 refresh ($self)

This function is called by the daemon. It checks if the service is up, and if
so, checks if it should regster the service or send a keepalive to the Lookup
Service. If not, it unregisters the service from the Lookup Service.

=cut

sub refresh {
    my ( $self ) = @_;

    if ( $self->{STATUS} eq "BROKEN" ) {
        $self->{LOGGER}->error( "Refreshing misconfigured service: ".$self->service_desc );
        return;
    }

    $self->{LOGGER}->debug( "Refreshing: " . $self->service_desc );

    if ( $self->is_up ) {
        $self->{LOGGER}->debug( "Service is up" );
        if ( $self->{STATUS} ne "REGISTERED" ) {
            $self->{LOGGER}->info( "Service '".$self->service_desc."' is up, registering" );
            $self->register();
        }
        elsif ( time >= $self->{NEXT_REFRESH} ) {
            $self->{LOGGER}->info( "Service '".$self->service_desc."' is up, refreshing registration" );
            $self->keepalive();
        }
        else {
            $self->{LOGGER}->debug( "No need to refresh" );
        }
    }
    elsif ( $self->{STATUS} eq "REGISTERED" ) {
        $self->{LOGGER}->info( "Service '".$self->service_desc."' is down, unregistering" );
        $self->unregister();
    }
    else {
        $self->{LOGGER}->info( "Service '".$self->service_desc."' is down" );
    }

    return;
}

=head2 register ($self)

This function is called by the refresh function. This creates
a brand new registration in the Lookup Service

=cut
sub register {
    my ( $self ) = @_;

    my $addresses = $self->get_service_addresses();
    my $projects = $self->{CONF}->{site_project};
    
    #convert projects to an array
    if ( $projects ) {
        unless ( ref( $projects ) eq "ARRAY" ) {
            $projects = [ $projects ];
        }
    }
    
    my @addressList = map { $_->{value} } @{$addresses};
    
    my $reg = new perfSONAR_PS::Client::LS::Requests::Registration();
    $reg->init({
        domain => $projects,
        locator => \@addressList,
        type => $self->service_type()
    });
    $reg->setServiceName([$self->service_name()]);
    $reg->setServiceSiteLocation([$self->service_desc()]);

    #Register
    my ($resCode, $res) = $self->{LS_CLIENT}->register({ registration => $reg, uri => $self->{CONF}->{ls_instance} });

    if($resCode == 0){
        $self->{LOGGER}->debug( "Registration succeeded with uri: " . $res->{"uri"} );
        $self->{STATUS}       = "REGISTERED";
        $self->{KEY}          = $res->{"uri"};
        $self->{NEXT_REFRESH} = $res->{"expires_unixtime"} - 300; # renew 5 minutes before expiration
    }else{
        $self->{LOGGER}->error( "Problem registering service. Will retry full registration next time: " . $res->{message} );
    }
    
    return;
}

=head2 keepalive ($self)

This function is called by the refresh function. It uses the saved KEY from the
Lookup Service registration, and sends an renew request to the Lookup
Service.

=cut
sub keepalive {
    my ( $self ) = @_;
    my ($resCode, $res) = $self->{LS_CLIENT}->renew({ uri => $self->{KEY}, base => $self->{CONF}->{ls_instance} });
    if ( $resCode == 0 ) {
        $self->{NEXT_REFRESH} = $res->{"expires_unixtime"} - 300; # renew 5 minutes before expiration
    }
    else {
        $self->{STATUS} = "UNREGISTERED";
        $self->{LOGGER}->error( "Couldn't send Keepalive. Will send full registration next time." );
    }

    return;
}


=head2 unregister ($self)

This function is called by the refresh function. It uses the saved KEY from the
Lookup Service registration, and sends an unregister request to the Lookup
Service.

=cut
sub unregister {
    my ( $self ) = @_;

    $self->{LS_CLIENT}->unregister({ uri => $self->{KEY}, base => $self->{CONF}->{ls_instance} });
    $self->{STATUS} = "UNREGISTERED";
    
    return;
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<perfSONAR_PS::Utils::DNS>,
L<perfSONAR_PS::Client::LS>

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
