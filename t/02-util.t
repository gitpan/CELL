#!perl -T
use 5.10.0;
use strict;
use warnings FATAL => 'all';
use CELL::Log qw( log_info );
use CELL::Util qw( timestamp );
use Test::More;

plan tests => 1;

my $status = CELL::Log::configure( 'CELLtest' );
log_info("-------------------------------------------------------- ");
log_info("---                   02-util.t                      ---");
log_info("-------------------------------------------------------- ");
# test that CELL::Util::timestamp returns something that looks
# like a timestamp
my $timestamp_regex = qr/\d{4,4}-[A-Z]{3,3}-\d{1,2} \d{2,2}:\d{2,2}/a;
ok( timestamp() =~ $timestamp_regex, "CELL::Util::timestamp" );
diag( "Timestamp: " . timestamp() );
