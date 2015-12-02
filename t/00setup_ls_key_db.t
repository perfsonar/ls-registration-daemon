#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 6;

use DBI;

use constant TEST_KEY_DB => "$Bin/test_data/lsKey.db";
note("Test DB can be found at " . TEST_KEY_DB);

#Create test database
my $ls_key_dbh = DBI->connect('dbi:SQLite:dbname=' . TEST_KEY_DB, '', '')  or BAIL_OUT("cannot connect to database");

#Test table creation
my $ls_key_create;
ok( $ls_key_create = $ls_key_dbh->prepare('CREATE TABLE IF NOT EXISTS lsKeys (uri VARCHAR(255) PRIMARY KEY, expires BIGINT NOT NULL, checksum VARCHAR(255) NOT NULL, duplicateChecksum VARCHAR(255) NOT NULL)'), "test table creation prepared");
ok( $ls_key_create->execute(), 'test table creation executed');
is($ls_key_create->err, undef, 'No creation errors') or BAIL_OUT("test table creation failed. can't perform other tests.");

#Test table cleanup
my $ls_key_clean_expired;
ok($ls_key_clean_expired = $ls_key_dbh->prepare('DELETE FROM lsKeys WHERE expires < ?'), 'expired record cleanup statement prepared ');
ok($ls_key_clean_expired->execute(time), "expired record cleanup statement executed");
is($ls_key_clean_expired->err, undef, 'No expired record cleanup errors') or BAIL_OUT("expired recourd cleanup failed. can't perform other tests.");
