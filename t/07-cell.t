#!perl
use 5.10.0;
use strict;
use warnings FATAL => 'all';
use Data::Printer;
use Test::More;
use CELL;
use CELL::Log qw( log_debug log_info );

plan tests => 2;

my $status = CELL::Log::configure( 'CELLtest' );
log_info("-------------------------------------------------------- ");
log_info("---                    07-cell.t                     ---");
log_info("-------------------------------------------------------- ");

my $bool = CELL->meta( 'CELL_CONFIG_INITIALIZED' );
ok( ! $bool, "CELL should not think it is initialized" );

$ENV{'CELL_CONFIGDIR'} = $ENV{'PWD'} . "/config";
$status = CELL->init;
ok( $status->ok, "CELL initialization OK" );
