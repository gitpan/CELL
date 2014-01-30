#!perl -T
use 5.10.0;
use strict;
use warnings FATAL => 'all';
use Test::More;
use CELL::Log qw( log_debug log_info );

plan tests => 8;

my $status = CELL::Log::configure( 'CELLtest' );
log_info("-------------------------------------------------------- ");
log_info("---                   01-log.t                       ---");
log_info("-------------------------------------------------------- ");
ok( 1, "Configure logging" );
ok( log_debug( "Testing: DEBUG log message" ), "Testing: DEBUG log message" );
ok( log_info( "Testing: INFO log message" ), "Testing: INFO log message" );
ok( CELL::Log::arbitrary( "NOTICE", "Testing: NOTICE log message" ), "Testing: NOTICE log message" );
ok( CELL::Log::arbitrary( "WARN", "Testing: WARN log message" ), "Testing: WARN log message" );
ok( CELL::Log::arbitrary( "ERR", "Testing: ERR log message" ), "Testing: ERR log message" );
ok( CELL::Log::arbitrary( "CRIT", "Testing: CRIT log message" ), "Testing: CRIT log message" );
ok( CELL::Log::arbitrary( "FUNKY", "Testing: FUNKY log message" ), "Testing: FUNKY log message" );

