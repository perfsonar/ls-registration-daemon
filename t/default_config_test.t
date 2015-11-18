#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More;

use Config::General;
use perfSONAR_PS::LSRegistrationDaemon::Utils::Config qw( init_sites );

use constant TEST_CONF => "$Bin/../etc/ls_registration_daemon.conf";

my %conf = Config::General->new( TEST_CONF )->getall();

my @site_params = init_sites(\%conf);

done_testing();