#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
use Test::More;
use Config::General;

use constant TEST_CONF => "$Bin/../etc/lsregistrationdaemon.conf";
use constant TEST_LS_INSTANCE => 'http://foo.bar';
use constant TEST_CLIENT_UUID_FILE => "$Bin/test_data/client_uuid";
use constant TEST_KEY_DB => "$Bin/test_data/lsKey.db";

# logging
Log::Log4perl->easy_init( {level => 'OFF'} );

#skip on mac
if( $^O eq 'darwin' ) {
      plan skip_all => 'Autodetection does not work on MacOS';
}

#import config util. use eval since does not work on Mac
eval "use perfSONAR_PS::LSRegistrationDaemon::Utils::Config qw( init_sites )";
ok(!$@, "load Config.pm");

my %conf;

#parse config file
ok(%conf = Config::General->new( TEST_CONF )->getall(), "read config file");

#override a few settings for testing purposes
$conf{'ls_instance'} =  TEST_LS_INSTANCE;
$conf{'client_uuid_file'} = TEST_CLIENT_UUID_FILE;
$conf{'ls_key_db'} = TEST_KEY_DB;
$conf{'allow_internal_addresses'} = 1; #increase autodetection chances

#build service records
my @site_params;
ok(@site_params = init_sites(\%conf), "built record tree") or BAIL_OUT("Unable to build record objects," . 
    "no further testing to be performed. Likely autodetection of some value failed. " .
    "It may be a bug or it may you are testing on an unsupported system");

#verify sites are defined
my $site_i = 1;
foreach my $site(@site_params){
    ok(@{$site->{'services'}} > 0, "site $site_i has hosts");
    my $host_i = 1;
    #verify all the top level services are hosts
    foreach my $host(@{$site->{'services'}}){
        # verify we have host types
        isa_ok($host, 'perfSONAR_PS::LSRegistrationDaemon::Host', "site $site_i host $host_i type check");
        $host_i++;
    }
    $site_i++;
}

done_testing();