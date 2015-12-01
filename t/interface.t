#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Test::More;
use perfSONAR_PS::LSRegistrationDaemon::UnitTests::Util qw( test_ls_record );

use perfSONAR_PS::LSRegistrationDaemon::Interface;

#constants
use constant TEST_RECORD_HASH => {
                                    'group-domains' => [
                                                         'es.net'
                                                       ],
                                    'interface-mtu' => [
                                                         '9000'
                                                       ],
                                    'interface-capacity' => [
                                                              '10000000000'
                                                            ],
                                    'interface-mac' => [
                                                         '09:12:37:2B:77:8B'
                                                       ],
                                    'interface-name' => [
                                                          'eth0'
                                                        ],
                                    'psinterface-urns' => [
                                                            'urn:ogf:network:foo.bar:eth0'
                                                          ],
                                    'type' => [
                                                'interface'
                                              ],
                                    'interface-addresses' => [
                                                               '10.0.0.1'
                                                             ],
                                    'interface-subnet' => [
                                                            '255.255.255.252'
                                                          ]
                                  };

#instantiate object
my $record = new perfSONAR_PS::LSRegistrationDaemon::Interface;

#add extra config
my %conf = ( 'address' => '10.0.0.1',
             'capacity' => '10000000000',
             'domain' => 'es.net',
             'if_name' => 'eth0',
             'mac_address' => '09:12:37:2B:77:8B',
             'mtu' => '9000',
             'subnet' => '255.255.255.252',
             'urn' => 'urn:ogf:network:foo.bar:eth0',
            );
        
        
#run standard tests
my $registration = test_ls_record($record, \%conf, TEST_RECORD_HASH);

#run any extra tests
#...

#finish testing
done_testing();