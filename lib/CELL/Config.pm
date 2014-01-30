package CELL::Config;

use 5.10.0;
use strict;
use warnings;

use Carp;
use Config::General;
use Data::Printer;
use File::HomeDir;
use File::Spec;

use CELL::Load;
use CELL::Log qw( log_debug log_info );
use CELL::Status;

=head1 NAME

CELL::Config -- load, store, and dispense meta parameters, core
parameters, and site parameters



=head1 VERSION

Version 0.065

=cut

our $VERSION = '0.065';



=head1 SYNOPSIS
 
    use CELL::Config;

    # load meta, core, and site parameters from files
    my $status = CELL::Config::init();
    return $status unless $status->ok;
   
    # get a parameter value (returns value or undef)
    my $value = CELL::Config::get_param( 'meta', 'MY_PARAM' );
    my $value = CELL::Config::get_param( 'core', 'MY_PARAM' );
    my $value = CELL::Config::get_param( 'site', 'MY_PARAM' );

    # set a meta parameter
    CELL::Config::set_meta( 'MY_PARAM', 42 );


=head1 DESCRIPTION

The purpose of the CELL::Config module is to maintain and provide
access to three blessed hashrefs: C<$meta>, C<$core>, and C<$site>,
which hold the names, values, and other information related to the
configuration parameters loaded from files in the site configuration
directory.


=head2 C<$meta>

Holds parameter values loaded from files with names of the format
C<[...]_MetaConfig.pm>. These "meta parameters" are by definition
changeable.

=cut

our $meta;


=head2 C<$core>

Holds parameter values loaded from files whose names match
C<[...]_Config.pm>. Sometimes referred to as "core parameters", these are
intended to be set by the application programmer to provide default values
for site parameters.

=cut

our $core;


=head2 C<$site>

Holds parameter values loaded from files of the format
C<[...]_SiteConfig.pm> -- referred to as "site parameters".
These are intended to be set by the site administrator.

=cut

our $site;



=head1 HOW PARAMETERS ARE INITIALIZED

Like message templates, the meta, core, and site parameters are initialized
by C<require>-ing files in the configuration directory. As described above,
files in this directory are processed according to their filenames. 

The actual directory path is determined by consulting the C<CELL_CONFIGDIR>
environment variable, the file C<.cell/CELL.conf> in the user's C<HOME>
directory, or the file C</etc/sysconfig/perl-CELL>, in that order --
whichever is found first, "wins".

CELL's configuration parameters are modelled after those of Request
Tracker. Configuration files are special Perl modules that are loaded at
run-time.  The modules should be in the C<CELL> package and should consist
of a series of calls to the C<set> function (which is provided by C<CELL>
and will not collide with your application's function of the same name).

CELL configuration files are straightforward and simple to create and
maintain, while still managing to provide power and flexibility. For
details, see the C<CELL_MetaConfig.pm> module in the CELL distribution.



=head1 PUBLIC FUNCTIONS AND METHODS

=head2 init

Re-entrant initialization function.

On first call, initializes all three site configuration hashes by
performing the following actions:

=over

=item 0. checks meta parameter CELL_CONFIG_INITIALIZED -- returns "OK"
status if true.

=item 1. get CELL_CONFIGDIR configuration parameter by consulting (a) the
environment, (b) C<~/.cell/CELL.conf>, and (c) C</etc/sysconfig/perl-CELL>,
in that order, and if none of these options is viable, default to
C</etc/CELL>.

=item 2. load meta parameters and their default values from files whose
names match C<[...]_MetaConfig.pm> -- store these in C<$meta>

=item 3. load core parameters and their default values from files whose
names match C<[...]_Config.pm> -- store these in C<$core>

=item 4. load site parameters and their default values from files whose
names match C<[...]_SiteConfig.pm> -- store these in C<$site>

=back

Takes: nothing, returns status object. To be called like this:

    my $status = CELL::Config::init();

Sets CELL_SITECONF_DIR and CELL_CONFIG_INITIALIZED meta parameters.

=cut

sub init {

    # re-entrant function
    use feature "state";
    state $firsttime = 1;
    return CELL::Status->ok if not $firsttime;

    my ( $status, $siteconfdir );
    my ( $quantfiles, $count ) = 0;

    # get site configuration directory 
    $siteconfdir = get_siteconfdir();
    if ( not $siteconfdir ) {
        return CELL::Status->new (
                    level => 'CRIT',
                    code => 'NO_SITE_CONFIGURATION_DIRECTORY',
                                 );
    }
    set_meta( 'CELL_SITECONF_DIR', $siteconfdir );

    # 2. get and load meta, core, and site config files
    foreach my $type ( 'meta', 'core', 'site' ) {
        no strict 'refs';
        my $file_list = CELL::Load::find_files( $type, $siteconfdir );
        foreach my $file ( @$file_list ) {
            $quantfiles += 1;
            $count += CELL::Load::parse_config_file( File => $file,
                                            Dest => ${ $type } );
        }
    }

    # successful completion
    CELL::Status->new (
                 level => 'NOTICE',
                 code => "Imported $count config parameters from"
                         . " $quantfiles files"
                      );
    $firsttime = 0;
    return CELL::Status->ok;
}


=head2 get_siteconfdir

Look in various places (in a pre-defined order) for the site
configuration directory. Stop as soon as we come up with a plausible
candidate. On success, returns a string containing an absolute
directory path. On failure, returns undef.

=cut

sub get_siteconfdir {

    # re-entrant function
    use feature "state";
    state $siteconfdir = '';
    return $siteconfdir if $siteconfdir;

    # first invocation
    my ( $candidate, $log_message );
    GET_CANDIDATE_DIR: {
        # look in the environment 
        if ( $candidate = $ENV{ 'CELL_CONFIGDIR' } ) {
            $log_message = "Found viable CELL configuration directory"
                           . " in environment variable";
            last GET_CANDIDATE_DIR if _is_viable( $candidate );
        }
    
        # look in the home directory
        my $cellconf = File::Spec->catfile ( 
                                    File::HomeDir::home(), 
                                    '.cell',
                                    'CELL.conf' 
                                           );
        if ( $candidate = _import_cellconf( $cellconf ) ) {
            $log_message = "Found viable CELL configuration directory"
                           . " in ~/.cell/CELL.conf";
            last GET_CANDIDATE_DIR if _is_viable( $candidate );
        }

        # look in /etc/sysconfig/perl-CELL
        $cellconf = File::Spec->catfile ( 
                                    File::Spec->rootdir(),
                                    'etc',
                                    'sysconfig',
                                    'perl-CELL'
                                        );
        if ( $candidate = _import_cellconf( $cellconf ) ) {
            $log_message = "Found viable CELL configuration directory"
                           . " in /etc/sysconfig/perl-CELL";
            last GET_CANDIDATE_DIR if _is_viable( $candidate );
        }

        # fall back to /etc/CELL
        $candidate = File::Spec->catfile (
                                    File::Spec->rootdir(),
                                    'etc',
                                    'CELL',
                                         );
        $log_message = "Found viable CELL configuration directory"
                        . " in /etc/CELL";
        last GET_CANDIDATE_DIR if _is_viable( $candidate );

        # FAIL
        CELL::Status->new(
             level => 'CRIT',
             code => 'Failed to find a viable CELL configuration directory',
                         );
        return undef;
    }

    # SUCCEED
    log_info( $log_message );
    $siteconfdir = $candidate;
    return $siteconfdir;
}


=head3 _import_cellconf

Takes cellconf candidate (full path). Returns site configuration
directory on success, undef on failure.

=cut

sub _import_cellconf {
    my $candidate = shift;
    my ( $problem, $siteconfdir );
    log_debug( "_import_cellconf: candidate ->$candidate<-" ); 
    KONTROLA: {
        if ( not -f $candidate ) {
            $problem = "cellconf candidate ->$candidate<- doesn't exist";
            last KONTROLA;
        }
        if ( -z $candidate ) {
            $problem = "cellconf candidate ->$candidate<- has zero size";
            last KONTROLA;
        }
        if ( not -r $candidate ) {
            $problem = "cellconf candidate ->$candidate<- is not readable";
            last KONTROLA;
        }

        # now we attempt to import configuration from the candidate
        #log_debug("Attempting to parse cellconf candidate ->$candidate<-" );
        my $conf = Config::General->new( $candidate );
        my %cellconf_hash = $conf->getall;
        #log_debug("Loaded " . keys(%cellconf_hash) . " hash elements" );
        if ( not $cellconf_hash{SITECONF_PATH} ) {
            $problem = "No SITECONF_PATH value in cellconf candidate ->$candidate<-";
            last KONTROLA;
        }
        log_info("SITECONF_PATH value from cellconf candidate ->$candidate<-"
                 . " is ->" . $cellconf_hash{'SITECONF_PATH'} . "<-");
        # Config::General doesn't strip quotes
        if ( $cellconf_hash{'SITECONF_PATH'} =~ m/'(?<value>[^']*)'/ ) {
            $cellconf_hash{'SITECONF_PATH'} = $+{'value'};
            log_info("Single quotes stripped from SITECONF_PATH value");
        }
        if ( $cellconf_hash{'SITECONF_PATH'} =~ m/"(?<value>[^"]*)"/ ) {
            $cellconf_hash{'SITECONF_PATH'} = $+{'value'};
            log_info("Double quotes stripped from SITECONF_PATH value");
        }
        log_info( $cellconf_hash{'SITECONF_PATH'} );
        if ( not File::Spec->file_name_is_absolute(
                             $cellconf_hash{'SITECONF_PATH'}) ) {
            $problem = "SITECONF_PATH value is not an absolute path";
            last KONTROLA;
        }
        if ( not -d $cellconf_hash{'SITECONF_PATH'} ) {
            $problem = "SITECONF_PATH value "
                       . $cellconf_hash{'SITECONF_PATH'}
                       . " is not a directory";
            last KONTROLA;
        }

        # we passed all the checks
        $siteconfdir = $cellconf_hash{'SITECONF_PATH'};
    } # KONTROLA

    if ( $problem ) {
        CELL::Log::arbitrary( 'NOTICE', $problem );
        return undef;
    } else {
        CELL::Log::arbitrary( 'NOTICE', "SITECONF_PATH candidate is now ->$siteconfdir<-" );
        return $siteconfdir;
    }
}


=head4 _is_viable

Run viability checks on siteconf candidate. Siteconf candidate _must_ pass
these checks; otherwise, we give up.

=cut

sub  _is_viable {
    my $confdir = shift;
    my $problem;
    CRIT_CHECK: {
        if ( not -d $confdir ) {
            $problem = "Site configuration directory candidate ->$confdir<- is not a directory";
            last CRIT_CHECK;
        }
        if ( not -r $confdir or 
             not -x $confdir ) {
            $problem = "permissions problem on site configuration directory "
            . "candidate ->$confdir<-: we need both 'read' and 'execute'";
            last CRIT_CHECK;
        }
    } # CRIT_CHECK

    if ( $problem ) {
        CELL::Log::arbitrary( 'WARN', $problem );
        return 0;
    } else {
        return 1;
    }
}


=head2 get_param

Basic function providing access to values of site configuration parameters
(i.e. the values stored in the C<%meta>, C<%core>, and C<%site> module
variables). Takes two arguments: type ('meta', 'core', or 'site') and
parameter name. Returns parameter value on success, undef on failure (i.e.
when parameter is not defined).

    my $value = CELL::Config::get_param( 'meta', 'META_MY_PARAM' );

=cut

sub get_param {
    no strict 'refs';
    my ( $type, $param ) = @_;
    if ( not $type or not $param ) {
        CELL::Status->new( 
            level => 'CRIT',
            code => 'CELL::Config::get_param called without proper parameters',
            caller => [ caller ],
                         );
        return undef;
    }
    if ( exists $$type->{$param} ) {
        log_debug( "get_param: returning value ->$$type->{$param}<-"
                   . " for $type config parameter $param" );
        return $$type->{$param};
    } else {
        return undef;
    }
}


=head2 set_meta

By definition, meta parameters are changeable. Use this function to change
them. Takes two arguments: parameter name and new value. If the parameter
didn't exist before, it will be created. Returns a true value.

=cut

sub set_meta {
    my ( $param, $value ) = @_;
    if ( exists $meta->{$param} ) {
        log_info( "Overwriting existing meta parameter $param with new value" );
    } else {
        log_info( "Setting meta parameter $param for the first time" );
    }
    $meta->{$param} = $value;
    return 1;
}

# END OF CELL::Config MODULE
1;
