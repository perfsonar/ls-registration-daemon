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
use DBI;

use perfSONAR_PS::Utils::DNS qw(reverse_dns);
use perfSONAR_PS::Utils::LookupService qw(get_client_uuid set_client_uuid);
use Digest::MD5 qw(md5_base64);
use SimpleLookupService::Client::Registration;
use SimpleLookupService::Client::RecordManager;
use SimpleLookupService::BulkRenewMessage;
use SimpleLookupService::Client::BulkRenewManager;
use SimpleLookupService::BulkRenewResponse;
use Data::Dumper;

use fields 'CONF', 'STATUS', 'LOGGER', 'KEY', 'NEXT_REFRESH', 'LS_CLIENT', 'DEPENDENCIES', 'SUBORDINATES', 'CLIENT_UUID';

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
    $self->{DEPENDENCIES} = [];
    $self->{SUBORDINATES} = [];

    return $self;
}

sub known_variables {
    my ($self) = @_;

    return (
        { variable => "disabled", type => "scalar" },
        { variable => "force_up_status", type => "scalar" },
        { variable => "ls_instance", type => "scalar" },
        { variable => "ls_key_db", type => "scalar" },
        { variable => "check_interval", type => "scalar" },
    );
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
    $self->{CLIENT_UUID} = get_client_uuid(file => $self->{CONF}->{'client_uuid_file'});
    unless($self->{CLIENT_UUID}){
        $self->{CLIENT_UUID} = set_client_uuid(file => $self->{CONF}->{'client_uuid_file'});
    }

    #if disabled then return
    if($self->{CONF}->{disabled}){
        return 0;
    }

    #setup ls client
    $self->init_ls_client();

    # Initialize registrations that we depend on
    if ($self->init_dependencies()) {
        return -1;
    }

    if ($self->validate_conf($self->{CONF})) {
        return -1;
    }

    #determine if entry that would cause 403 error, cause LS considers a duplicate
    # if its not there is nothing to do
    my $duplicate_uri = $self->find_duplicate();
    unless ($duplicate_uri){
        $self->{LOGGER}->debug("No duplicate found for " . $self->description());
    }
    else {
        $self->{LOGGER}->debug("Duplicate $duplicate_uri found for " . $self->description());

        # if it is a duplicate, determine if anything has changed in the fields the LS
        # does not use to compare records...
        my ($existing_key, $next_refresh) = $self->find_key();
        if($existing_key){
            # no changes, so just renew
            $self->{STATUS} = "REGISTERED";
            $self->{KEY} = $existing_key;
            $self->{NEXT_REFRESH} = time; # Renew it now to make sure that the LS actually has the record
            $self->{LOGGER}->info("No changes for record $existing_key, will renew " . $self->description());
        }else{
            #changes so unregister old one
            $self->{LOGGER}->info("Changes in record, will delete " . $duplicate_uri);
            my $ls_client = new SimpleLookupService::Client::RecordManager();
            $ls_client->init({ server => $self->{LS_CLIENT}, record_id => $duplicate_uri });
            $ls_client->delete();
        }
    }

    # Initialize registrations that depend on us
    if ($self->init_subordinates() != 0) {
        return -1;
    }

    return 0;
}

sub validate_conf {
    my ($self, $conf) = @_;

    my @variables = $self->known_variables();
    foreach my $variable_info (@variables) {
        my $variable = $variable_info->{variable};
        my $type = $variable_info->{type};

        next unless defined ($conf->{$variable_info->{variable}});

        if ($variable_info->{type} eq "array") {
            $conf->{$variable} = [ $conf->{$variable} ] unless ref($conf->{$variable}) eq "ARRAY";
        }
        elsif ($variable_info->{type} eq "scalar") {
            if (ref($conf->{$variable}) eq "ARRAY") {
                $self->{LOGGER}->error("Multiple entries for ".$variable.". Only one is valid");
                return -1;
            }
            elsif (ref($conf->{$variable})) {
                $self->{LOGGER}->error("Invalid entry for ".$variable);
                return -1;
            }
        }
    }

    return 0;
}

sub init_ls_client {
    my ( $self ) = @_;

    $self->{LS_CLIENT} = SimpleLookupService::Client::SimpleLS->new();
    my $uri = URI->new($self->{CONF}->{ls_instance});
    my $ls_port =$uri->port();
    if(!$ls_port &&  $uri->scheme() eq 'https'){
        $ls_port = 443;
    }elsif(!$ls_port){
        $ls_port = 80;
    }
    $self->{LS_CLIENT}->init( host=> $uri->host(), port=> $ls_port );
}

sub change_lookup_service {
    my ( $self ) = @_;

    $self->delete_key();

    $self->init_ls_client();

    if ($self->{DEPENDENCIES}) {
        foreach my $child_reg (@{$self->{DEPENDENCIES}}){
            $child_reg->change_lookup_service();
        }
    }

    if ($self->{SUBORDINATES}) {
        foreach my $child_reg (@{$self->{SUBORDINATES}}) {
            $child_reg->change_lookup_service();
        }
    }
}

sub init_dependencies {
    my ( $self ) = @_;

    return 0;
}

sub init_subordinates {
    my ( $self ) = @_;

    return 0;
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
        $self->{LOGGER}->error( "Refreshing misconfigured record (key=" . $self->{KEY} . ", description=" . $self->description() . ")" );
        return;
    }

    # Refresh the objects we depend on first
    foreach my $child_reg(@{$self->{DEPENDENCIES}}){
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
            $self->{LOGGER}->info( "Record is up, registering (description=" . $self->description() . ")" );
            $self->register();
        }
        elsif ( time >= $self->{NEXT_REFRESH} ) {
            $self->{LOGGER}->info( "Record is up, refreshing registration (key=" . $self->{KEY} . ", description=" . $self->description() . ")" );
            $self->keepalive();
        }
        else {
            $self->{LOGGER}->debug( "No need to refresh" );
        }
    }
    elsif ( $self->{STATUS} eq "REGISTERED" ) {
        $self->{LOGGER}->info( "Record is down, unregistering (key=" . $self->{KEY} . ", description=" . $self->description() . ")" );
        $self->unregister();
    }
    else {
        $self->{LOGGER}->info( "Record is down (key=" . ($self->{KEY} ? $self->{KEY} : 'NONE') . ", description=" . $self->description() . ")" );
    }

    # Refresh the objects that depend on us
    foreach my $child_reg (@{$self->{SUBORDINATES}}){
        $child_reg->refresh();
    }

    return;
}

sub bulk_refresh {

    my ( $self ) = @_;

    #if disabled then return
    if($self->{CONF}->{disabled}){
        return 0;
    }

    if ( $self->{STATUS} eq "BROKEN" ) {
        $self->{LOGGER}->error( "Refreshing misconfigured record (key=" . $self->{KEY} . ", description=" . $self->description() . ")" );
        return;
    }

    my $flattened_services_list = [];

    my $refresh_list= ();

    if(@{$self->{DEPENDENCIES}}){
        foreach my $child_reg(@{$self->{DEPENDENCIES}}){
            push(@{$flattened_services_list}, $child_reg )
        }
    }
    push(@{$flattened_services_list}, $self);

    if(@{$self->{SUBORDINATES}}){
        foreach my $child_reg(@{$self->{SUBORDINATES}}){
            push(@{$flattened_services_list}, $child_reg )
        }
    }


    #Refresh current registration
    $self->{LOGGER}->debug( "Refreshing: " . $self->description() );


    for (my $i=0; $i <= $#$flattened_services_list; $i++) {

        my $current_reg = $flattened_services_list->[$i];

        $self->{LOGGER}->debug( "Hashcontents: " . $current_reg);
        if ( $current_reg->{CONF}->{force_up_status} || $current_reg->is_up ) {
            $current_reg->{LOGGER}->debug( "Service is up" );

            $current_reg->{LOGGER}->debug( "Current reg status" . $current_reg->{STATUS});

            #check if record has changed, if it has then need to re-register
            my ($existing_key, $next_refresh) = $current_reg->find_key();
            if($current_reg->{KEY} && !$existing_key){
                $current_reg->{LOGGER}->debug( "Current reg status" . $current_reg->{STATUS});
                $current_reg->{LOGGER}->info( "didn't find existing key " . $current_reg->{KEY} );
                $current_reg->unregister();
            }

            #perform needed LS operation
            if ( $current_reg->{STATUS} ne "REGISTERED" ) {
                $current_reg->{LOGGER}->info( "Record is up, registering (description=" .  $current_reg->description() . ")" );
                $current_reg->{LOGGER}->debug( "Current reg status" . $current_reg->{STATUS});
                $current_reg->register();
            }
            elsif ( time >= $self->{NEXT_REFRESH} ) {
                $current_reg->{LOGGER}->info( "Record is up, adding registration to refresh list(key=" . $current_reg->{KEY} . ", description=" . $current_reg->description() . ")" );
                $refresh_list->{$current_reg->{KEY}} = $current_reg;
            }
            else {
                $current_reg->{LOGGER}->debug( "No need to refresh" );
            }
        }
        elsif ( $self->{STATUS} eq "REGISTERED" ) {
            $current_reg->{LOGGER}->info( "Record is down, unregistering (key=" . $current_reg->{KEY} . ", description=" . $current_reg->description() . ")" );
            $current_reg->unregister();
        }
        else {
            $current_reg->{LOGGER}->info( "Record is down (key=" . ($current_reg->{KEY} ? $current_reg->{KEY} : 'NONE') . ", description=" . $current_reg->description() . ")" );
        }
    }


    #call bulk_keepalive
    if($refresh_list){
        $self->{LOGGER}->info( "Calling bulk_keepalive() " );
        my $refreshed = $self->bulk_keepalive($refresh_list);
    }



    return;

}


sub bulk_keepalive {

    my ( $self, $services_map ) = @_;

    my $record_uris = [];
    push(@{$record_uris}, (keys %{$services_map}));

    my $bulk_renew_message = new SimpleLookupService::BulkRenewMessage();
    $bulk_renew_message->init({record_uris => $record_uris});

    if($self->{CONF}->{ls_lease_duration}){
        my $val = $self->{CONF}->{ls_lease_duration}/60;
        my $ttl = int($val+0.5); #round to nearest integer
        $bulk_renew_message->setRecordTtlInMinutes($ttl);
    }

    $self->{LOGGER}->debug("Created Bulk renew message");
    $self->{LOGGER}->debug(Dumper($bulk_renew_message));


    my $ls_client = new SimpleLookupService::Client::BulkRenewManager();
    $ls_client->init(server => $self->{LS_CLIENT}, message=>$bulk_renew_message);

    my ($resCode, $res) = $ls_client->renew();
    
    my %failed_keys = ();
    my %renewed_keys = ();

    if ( $resCode == 0 ) {

        if($res->getTotal() == $res->getRenewed()){
            $self->{LOGGER}->info("Bulk keepalive succeeded.");
            %renewed_keys = %{$services_map};
        }elsif ($res->getTotal() == $res->getFailed()){
            $self->{LOGGER}->info("Bulk keepalive did not succeed. Added services to failed list. Will try registering in the next interval");
            %failed_keys = %{$services_map} ;
        }else {
            for my $key (@{$res->getFailedUris()}) {
                $failed_keys{$key} = $services_map->{$key};
                delete $services_map->{$key};
            }

            %renewed_keys = %{$services_map};
        }




    }else{
        $self->{LOGGER}->info("Bulk keepalive did not succeed. Reason:". $res->{message});
        %failed_keys = %{$services_map} ;

        for my $key (keys %$services_map) {
            $services_map->{$key}->{STATUS} = "UNREGISTERED";
            $services_map->{$key}->{LOGGER}->error( "Couldn't send Keepalive. Will send full registration next time.". "(key=" . $services_map->{$key}->{KEY} . ", description=" . $services_map->{$key}->description() . ")");
            $services_map->{$key}->delete_key();
        }
    }

    if(%renewed_keys){
        $self->_handle_bulk_update_success(\%renewed_keys);
    }

    if(%failed_keys){
        $self->_handle_bulk_update_failure(\%failed_keys);
    }



    return $services_map;

}

sub _handle_bulk_update_success {
    my ($self, $service_map) = @_;
    
    my $next_refresh;
    if($self->{CONF}->{ls_lease_duration}){
        # if ls_lease_duration set, use that knowledge to set next_refresh
        $next_refresh = time + $self->{CONF}->{ls_lease_duration} - $self->{CONF}->{check_interval} - 10;
    }else{
        # if not set, then only the server knows, so just make sure it doesn't expire before next run
        $next_refresh = time + $self->{CONF}->{check_interval} + 300; #add some wiggle room
    }
    
    if($service_map->{$self->{KEY}}){
        $self->{STATUS} = "REGISTERED";
        $self->{NEXT_REFRESH} = $next_refresh;
    }

    for my $key (keys %{$service_map}){
        $service_map->{$key}->{NEXT_REFRESH} = $next_refresh;
        $service_map->{$key}->update_key();
        $service_map->{$key}->{STATUS} = "REGISTERED";

        $service_map->{$key}->{LOGGER}->info("Service renewed. Next Refresh: " . $service_map->{$key}->{NEXT_REFRESH} . "(key=" . $service_map->{$key}->{KEY} . ", description=" . $service_map->{$key}->description() . ")");
    }
    return;
}

sub _handle_bulk_update_failure {

    my ($self, $service_map) = @_;

    if($service_map->{$self->{KEY}}){
        $self->{STATUS} = "UNREGISTERED";
        $self->{LOGGER}->error( "Couldn't send Keepalive. Will send full registration next time.". "(key=" . $self->{KEY} . ", description=" . $self->description() . ")");
        $self->delete_key();
    }

    for my $key (keys %{$service_map}){
        $service_map->{$key}->{STATUS} = "UNREGISTERED";
        $service_map->{$key}->{LOGGER}->error( "Couldn't send Keepalive. Will send full registration next time.". "(key=" . $service_map->{$key}->{KEY} . ", description=" . $service_map->{$key}->description() . ")");
        $service_map->{$key}->delete_key();
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
    $reg->setRecordClientUUID($self->client_uuid());

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
        $self->{LOGGER}->info("Service registered. Next Refresh: " . $self->{NEXT_REFRESH} . "(key=" . $self->{KEY} . ", description=" . $self->description() . ")");
        $self->add_key();
    }else{
        $self->{LOGGER}->error( "Problem registering service. Will retry full registration next time: " . $res->{message} . "(key=NONE, description=" . $self->description() . ")" );
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
        $self->{LOGGER}->info("Service renewed. Next Refresh: " . $self->{NEXT_REFRESH} . "(key=" . $self->{KEY} . ", description=" . $self->description() . ")");
    }
    else {
        $self->{STATUS} = "UNREGISTERED";
        $self->{LOGGER}->error( "Couldn't send Keepalive. Will send full registration next time. Error was: " . $res->{message} . "(key=" . $self->{KEY} . ", description=" . $self->description() . ")");
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
        $self->{LOGGER}->debug( "Found key $key with $checksum for " . $self->description() . " that expires $expires" );
    }
    $dbh->disconnect();

    return ($key, $expires);
}

sub find_duplicate {
    my ( $self ) = @_;

    my $key = '';
    my $expires = 0;
    my $checksum = $self->build_duplicate_checksum();
    $self->{LOGGER}->debug( "Checking duplicate for $checksum for " . $self->description());
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
        $self->{LOGGER}->debug( "Found duplicate checksum $key with $checksum for " . $self->description());
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
    $self->{LOGGER}->info( "Updated key: " . $self->{KEY} . "with refresh" . $self->{NEXT_REFRESH} );
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

sub client_uuid(){
    my ( $self ) = @_;

    return $self->{CLIENT_UUID};
}

sub build_registration {
    my ( $self ) = @_;

    die "Subclass class must implement build_registration"
}

sub checksum_fields {
    my ( $self ) = @_;

    die "Subclass class must implement checksum_fields"
}

sub duplicate_checksum_fields {
    my ( $self ) = @_;

    die "Subclass class must implement duplicate_checksum_fields"
}

sub checksum_prefix {
    my ( $self ) = @_;

    die "Subclass class must implement checksum_prefix"
}

sub build_checksum {
    my ( $self ) = @_;

    my $checksum = $self->checksum_prefix()."::";
    foreach my $field (@{ $self->checksum_fields() }) {
        $checksum .= $self->_add_checksum_val($self->$field());
    }
    $checksum .= $self->_add_checksum_val($self->client_uuid());

    $self->{LOGGER}->debug("Checksum prior to md5 is " . $checksum);

    utf8::encode($checksum); # convert to binary for md5 to work
    $checksum = md5_base64($checksum);

    $self->{LOGGER}->debug("Checksum is " . $checksum);

    return $checksum;
}

sub build_duplicate_checksum {
    my ( $self ) = @_;

    my $checksum = $self->checksum_prefix()."::";
    foreach my $field (@{ $self->duplicate_checksum_fields() }) {
        $checksum .= $self->_add_checksum_val($self->$field());
    }

    $self->{LOGGER}->debug("Duplicate checksum prior to md5 is " . $checksum);

    utf8::encode($checksum); # convert to binary for md5 to work
    $checksum = md5_base64($checksum);

    $self->{LOGGER}->debug("Duplicate checksum is " . $checksum);

    return $checksum;

}

sub _add_checksum_val {
    my ($self, $val) = @_;

    my $result = '';

    if(!defined $val){
        return $result;
    }

    if(ref($val) eq 'ARRAY'){
        $result = join ',', sort @{$val};
    }else{
        $result = $val;
    }

    return $result;
}

1;
__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<perfSONAR_PS::Utils::DNS>,
L<perfSONAR_PS::Client::LS>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS git repository is located at:

  https://code.google.com/p/perfsonar-ps/

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
