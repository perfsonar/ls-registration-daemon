package perfSONAR_PS::LSRegistrationDaemon::Utils::Config;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Config - Utility class for parsing the config

=head1 DESCRIPTION

This module provides methods for parsing lsregistrationdaemon.conf.
=cut

use strict;
use warnings;

our $VERSION = 3.5;

use base 'Exporter';
use Log::Log4perl qw/get_logger/;
use perfSONAR_PS::Common;
use perfSONAR_PS::LSRegistrationDaemon::Person;
use perfSONAR_PS::LSRegistrationDaemon::Host;
use perfSONAR_PS::LSRegistrationDaemon::Signature;

our @EXPORT_OK = qw( init_sites init_site );

my $logger = get_logger(__PACKAGE__);

=head2 init_sites ($conf)

This function takes the global configuration and parse the sites

=cut
sub init_sites {
    my ( $conf ) = @_;
    
    my $site_confs = $conf->{"site"};
    if ( not $site_confs ) {
        $logger->error( "No sites defined in configuration file" );
        exit( -1 );
    }

    if ( ref( $site_confs ) ne "ARRAY" ) {
        my @tmp = ();
        push @tmp, $site_confs;
        $site_confs = \@tmp;
    }

    my @site_params = ();

    foreach my $site_conf ( @$site_confs ) {
        my $site_merge_conf = mergeConfig( $conf, $site_conf );
        $site_merge_conf->{'ls_key_db'} = $conf->{'ls_key_db'};
        my $services = init_site( $site_merge_conf );

        if ( not $services ) {
            $logger->error("Couldn't initialize site. Exiting.");
            exit( -1 );
        }

        my %params = ( conf => $site_merge_conf, services => $services );

        push @site_params, \%params;
    }
    
    return @site_params;
}

=head2 init_site ($site_conf)

This function takes a configuration for a site, and generates agents for each
service it finds. It returns that as an array of service agents.

=cut

sub init_site {
    my ( $site_conf ) = @_;
    
    # List that will hold all objects to be registered
    my @services = ();
    
    ##
    # Add person records to registration list first - We add these before hosts
    # and services so they can be referenced
    if($site_conf->{administrator}) {
        my $admin_conf = mergeConfig( $site_conf, $site_conf->{administrator} );
        my $person = perfSONAR_PS::LSRegistrationDaemon::Person->new();
        if ( $person->init( $admin_conf ) != 0 ) {
            $logger->error( "Error: Couldn't initialize person record" );
            exit( -1 );
        }
        push @services, $person;
    }

    ##
    # Add signing certificate records to registration list first - We add these before hosts
    # and services so they can be referenced
    $logger->info( "Checking for  signature record" );
    if($site_conf->{signature}) {
        $logger->info( "Found signature record" );
        my $signature_conf = mergeConfig( $site_conf, $site_conf->{signature} );
        my $signing_record = perfSONAR_PS::LSRegistrationDaemon::Signature->new();
        if ( $signing_record->init( $signature_conf ) != 0 ) {
            $logger->error( "Error: Couldn't initialize signature record" );
            exit( -1 );
        }
        push @services, $signing_record;
    }
    $logger->info( "No signature record found" );

    ##
    # Parse host configurations - We add these before services 
    # so they can be referenced
    $site_conf->{host} = [] unless $site_conf->{host};
    $site_conf->{host} = [ $site_conf->{host} ] unless ref($site_conf->{host}) eq "ARRAY";

    foreach my $curr_host_conf ( @{ $site_conf->{host} } ) {

        my $host_conf = mergeConfig( $site_conf, $curr_host_conf );
        
        my $host = perfSONAR_PS::LSRegistrationDaemon::Host->new();
        if ( $host->init( $host_conf ) != 0 ) {

            # complain
            $logger->error( "Error: Couldn't initialize host watcher" );
            exit( -1 );
        }
        push @services, $host;
    }

    return \@services;
}