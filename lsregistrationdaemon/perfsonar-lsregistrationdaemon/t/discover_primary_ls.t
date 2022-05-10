#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 4;

use perfSONAR_PS::Utils::LookupService qw( discover_primary_lookup_service );


#Discover primary lookup service
my $ls_instance;
ok( $ls_instance = discover_primary_lookup_service(), "discover_primary_lookup_service completed");

#Make sure result is defined
ok(defined $ls_instance, "LS instance defined") 
    or diag("No LS discovered. You may want to check your network connection.");

#Make sure result is non-empty
ok($ls_instance ne '', "LS instance is non-empty");

#Make sure it starts with http:// or https://
like($ls_instance, qr/https?\:\/\/.+/, "LS instance looks like a http/https URL");
