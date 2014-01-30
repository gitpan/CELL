#!perl
use 5.10.0;
use strict;
use warnings FATAL => 'all';
use Data::Printer;
use CELL::Load;
use CELL::Log qw( log_debug log_info );
use CELL::Message;
use CELL::Test;
use File::Spec;
use File::Touch;
use Test::More;

plan tests => 14;

my $status = CELL::Log::configure( 'CELLtest' );
log_info("-------------------------------------------------------- ");
log_info("---                   03-load.t                      ---");
log_info("-------------------------------------------------------- ");

# Since we haven't run CELL::Config::init, this will just
# initialize a single, hard-coded message CELL_UNKNOWN_MESSAGE_CODE/en
CELL::Message::init();

log_info("*****");
log_info("***** TESTING find_files for 'message' type" );
my $tmpdir = CELL::Test::mktmpdir();
my @file_list = qw{ 
                     CELL_Message.conf
                     CELL_Message_en.conf
                     Dochazka_MetaConfig.pm
                     Bubba_MetaConfig.pm
                     adfa343kk.conf
                     Dochazka_SiteConfig.pm
                     Dochazka_Config.pm
                  };
my $count1 = CELL::Test::touch_files( $tmpdir, @file_list );

# now we have some files in $tmpdir
my $return_list = CELL::Load::find_files( 'message', $tmpdir );

# how many matched the regex?
my $count2 = keys( @$return_list );
diag( "Touched $count1 files; $count2 of them match the regex" );
ok( $count2 == 2, "find_files found the right number of files" );

# which ones?
#my @return_files = map { s|^.*/(?=[^/]*$)||g; $_; } @return_list;
my @return_files = map { 
        my ( undef, undef, $file ) = File::Spec->splitpath( $_ );
        $file;
                       } @$return_list;
my @should_be = ( 'CELL_Message.conf', 'CELL_Message_en.conf' );
ok( CELL::Test::cmp_arrays( \@return_files, \@should_be ), 
    "find_files found the right files" );

# what about meta, core, and site configuration files?
$return_list = CELL::Load::find_files( 'meta', $tmpdir );
ok( keys( @$return_list ) == 2, "Right number of meta config files" );
$return_list = CELL::Load::find_files( 'core', $tmpdir );
ok( keys( @$return_list ) == 1, "Right number of core config files" );
$return_list = CELL::Load::find_files( 'site', $tmpdir );
ok( keys( @$return_list ) == 1, "Right number of site config files" );


log_info("*****");
log_info("***** TESTING parse_message_file" );
my $full_path = File::Spec->catfile( $tmpdir, $file_list[0] );
#diag( "Opening $full_path for writing" );
open(my $fh, '>', $full_path ) or die "Could not open file: $!";
my $stuff = <<'EOS';
# This is a test


TEST_MESSAGE
OK


   TEST_MESSAGE
OKAY

BORKED_MESSAGE
Bimble bomble brum

EOS
print $fh $stuff;
close $fh;
my %messages;
#diag( "BEFORE: %messages has " . keys(%messages) . " keys" );
CELL::Load::parse_message_file( File => $full_path, Dest => \%messages );
#diag( "Loaded " . keys(%messages) . " message codes from $full_path" );
#p(%messages);
ok( exists $messages{'TEST_MESSAGE'}, "TEST_MESSAGE loaded from file" );
is( $messages{'TEST_MESSAGE'}->{'en'}->{'Text'}, "OK", "TEST_MESSAGE has the right text");


log_info("*****");
log_info("***** TESTING parse_config_file" );
$return_list = CELL::Load::find_files( 'meta', $tmpdir );
is( scalar @$return_list, 2, "Found right number of meta config files");
#diag( "Meta config file found: $return_list->[0]" );
$full_path = $return_list->[0];
open($fh, '>', $full_path ) or die "Could not open file: $!";
$stuff = <<'EOS';
# This is a test
set( 'TEST_PARAM_1', 'Fine and dandy' );
set( 'TEST_PARAM_2', [ 0, 1, 2 ] );
set( 'TEST_PARAM_3', { 'one' => 1, 'two' => 2 } );
set( 'TEST_PARAM_1', 'Now is the winter of our discontent' );
set( 'TEST_PARAM_4', sub { 1; } );
1;
EOS
print $fh $stuff;
close $fh;
my %params = ();
my $count = CELL::Load::parse_config_file( File => $full_path, Dest => \%params );
#p( %params );
is( keys( %params ), 4, "Correct number of parameters loaded from file" );
is( $count, keys( %params ), "Return value matches number of parameters loaded");
ok( exists $params{ 'TEST_PARAM_1' }, "TEST_PARAM_1 loaded from file" );
is( $params{ 'TEST_PARAM_1' }->{ 'Value' }, "Fine and dandy", "TEST_PARAM_1 has the right value" );
is_deeply( $params{ 'TEST_PARAM_2' }->{ 'Value' }, [ 0, 1, 2], "TEST_PARAM_2 has the right value" );
is_deeply( $params{ 'TEST_PARAM_3' }->{ 'Value' }, { 'one' => 1, 'two' => 2 }, "TEST_PARAM_3 has the right value" );
