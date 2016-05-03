#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Test::More;
use perfSONAR_PS::LSRegistrationDaemon::UnitTests::Util qw( test_ls_record );

use perfSONAR_PS::LSRegistrationDaemon::PSMetadata;

#constants
use constant TEST_RECORD_HASH => {
                                    'group-domains' => [
                                                         'foo.bar'
                                                       ],
                                    'group-communities' => [
                                                             'Test'
                                                           ],
                                    'psmetadata-eventtypes' => [
                                                                 'throughput'
                                                               ],
                                    'psmetadata-measurement-agent' => [
                                                                        '10.0.0.1'
                                                                      ],
                                    'psmetadata-src-address' => [
                                                                  '10.0.0.1'
                                                                ],
                                    'psmetadata-uri' => [
                                                          '/esmond/perfsonar/archive/ABCDEF1234567890'
                                                        ],
                                    'psmetadata-dst-address' => [
                                                                  '10.0.0.2'
                                                                ],
                                    'psmetadata-tool-name' => [
                                                                'bwctl/iperf3'
                                                              ],
                                    'type' => [
                                                'psmetadata'
                                              ],
                                    'psmetadata-index-example-foobar' => [
                                                                    'foo',
                                                                    'bar'
                                                                  ],
                                    'psmetadata-ma-locator' => [
                                                                 'http://foo.bar/esmond/perfsonar/archive'
                                                               ]
                                  };

#instantiate object
my $record = new perfSONAR_PS::LSRegistrationDaemon::PSMetadata;

#add extra config
my %conf = ( 'source' => '10.0.0.1',
             'destination' => '10.0.0.2',
             'event_type' => 'throughput',
             'measurement_agent' => '10.0.0.1',
             'tool_name' => 'bwctl/iperf3',
             'ma_locator' => 'http://foo.bar/esmond/perfsonar/archive',
             'domain' => 'foo.bar',
             'site_project' => 'Test',
             'result_index' => [ {type=>'example', value=>{'foobar' => ['foo', 'bar']}} ],
             'metadata_uri' => '/esmond/perfsonar/archive/ABCDEF1234567890',
            );
            
        
#run standard tests
my $registration = test_ls_record($record, \%conf, TEST_RECORD_HASH);

#run any extra tests
#...

#finish testing
done_testing();