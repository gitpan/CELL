#!perl
use 5.10.0;
use strict;
use warnings FATAL => 'all';
use Data::Printer;
use CELL::Config;
use CELL::Log qw( log_debug log_info );
use Test::More;

plan tests => 4;

my $status = CELL::Log::configure( 'CELLtest' );
log_info("-------------------------------------------------------- ");
log_info("---                   06-config.t                    ---");
log_info("-------------------------------------------------------- ");

my $configdir = $ENV{'CELL_CONFIGDIR'} = $ENV{'PWD'} . "/config";
diag( "CELL config directory is $configdir" );
is( CELL::Config::get_siteconfdir, $configdir, 
    "get_siteconfdir sees and understands the environment variable we just set" );

my $siteconfigfile = "/tmp/CELLtest/siteconfig.conf";
open(my $fh, '>', $siteconfigfile ) or die "Could not open file: $!";
my $stuff = <<EOS;
# This is a test
SITECONF_PATH="$configdir";
EOS
print $fh $stuff;
close $fh;
diag( "Test siteconfigfile is $siteconfigfile" );
is( CELL::Config::_import_cellconf($siteconfigfile), $configdir, "_import_cellconf" );

ok( CELL::Config::_is_viable($configdir), "Configuration directory is viable" );

$status = CELL::Config::init;
ok( $status->ok, "CELL::Config::init OK" );

