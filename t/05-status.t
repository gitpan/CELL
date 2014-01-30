#!perl -T
use 5.10.0;
use strict;
use warnings FATAL => 'all';
use Data::Printer;
use CELL::Log qw( log_debug log_info );
use CELL::Status;
use Test::More;

plan tests => 5;

my $status = CELL::Log::configure( 'CELLtest' );
log_info("-------------------------------------------------------- ");
log_info("---               05-status.t PRE-INIT               ---");
log_info("-------------------------------------------------------- ");

# test functions in Status.pm "in a vacuum" (just the functions with
# no particular context)

$status = CELL::Status->new( 
            level => 'NOTICE',
            code => "Pre-init notice w/arg ->%s<-",
            args => [ "CONTENT" ],
                             );
ok( ! $status->ok, "Our pre-init status is not OK" );
is( $status->msgobj->text, "Pre-init notice w/arg ->CONTENT<-", "Access message object through the status object" );

$status = CELL::Status->ok;
ok( $status->ok, "Our pre-init status is OK" );

$status = CELL::Status->new(
            level => 'CRIT',
            code => "This is just a test. Don't worry; be happy.",
            payload => "FOOBARBAZ",
                            );
is( $status->payload, "FOOBARBAZ", "Payload accessor function returns the right value" );
is( $status->level, "CRIT", "Level accessor function returns the right value" );
