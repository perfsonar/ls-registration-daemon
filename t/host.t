#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Test::More;
use perfSONAR_PS::LSRegistrationDaemon::UnitTests::Util qw( test_ls_record );

use perfSONAR_PS::LSRegistrationDaemon::Host;

#constants
use constant TEST_RECORD_HASH => {
                                    'pshost-bundle' => [
                                                         'perfsonar-toolkit'
                                                       ],
                                    'location-city' => [
                                                         'New York'
                                                       ],
                                    'host-net-tcp-maxbuffer-recv' => [
                                                                       '4194304 bytes'
                                                                     ],
                                    'host-hardware-processorcore' => [
                                                                       '4'
                                                                     ],
                                    'group-communities' => [
                                                             'Test'
                                                           ],
                                    'pshost-access-policy' => [
                                                                'public'
                                                              ],
                                    'location-state' => [
                                                          'NY'
                                                        ],
                                    'host-os-kernel' => [
                                                          'Linux 2.6.32-431.29.2.el6.aufs.web100.x86_64'
                                                        ],
                                    'host-net-tcp-autotunemaxbuffer-recv' => [
                                                                               '4194304 bytes'
                                                                             ],
                                    'location-latitude' => [
                                                             '40.7127'
                                                           ],
                                    'host-net-tcp-maxachievable' => [
                                                                      '9 Gbps'
                                                                    ],
                                    'host-hardware-cpuid' => [
                                                               'Intel(R) Core(TM) i5-3427U CPU @ 1.80GHz'
                                                             ],
                                    'host-net-interfaces' => [],
                                    'host-hardware-processorspeed' => [
                                                                        '2600.056 MHz'
                                                                      ],
                                    'host-administrators' => [
                                                               ''
                                                             ],
                                    'type' => [
                                                'host'
                                              ],
                                    'host-hardware-memory' => [
                                                                '1869 MB'
                                                              ],
                                    'host-os-version' => [
                                                           '6.6 (Final)'
                                                         ],
                                    'location-longitude' => [
                                                              '-74.0059'
                                                            ],
                                    'host-vm' => [
                                                   1
                                                 ],
                                    'host-hardware-processorcount' => [
                                                                        '2'
                                                                      ],
                                    'host-net-tcp-maxbacklog' => [
                                                                   '1000'
                                                                 ],
                                    'location-sitename' => [
                                                             'Foo Bar East'
                                                           ],
                                    'pshost-access-notes' => [
                                                               'This is just a test'
                                                             ],
                                    'host-os-name' => [
                                                        'CentOS'
                                                      ],
                                    'group-domains' => [
                                                         'foo.bar'
                                                       ],
                                    'host-net-tcp-autotunemaxbuffer-send' => [
                                                                               '4194304 bytes'
                                                                             ],
                                    'host-net-tcp-maxbuffer-send' => [
                                                                       '124928 bytes'
                                                                     ],
                                    'location-country' => [
                                                            'US'
                                                          ],
                                    'location-code' => [
                                                         '10001'
                                                       ],
                                    'pshost-role' => [
                                                       'science-dmz'
                                                     ],
                                    'host-name' => [
                                                     'host1.foo.bar'
                                                   ],
                                    'pshost-toolkitversion' => [
                                                                 '3.5.0.5'
                                                               ],
                                    'host-net-tcp-congestionalgorithm' => [
                                                                            'cubic'
                                                                          ],
                                    'pshost-bundle-version' => [
                                                                 '3.5.0.5'
                                                               ]
                                  };

#instantiate object
my $record = new perfSONAR_PS::LSRegistrationDaemon::Host;

#add extra config
my %conf = ( 'host_name' => 'host1.foo.bar',
             'domain' => 'foo.bar',
             'site_project' => 'Test',
             'site_name' => 'Foo Bar East',
             'city' => 'New York',
             'region' => 'NY',
             'zip_code' => '10001',
             'country' => 'US',
             'phone' => '5555555555',
             'latitude' => '40.7127',
             'longitude' => '-74.0059',
             'memory' => '1869 MB',
             'os_kernel' => 'Linux 2.6.32-431.29.2.el6.aufs.web100.x86_64',
             'os_name' => 'CentOS',
             'os_version' => '6.6 (Final)',
             'processor_cores' => '4',
             'processor_count' => '2',
             'processor_speed' => '2600.056 MHz',
             'processor_cpuid' => 'Intel(R) Core(TM) i5-3427U CPU @ 1.80GHz',
             'tcp_autotune_max_buffer_recv' => '4194304 bytes',
             'tcp_autotune_max_buffer_send' => '4194304 bytes',
             'tcp_cc_algorithm' => 'cubic',
             'tcp_max_backlog' => '1000',
             'tcp_max_buffer_recv' => '4194304 bytes',
             'tcp_max_buffer_send' => '124928 bytes',
             'tcp_max_achievable' => '9 Gbps',
             'role' => 'science-dmz',
             'bundle_type' => 'perfsonar-toolkit',
             'bundle_version' => '3.5.0.5',
             'access_policy' => 'public',
             'access_policy_notes' => 'This is just a test',
             'is_virtual_machine' => 1,
            );
        
#run standard tests
my $registration = test_ls_record($record, \%conf, TEST_RECORD_HASH);

#run any extra tests
#...

#finish testing
done_testing();