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
use Digest::MD5 qw(md5_base64);

use fields 'CONF', 'STATUS', 'LOGGER', 'KEY', 'KEY_DB_HASH', 'NEXT_REFRESH', 'LS_CLIENT';

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
    
    #calculate hash
    my $reg_hash = $self->_buildRegistration()->getRegHash();
    my $hash_input = '';
    foreach my $regFieldName(keys %{$reg_hash}){
        $hash_input .= $regFieldName . "__" . $reg_hash->{$regFieldName};
    }
    $self->{KEY_DB_HASH} = md5_base64($hash_input);
    $self->{LOGGER}->info("KEY_DB_HASH = " . $self->{KEY_DB_HASH} . "\n");
    
    #check if in database
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $conf->{"ls_key_db"}, '', '');
    $self->{KEY} = $self->find_key($dbh);
    #if not in DB, determine if already registered˙
    if(!$self->{KEY}){
        my($returnCode, $searchResults) = $self->{LS_CLIENT}->query({
            uri => $self->{CONF}->{ls_instance},
            search_params => $self->_buildRegistration()->getRegHash(),
        });
        if($returnCode == 0 && $searchResults && $searchResults->{'results'} && 
            @{$searchResults->{'results'}} > 0 && $searchResults->{'results'}->[0]->{'record-uri'}){
            $self->{LOGGER}->info("Service already in LS, saving key: " . $searchResults->{'results'}->[0]->{'record-uri'} . "\n");
            $self->{STATUS} = "REGISTERED";
            $self->{KEY} = $searchResults->{'results'}->[0]->{'record-uri'};
            $self->save_key($dbh, $self->{KEY}, 0);
            $self->{NEXT_REFRESH} = 0;
        }else{
            $self->{LOGGER}->info("Service not yet registered in LS\n");
        }
    }
    #close db
    $dbh->disconnect();
    
    return 0;
}

sub find_key {
    my ($self, $dbh) = @_;
    my $uri = '';
    my $sth  = $dbh->prepare('SELECT uri FROM lsKeys WHERE regHash=?');
    $sth->bind_param(1, $self->{KEY_DB_HASH});
    $sth->execute();
    if($sth->err){
        $self->{LOGGER}->warn( "Error looking for key: " . $sth->errstr );
    }
    while( my @row = $sth->fetchrow_array){
        $uri = $row[0];
        $self->{LOGGER}->info("find_key.key: " .  $self->{KEY});
        last;
    }
    
    return $uri;
}

sub save_key {
    my ($self, $dbh, $key, $update_id) = @_;
    
    #check if key exists
    my $sth = '';
    #save key to database
    if($update_id && $self->find_key($dbh)){
        $sth = $dbh->prepare('UPDATE lsKeys SET uri=?, update_id=? WHERE lsRegKey=?');
        $sth->bind_param(1, $key);
        $sth->bind_param(2, $update_id);
        $sth->bind_param(3, $self->{KEY_DB_HASH});
    }else{
        $sth = $dbh->prepare('INSERT INTO lsKeys VALUES(?, ?, ?)');
        $sth->bind_param(1, $self->{KEY_DB_HASH});
        $sth->bind_param(2, $key);
        $sth->bind_param(3, $update_id);
    }
    $sth->execute();
    if($sth->err){
        $self->{LOGGER}->warn( "Error saving key: " . $sth->errstr );
    }
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
    my ( $self, $update_id ) = @_;

    if ( $self->{STATUS} eq "BROKEN" ) {
        $self->{LOGGER}->error( "Refreshing misconfigured service: ".$self->service_desc );
        return;
    }

    $self->{LOGGER}->debug( "Refreshing: " . $self->service_desc );
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $self->{CONF}->{"ls_key_db"}, '', '');
    if ( $self->is_up ) {
        $self->{LOGGER}->debug( "Service is up" );
        if ( $self->{STATUS} ne "REGISTERED" ) {
            $self->{LOGGER}->info( "Service '".$self->service_desc."' is up, registering" );
            $self->register($dbh, $update_id );
        }
        elsif ( time >= $self->{NEXT_REFRESH} ) {
            $self->{LOGGER}->info( "Service '".$self->service_desc."' is up, refreshing registration" );
            $self->keepalive($dbh, $update_id );
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
    $dbh->disconnect();
    
    return;
}

=head2 register ($self)

This function is called by the refresh function. This creates
a brand new registration in the Lookup Service

=cut
sub register {
    my ( $self, $dbh, $update_id ) = @_;

    #Register
    my $reg = $self->_buildRegistration();
    my ($resCode, $res) = $self->{LS_CLIENT}->register({ registration => $reg, uri => $self->{CONF}->{ls_instance} });

    if($resCode == 0){
        $self->{LOGGER}->debug( "Registration succeeded with uri: " . $res->{"uri"} );
        $self->{STATUS}       = "REGISTERED";
        $self->{KEY}          = $res->{"uri"};
        $self->{NEXT_REFRESH} = int($res->{"expires_unixtime"} - .05*($res->{"expires_unixtime"} - time)); 
        $self->{LOGGER}->info("Next Refresh: " . $self->{NEXT_REFRESH});
        $self->save_key($dbh, $res->{"uri"}, $update_id );
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
    my ( $self, $dbh, $update_id  ) = @_;
    my ($resCode, $res) = $self->{LS_CLIENT}->renew({ uri => $self->{KEY}, base => $self->{CONF}->{ls_instance} });
    if ( $resCode == 0 ) {
        $self->{NEXT_REFRESH} = $res->{"expires_unixtime"} - 300; # renew 5 minutes before expiration
        $self->save_key($dbh, $self->{KEY}, $update_id );
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

=head2 _buildRegistration ($self)

This function is called to build the registration object
=cut
sub _buildRegistration {
    my ($self) = @_;
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
    
    return $reg;
}

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
