#!/usr/bin/perl

use strict;
use warnings;

=head1 NAME

lsregistrationdaemon.pl - Registers services into the global information service.

=head1 DESCRIPTION

This daemon reads a configuration file consisting of sites and the services
those sites are running. It will then check those services and register them
with the specified lookup service.

=cut

use FindBin qw($Bin);
use lib "$Bin/../lib";

use perfSONAR_PS::Common;
use perfSONAR_PS::Utils::LookupService qw( discover_lookup_services discover_primary_lookup_service lookup_service_is_active lookup_services_latency_diff);
use perfSONAR_PS::LSRegistrationDaemon::Utils::Config qw( init_sites );
use DBI;
use Getopt::Long;
use Config::General;
use Linux::Inotify2;
use Log::Log4perl qw/:easy/;

# set the process name
$0 = "lsregistrationdaemon.pl";

my $CONFIG_FILE;
my $LOGOUTPUT;
my $LOGGER_CONF;
my $DEBUGFLAG;
my $HELP;

my ( $status, $res );

$status = GetOptions(
    'config=s'  => \$CONFIG_FILE,
    'output=s'  => \$LOGOUTPUT,
    'logger=s'  => \$LOGGER_CONF,
    'verbose'   => \$DEBUGFLAG,
    'help'      => \$HELP
);

if ( not $CONFIG_FILE ) {
    print "Error: no configuration file specified\n";
    exit( -1 );
}

my %conf = Config::General->new( $CONFIG_FILE )->getall();

# Create the logger
my $logger;
if ( not defined $LOGGER_CONF or $LOGGER_CONF eq q{} ) {
    use Log::Log4perl qw(:easy);

    my $output_level = $INFO;
    if ( $DEBUGFLAG ) {
        $output_level = $DEBUG;
    }

    my %logger_opts = (
        level  => $output_level,
        layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
    );

    if ( defined $LOGOUTPUT and $LOGOUTPUT ne q{} ) {
        $logger_opts{file} = $LOGOUTPUT;
    }

    Log::Log4perl->easy_init( \%logger_opts );
    $logger = get_logger( "perfSONAR_PS" );
}
else {
    Log::Log4perl->init( $LOGGER_CONF );
    $logger = get_logger( "perfSONAR_PS" );
}

#monitor config file for changes
my $inotify = new Linux::Inotify2 or die "Unable to create new inotify object: $!" ;
$inotify->blocking(0);
$inotify->watch ("$CONFIG_FILE", IN_MODIFY) or die "config file watcher creation failed" ;

#start main program loop
my $flap_count = 0;
my $current_ls_instance = "";
while(1){
    eval{
        %conf = Config::General->new( -ConfigFile => $CONFIG_FILE, -UTF8 => 1 )->getall();
    };
    if($@){
         $logger->error( "Error reading config file $CONFIG_FILE. Proceeding with defaults: Caused by: $@");
         %conf = ();
    }
    
    unless ($conf{server_flap_threshold}){
        $conf{server_flap_threshold} = 3;
    }

    unless ($conf{"check_interval"}) {
        $logger->debug( "No service check interval specified. Defaulting to 60 minutes" );
        $conf{"check_interval"} = 3600;
    }
    
    unless ($conf{"check_config_interval"}) {
        $logger->debug( "No configuration file check interval specified. Defaulting to 60 seconds" );
        $conf{"check_config_interval"} = 60;
    }
    my $until_next_file_check = $conf{"check_config_interval"};
    
    unless ($conf{"ls_instance_latency_threshold"}) {
        $logger->debug( "No latency threshold specified for switching LSes. Defaulting to 10%" );
        $conf{"ls_instance_latency_threshold"} = .1;
    }
    my $ls_latency_threshold = $conf{"ls_instance_latency_threshold"};
    
    #initialize the key database
    unless ( $conf{"client_uuid_file"} ) {
        $conf{"client_uuid_file"} = '/var/lib/perfsonar/lsregistrationdaemon/client_uuid';
    }
    
    my $init_ls = 0;
    eval{
        #initialize the key database
        unless ( $conf{"ls_key_db"} ) {
            $conf{"ls_key_db"} = '/var/lib/perfsonar/lsregistrationdaemon/lsKey.db';
        }
        my $ls_key_dbh = DBI->connect('dbi:SQLite:dbname=' . $conf{"ls_key_db"}, '', '');
        my $ls_key_create  = $ls_key_dbh->prepare('CREATE TABLE IF NOT EXISTS lsKeys (uri VARCHAR(255) PRIMARY KEY, expires BIGINT NOT NULL, checksum VARCHAR(255) NOT NULL, duplicateChecksum VARCHAR(255) NOT NULL)');
        $ls_key_create->execute();
        if($ls_key_create->err){
            die "Error creating key database: " . $ls_key_create->errstr;
        }
        #delete expired entries from local db
        my $ls_key_clean_expired  = $ls_key_dbh->prepare('DELETE FROM lsKeys WHERE expires < ?');
        $ls_key_clean_expired->execute(time);
        if($ls_key_clean_expired->err){
            die  "Error cleaning out expired keys: " . $ls_key_clean_expired->errstr;
        }
        $ls_key_dbh->disconnect();
    
        #determine LS URL
        my $new_ls_instance = $conf{ls_instance};
        if($new_ls_instance){
            #statically set URL
            if(!$current_ls_instance){
                $init_ls = 1;
                $logger->info("Initial LS URL statically set to " . $new_ls_instance);
            }elsif($current_ls_instance ne $new_ls_instance){
                $init_ls = 1;
                $logger->info("LS static URL changed to " . $new_ls_instance);
            }
            $current_ls_instance = $new_ls_instance;
            $flap_count = 0;
        }else{
            #auto-discover URL
            my $lookup_services = discover_lookup_services();
            $new_ls_instance = discover_primary_lookup_service(lookup_services => $lookup_services);
            if ($new_ls_instance) {
                $logger->debug("Auto-discovered LS: $new_ls_instance");
            }
            #check for a better lookup service
            my $init_ls = 0;
            if(!$current_ls_instance){
                $current_ls_instance = $new_ls_instance;
                $init_ls = 1;
                $flap_count = 0;
                $logger->info("Initial LS URL set to " . $current_ls_instance);
            }elsif($new_ls_instance ne $current_ls_instance){
                my $current_ls_is_active = lookup_service_is_active(ls_url => $current_ls_instance, lookup_services => $lookup_services );
                my $latency_diff = lookup_services_latency_diff(ls_url1 => $current_ls_instance, ls_url2 => $new_ls_instance, lookup_services => $lookup_services);
                $flap_count++ if($latency_diff && $latency_diff > $ls_latency_threshold);
                #only change if we have seen the new LS a few times to prevent flapping
                if(!$current_ls_is_active || $flap_count >  $conf{"server_flap_threshold"}){
                    $current_ls_instance = $new_ls_instance;
                    $init_ls = 1;
                    $flap_count = 0;
                    $logger->info("LS URL automatically changed to  " . $new_ls_instance);
                }
            }else{
                $flap_count = 0;
            }
        }
    };
    if($@){
        $logger->error("$@");
    }
    
    #init and register records for each site
    my $start = time;
    if($current_ls_instance){
        #set here so can be passed to sites
        $conf{ls_instance} = $current_ls_instance;
        my $pid = fork();
        if( $pid != 0 ){
            push @child_pids, $pid;
        }else{
            #fork this off to prevent memory leak. not ideal but perl has trouble cleaning-up this part of code
            my @site_params = init_sites(\%conf);
            foreach my $params ( @site_params ) {
                my $update_id = time .'';
                handle_site( $params->{conf}, $params->{services}, $update_id, $init_ls );
            }
            exit(0);
        }

        foreach my $pid ( @child_pids ) {
            waitpid( $pid, 0 );
        }
        @child_pids = (); #clear pids
    }else{
        $logger->error("Unable to determine ls_instance so not performing any operations");
    }
        
    #sleep until its time to look for file updates or time to refesh
    my $end = time;
    my $until_next_refresh = $conf{"check_interval"} - ($end - $start);
    $logger->debug("Time until next record refresh is $until_next_refresh seconds");
    $start = $end;
    while($until_next_refresh > 0){
        sleep($until_next_refresh < $until_next_file_check ? $until_next_refresh : $until_next_file_check);
        if($inotify->poll()){
            $logger->info("Configuration file change detected, refreshing records.");
            last;
        }else{
            $end = time;
            $until_next_refresh -= ($end - $start);
            $start = $end;
        }
    }
}

exit(0);

=head2 handle_site ($site_conf, \@services )

This function is the main loop for a ls registration daemon process. It goes
through and refreshes the services, and pauses for "check_interval" seconds.

=cut

sub handle_site {
    my ( $site_conf, $services, $update_id, $init_ls ) = @_;
    
    foreach my $service ( @$services ) {
        if($init_ls){
            $service->change_lookup_service();
        }
        $service->bulk_refresh($update_id);

    }

    

    return;
}

__END__

=head1 VERSION

$Id$

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
