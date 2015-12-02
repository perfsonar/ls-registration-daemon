#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Test::More;
use perfSONAR_PS::LSRegistrationDaemon::UnitTests::Util qw( test_ls_record );

use perfSONAR_PS::LSRegistrationDaemon::Services::NDT;

#constants
use constant TEST_ADDRESS => "10.0.0.1";
use constant TEST_RECORD_HASH => {
                                    'psservice-eventtypes' => [
                                                                'http://ggf.org/ns/nmwg/tools/ndt/1.0'
                                                              ],
                                    'service-administrators' => [
                                                                  ''
                                                                ],
                                    'service-host' => [
                                                        ''
                                                      ],
                                    'service-name' => [
                                                        'NDT Server'
                                                      ],
                                    'type' => [
                                                'service'
                                              ],
                                    'service-locator' => [
                                                           'http://10.0.0.1:7123'
                                                         ],
                                    'service-type' => [
                                                        'ndt'
                                                      ]
                                  };

#instantiate object
my $record = new perfSONAR_PS::LSRegistrationDaemon::Services::NDT;

#add extra config
my %conf = ( 'address' => TEST_ADDRESS );

#run standard tests
my $registration = test_ls_record($record, \%conf, TEST_RECORD_HASH);

#run any extra tests
#...

#finish testing
done_testing();