#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Test::More;
use perfSONAR_PS::LSRegistrationDaemon::UnitTests::Util qw( test_ls_record_with_signature);

use perfSONAR_PS::LSRegistrationDaemon::Person;

#constants
use constant TEST_RECORD_HASH => {
    'location-city' => [
        'New York'
    ],
    'location-longitude' => [
        '-74.0059'
    ],
    'person-emails' => [
        'foo@foobar.test'
    ],
    'location-state' => [
        'NY'
    ],
    'location-sitename' => [
        'Foo Bar East'
    ],
    'person-organization' => [
        'Foo Bar University'
    ],
    'person-name' => [
        'Foo Bar'
    ],
    'location-code' => [
        '10001'
    ],
    'location-country' => [
        'US'
    ],
    'location-latitude' => [
        '40.7127'
    ],
    'person-phonenumbers' => [
        '5555555555'
    ],
    'type' => [
        'person'
    ]
};

#instantiate object
my $record = new perfSONAR_PS::LSRegistrationDaemon::Person;

#add extra config
my %conf = ( 'name' => 'Foo Bar',
    'email' => 'foo@foobar.test',
    'organization' => 'Foo Bar University',
    'site_name' => 'Foo Bar East',
    'city' => 'New York',
    'region' => 'NY',
    'zip_code' => '10001',
    'country' => 'US',
    'phone' => '5555555555',
    'latitude' => '40.7127',
    'longitude' => '-74.0059'
);

#run standard tests
my $registration = test_ls_record_with_signature($record, \%conf, TEST_RECORD_HASH);

#run any extra tests
#...

#finish testing
done_testing();