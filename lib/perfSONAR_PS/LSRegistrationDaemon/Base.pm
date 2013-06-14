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

our $VERSION = 3.3;

use Log::Log4perl qw/get_logger/;
use URI;
use Data::Dumper;

use perfSONAR_PS::Utils::DNS qw(reverse_dns);
use Digest::MD5 qw(md5_base64);
use SimpleLookupService::Client::Registration;
use SimpleLookupService::Client::RecordManager;

use fields 'CONF', 'STATUS', 'LOGGER', 'KEY', 'NEXT_REFRESH', 'LS_CLIENT', 'CHILD_REGISTRATIONS';

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
    
    if ($self->{CONF}->{require_site_name} and not $self->{CONF}->{site_name}) {
    	$self->{LOGGER}->error("site_name is a required configuration option");
    	return -1;
    }

    if ($self->{CONF}->{require_site_location} and not $self->{CONF}->{site_location}) {
    	$self->{LOGGER}->error("site_location is a required configuration option");
    	return -1;
    }
    
    #if disabled then return
    if($self->{CONF}->{disabled}){
        return 0;
    }
    
    #setup ls client
    $self->{LS_CLIENT} = SimpleLookupService::Client::SimpleLS->new();
    my $uri = URI->new($self->{CONF}->{ls_instance}); 
    my $ls_port =$uri->port();
    if(!$ls_port &&  $uri->scheme() eq 'https'){
        $ls_port = 443;
    }elsif(!$ls_port){
        $ls_port = 80;
    }
    $self->{LS_CLIENT}->init( host=> $uri->host(), port=> $ls_port );
    
    #initialize children registrations
    $self->init_children();
    
    #determine if entry that would cause 403 error, cause LS considers a duplicate
    # if its not there is nothing to do
    my $duplicate_uri = $self->find_duplicate();
    if(!$duplicate_uri){
        $self->{LOGGER}->info("No duplicate found for " . $self->description());
        return 0;    
    }
    $self->{LOGGER}->info("Duplicate $duplicate_uri found for " . $self->description());
    
    # if it is a duplicate, determine if anything has changed in the fields the LS
    # does not use to compare records...
    my ($existing_key, $next_refresh) = $self->find_key();
    if($existing_key){
        # no changes, so just renew
        $self->{STATUS} = "REGISTERED";
        $self->{KEY} = $existing_key;
        $self->{NEXT_REFRESH} = $next_refresh;
        $self->{LOGGER}->info("No changes, will renew " . $self->description());
    }else{
        #changes so unregister old one
        $self->{LOGGER}->info("Changes, will delete " . $duplicate_uri);
        my $ls_client = new SimpleLookupService::Client::RecordManager();
        $ls_client->init({ server => $self->{LS_CLIENT}, record_id => $duplicate_uri });
        $ls_client->delete();
    }
    
    return 0;
}

sub init_children {
    my ( $self ) = @_;
    my @childRegs = ();
    
    $self->{CHILD_REGISTRATIONS} = \@childRegs;
    
    return;
}

=head2 refresh ($self)

This function is called by the daemon. It checks if the service is up, and if
so, checks if it should regster the service or send a keepalive to the Lookup
Service. If not, it unregisters the service from the Lookup Service.

=cut

sub refresh {
    my ( $self ) = @_;
    
    #if disabled then return
    if($self->{CONF}->{disabled}){
        return 0;
    }
    
    if ( $self->{STATUS} eq "BROKEN" ) {
        $self->{LOGGER}->error( "Refreshing misconfigured record: ".$self->description() );
        return;
    }
    
    #Refresh children first
    foreach my $child_reg(@{$self->{CHILD_REGISTRATIONS}}){
        $child_reg->refresh();
    }
    
    #Refresh current registration    
    $self->{LOGGER}->debug( "Refreshing: " . $self->description() );
    if ( $self->{CONF}->{force_up_status} || $self->is_up ) {
        $self->{LOGGER}->debug( "Service is up" );
        
        #check if record has changed, if it has then need to re-register
        my ($existing_key, $next_refresh) = $self->find_key();
        if($self->{KEY} && !$existing_key){
            $self->{LOGGER}->info( "didn't find existing key " . $self->{KEY} );
            $self->unregister();
        }
        
        #perform needed LS operation
        if ( $self->{STATUS} ne "REGISTERED" ) {
            $self->{LOGGER}->info( "Record '".$self->description()."' is up, registering" );
            $self->register();
        }
        elsif ( time >= $self->{NEXT_REFRESH} ) {
            $self->{LOGGER}->info( "Record '".$self->description()."' is up, refreshing registration" );
            $self->keepalive();
        }
        else {
            $self->{LOGGER}->debug( "No need to refresh" );
        }
    }
    elsif ( $self->{STATUS} eq "REGISTERED" ) {
        $self->{LOGGER}->info( "Record '".$self->description()."' is down, unregistering" );
        $self->unregister();
    }
    else {
        $self->{LOGGER}->info( "Record '".$self->description()."' is down" );
    }
    
    return;
}

=head2 register ($self)

This function is called by the refresh function. This creates
a brand new registration in the Lookup Service

=cut
sub register {
    my ( $self ) = @_;

    #Register
    my $reg = $self->build_registration();
    my $ls_client = new SimpleLookupService::Client::Registration();
    $ls_client->init({server => $self->{LS_CLIENT}, record => $reg});
    my ($resCode, $res) = $ls_client->register();

    if($resCode == 0){
        $self->{LOGGER}->debug( "Registration succeeded with uri: " . $res->getRecordUri() );
        $self->{STATUS}       = "REGISTERED";
        $self->{KEY}          = $res->getRecordUri();
        $self->{NEXT_REFRESH} = $res->getRecordExpiresAsUnixTS()->[0] - $self->{CONF}->{check_interval}; 
        if($self->{NEXT_REFRESH} < time){
             $self->{LOGGER}->warn( "You may want to decrease the check_interval option as the registered record will expire before the next run");
        }
        $self->{LOGGER}->info("Next Refresh: " . $self->{NEXT_REFRESH});
        $self->add_key();
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
    my $ls_client = new SimpleLookupService::Client::RecordManager();
    $ls_client->init({ server => $self->{LS_CLIENT}, record_id => $self->{KEY} });
    my ($resCode, $res) = $ls_client->renew();
    if ( $resCode == 0 ) {
        $self->{NEXT_REFRESH} = $res->getRecordExpiresAsUnixTS()->[0] - $self->{CONF}->{check_interval};
        $self->update_key();
    }
    else {
        $self->{STATUS} = "UNREGISTERED";
        $self->{LOGGER}->error( "Couldn't send Keepalive. Will send full registration next time. Error was: " . $res->{message} );
        $self->delete_key();
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
    
    my $ls_client = new SimpleLookupService::Client::RecordManager();
    $ls_client->init({ server => $self->{LS_CLIENT}, record_id => $self->{KEY} });
    $ls_client->delete();
    $self->{STATUS} = "UNREGISTERED";
    $self->delete_key();
    
    return;
}

sub find_key {
    my ( $self ) = @_;
    
    my $key = '';
    my $expires = 0;
    my $checksum = $self->build_checksum();
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $self->{CONF}->{"ls_key_db"}, '', '');
    my $stmt  = $dbh->prepare('SELECT uri, expires FROM lsKeys WHERE checksum=?');
    $stmt->execute($checksum);
    if($stmt->err){
        $self->{LOGGER}->warn( "Error finding key: " . $stmt->errstr );
        $dbh->disconnect();
        return '';
    }
    while(my @row = $stmt->fetchrow_array()){
        $key = $row[0];
        $expires = $row[1];
        $self->{LOGGER}->info( "Found key $key with $checksum for " . $self->description() . " that expires $expires" );
    }
    $dbh->disconnect();
    
    return ($key, $expires);
}

sub find_duplicate {
    my ( $self ) = @_;
    
    my $key = '';
    my $expires = 0;
    my $checksum = $self->build_duplicate_checksum();
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $self->{CONF}->{"ls_key_db"}, '', '');
    my $stmt  = $dbh->prepare('SELECT uri FROM lsKeys WHERE duplicateChecksum=?');
    $stmt->execute($checksum);
    if($stmt->err){
        $self->{LOGGER}->warn( "Error finding duplicate checksum: " . $stmt->errstr );
        $dbh->disconnect();
        return '';
    }
    while(my @row = $stmt->fetchrow_array()){
        $key = $row[0];
        $self->{LOGGER}->info( "Found duplicate checksum $key with $checksum for " . $self->description());
    }
    $dbh->disconnect();
    
    return $key;
}

sub add_key {
    my ( $self ) = @_;
    
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $self->{CONF}->{"ls_key_db"}, '', '');
    my $stmt  = $dbh->prepare('INSERT INTO lsKeys VALUES(?, ?, ?, ?)');
    $stmt->execute($self->{KEY}, $self->{NEXT_REFRESH}, $self->build_checksum(), $self->build_duplicate_checksum());
    if($stmt->err){
        $self->{LOGGER}->warn( "Error adding key: " . $stmt->errstr );
        $dbh->disconnect();
        return '';
    }
    $dbh->disconnect();
}

sub update_key {
    my ( $self ) = @_;
    
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $self->{CONF}->{"ls_key_db"}, '', '');
    my $stmt  = $dbh->prepare('UPDATE lsKeys SET expires=? WHERE uri=?');
    $stmt->execute($self->{NEXT_REFRESH}, $self->{KEY});
    if($stmt->err){
        $self->{LOGGER}->warn( "Error updating key: " . $stmt->errstr );
        $dbh->disconnect();
        return '';
    }
    $dbh->disconnect();
}

sub delete_key {
    my ( $self ) = @_;
    
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $self->{CONF}->{"ls_key_db"}, '', '');
    my $stmt  = $dbh->prepare('DELETE FROM lsKeys WHERE uri=?');
    $stmt->execute($self->{KEY});
    if($stmt->err){
        $self->{LOGGER}->warn( "Error deleting key: " . $stmt->errstr );
        $dbh->disconnect();
        return '';
    }
    $dbh->disconnect();
}



sub build_registration {
    my ( $self ) = @_;
    
    die "Subclass class must implement build_registration"
}

sub build_checksum {
    my ( $self ) = @_;
    
    die "Subclass class must implement build_checksum"
}

sub build_duplicate_checksum {
    my ( $self ) = @_;
    
    die "Subclass class must implement build_duplicate_checksum"
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
