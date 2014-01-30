package CELL::Log;

use 5.10.0;
use strict;
use warnings;

# IMPORTANT: this module must not depend on any other CELL modules
use File::Spec;
use Log::Fast;



=head1 NAME

CELL::Log - basic logging to syslog facility



=head1 VERSION

Version 0.065

=cut

our $VERSION = '0.065';



=head1 SYNOPSIS

    use CELL::Log qw( log_debug log_info );

    # configure logging -- need only be done once
    my $status = CELL::Log::configure();  
    return $status unless $status->ok;

    # Info and debug messages are created by calling log_info and
    # log_debug, respectively
    log_info  ( "Info-level message"  );
    log_debug ( "Debug-level message" );

    # Arbitrary log message (use sparingly -- see CELL::Status
    # for a way to trigger higher-level log messages
    CELL::Log::arbitrary( 'WARN', "Be warned!" );

    # Log a status object (don't do this: it happens automatically when
    # status object is constructed)
    CELL::Log::status_obj( $status_obj );



=head1 EXPORTS

This module exports the following functions:

=over 

=item C<log_debug>

=item C<log_info>

=back

=cut 

use Exporter qw( import );
our @EXPORT_OK = qw( log_debug log_info );



=head1 DESCRIPTION

The C<CELL::Log> module provides for "log-only messages" (see
Localization section of the top-level README for a discussion of the
different types of CELL messages).



=head1 FUNCTIONS


=head2 configure

Configures logging the way we like it. Takes one argument: the 'ident'
(identifier) string, which will probably be the application name. If not
given, defaults to 'CELL'. Returns status object.

TO DO: get ident and default log-level from site configuration, if
available.
TO DO: if we've already completed CELL server initialization, return
without doing anything

Returns: true on success, false on failure

=cut

sub configure {
    my $ident = shift;

    # re-entrant function: run only if (a) we haven't been initialized
    # at all yet, or (b) we were initialized under a different ident
    # string
    use feature "state";
    state $initialized = '';
    if ( $ident eq $initialized ) {
        log_info( "Logging already configured" );
        return 1;
    }

    # first invocation or change of ident
    if ( eval {
            my $LOG = Log::Fast->global();
            $LOG->config(
                { 
                    ident  => $ident,
                    level  => 'DEBUG',
                    prefix => '[%L] ',
                    type   => 'unix', 
                }
            );
            1;
        } )
    { 
        $initialized = $ident;
        return 1;
    }
    else
    { 
        # this might happen if syslog is not running
        print STDERR "CELL WARNING LOGGER_INIT_FAIL: $@";
        return 0;
    }
}


=head2 log_debug

Exportable function. Takes a string and writes it to syslog with log
level "DEBUG". Always returns true.

=cut

sub log_debug {
    
    # get argument
    my $msg_text = $_[0];

    # get Log::Fast object
    my $LOG = Log::Fast->global();

    # write message
    $LOG->DEBUG( _assemble_log_message( $msg_text, caller ) );

    return 1;
}


=head2 log_info

Exportable function. Takes a string and writes it to syslog with log
level "INFO". Always returns true.

=cut

sub log_info {
    
    # get argument
    my $msg_text = $_[0];

    # get Log::Fast object
    my $LOG = Log::Fast->global();

    # write message
    $LOG->INFO( _assemble_log_message( $msg_text, caller ) );

    return 1;
}


=head2 arbitrary

Write an arbitrary message to any log level. Takes two string arguments:
log level and message to write.

=cut

sub arbitrary {
    # get arguments
    my ( $level, $msg_text ) = @_;
    $level = uc $level;

    # get Log::Fast object
    my $LOG = Log::Fast->global();

    # ensure sanity
    if ( not $msg_text ) { $msg_text = '<NONE>'; }
    if ( not grep { $level eq $_ } 
             ( 'DEBUG', 'INFO', 'NOTICE', 'WARN', 'ERR', 'CRIT' ) ) 
    {
        my ( $pkg, $file, $line ) = caller;
        $msg_text .= " <- detected attempt to to log this message at"
        . " unknown level $level in $pkg ($file) line $line";
        $level = 'WARN';
    }
    if ( $level eq 'CRIT' ) {
        $level = 'ERR';
        $msg_text = "CRITICAL: " . $msg_text;
    }
    $LOG->$level( $msg_text );

    return 1;
}


=head2 status_obj

Take a status object and log it.

=cut

sub status_obj {
    my $status_obj = $_[0];
    my $LOG = Log::Fast->global();
    my $level = $status_obj->{level};
    my $msg_text = $status_obj->text;
    my $pkg = undef;
    my $file = $status_obj->{filename};
    my $line = $status_obj->{line};

    if ( $level eq 'CRIT' ) {
        $msg_text = 'CRITICAL: ' . $msg_text;
        $level = 'ERR';
    }

    $LOG->$level( 
        _assemble_log_message( $msg_text, $pkg, $file, $line ) );
}

sub _assemble_log_message {
    my ( $message, $package, $filename, $line ) = @_;

    if ( File::Spec->file_name_is_absolute( $filename ) ) {
       ( undef, undef, $filename ) = File::Spec->splitpath( $filename );
    }
    return "$message at $filename line $line";
}

1;
