package perfSONAR_PS::LSRegistrationDaemon::UnitTests::Util;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::UnitTests::Util - Utility class for init tests

=head1 DESCRIPTION

This module provides methods for writing unit tests
=cut

use strict;
use warnings;

our $VERSION = 3.5;

use base 'Exporter';
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);
use Test::More;
use Config::General;

our @EXPORT_OK = qw( test_ls_record test_ls_record_with_signature);

use constant TEST_CONF => "$Bin/../etc/lsregistrationdaemon.conf";
use constant TEST_LS_INSTANCE => 'http://foo.bar';
use constant TEST_CLIENT_UUID_FILE => "$Bin/test_data/client_uuid";
use constant TEST_KEY_DB => "$Bin/test_data/lsKey.db";


sub test_ls_record {
    my ($record, $extra_conf, $reg_hash) = @_;
    
    # disable logging
    Log::Log4perl->easy_init( {level => 'OFF'} );
    
    #build basic config
    my %conf = build_basic_config();

    foreach my $opt(keys %{ $extra_conf }){
        $conf{$opt} = $extra_conf->{$opt};
    }
    #test_init
    ok($record->init(\%conf) == 0, "service init");

    #test building registration
    my $registration;
    ok( $registration = $record->build_registration(), "create registration object");
    is_deeply($registration->{RECORD_HASH}, $reg_hash, "record check");
    
    # use Data::Dumper;
    # print Dumper($registration);
    
    return $registration;
}


sub test_ls_record_with_signature {
    my ($record, $extra_conf, $reg_hash) = @_;

    # disable logging
    Log::Log4perl->easy_init( {level => 'OFF'} );

    #build basic config
    my %conf = build_basic_config();
    $conf{'add_signature'} = 1;
    $conf{'signing_key'} = "$Bin/input/recordsign_test_key.pem";
    foreach my $opt(keys %{ $extra_conf }){
        $conf{$opt} = $extra_conf->{$opt};
    }
    $record->init(\%conf);


    #test building registration
    my $registration;
    ok( $registration = $record->build_registration(), "create registration object");
    is_deeply($registration->{RECORD_HASH}, $reg_hash, "record check");


    $registration->addsign($record->{PS_PRIVATE_KEY});

    my $first_signature = $registration->{RECORD_HASH}->{'signature'}->[0];

    ok(defined($registration->{RECORD_HASH}->{'signature'}), "check if signature has been added");
    print $registration->toJson;

    $registration->addsign($record->{PS_PRIVATE_KEY});

    my $second_signature = $registration->{RECORD_HASH}->{'signature'}->[0];

    ok($first_signature eq $second_signature, "check if signature is reproducible");


    # use Data::Dumper;
    # print Dumper($registration);

    return $registration;
}


sub build_basic_config {
    my %conf = ();
    $conf{'ls_instance'} =  TEST_LS_INSTANCE;
    $conf{'client_uuid_file'} = TEST_CLIENT_UUID_FILE;
    $conf{'ls_key_db'} = TEST_KEY_DB;
    $conf{'allow_internal_addresses'} = 1; #increase autodetection chances
    return %conf;
}

1;