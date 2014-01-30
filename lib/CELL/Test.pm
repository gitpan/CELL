package CELL::Test;

use 5.10.0;
use strict;
use warnings;
use CELL::Log qw( log_debug log_info );
use File::Spec;
use File::Touch;

=head1 NAME

CELL::Test - functions for unit testing 


=head1 VERSION

Version 0.065

=cut

our $VERSION = '0.065';



=head1 SYNOPSIS

    use CELL::Test;



#use Exporter qw( import );
#our @EXPORT_OK = qw( log_debug log_info );


=head1 DESCRIPTION

The C<CELL::Test> module provides a number of special-purpose functions for
use in CELL's test suite. 



=head1 CONSTANTS

=cut

use constant CELLTESTDIR => 'CELLtest';



=head1 FUNCTIONS


=head2 mktmpdir

First wipes, and then creates, the 'CELLtest' directory in C</tmp> and
returns the path to this directory or "undef" on failure.

=cut

sub mktmpdir {
    my $tmpdir = File::Spec->catfile( 
                        File::Spec->rootdir, 
                        'tmp', 
                        CELLTESTDIR,
                                    );
    eval { mkdir $tmpdir; };
    if ( $@ ) {
        my $errmsg = $@;
        $errmsg =~ s/\n//g;
        $errmsg =~ s/\o{12}/ -- /g;
        $errmsg = "Attempting to create $tmpdir . . . failure: $errmsg";
        log_debug( $errmsg );
        print STDERR $errmsg, "\n";
        return undef;
    } else {
        log_debug( "Attempting to create $tmpdir . . . success" );
        return $tmpdir;
    }
}


=head2 touch_files

"Touch" some files. Takes: directory path and list of files to "touch" in
that directory. Returns number of files successfully touched.

=cut

sub touch_files {
    my ( $dirspec, @file_list ) = @_;
    my $count = @file_list;
    eval { 
        touch( map { 
                        File::Spec->catfile( $dirspec, $_ ); 
                   } @file_list );
    };
    if ( $@ ) {
        my $errmsg = $@;
        $errmsg =~ s/\n//g;
        $errmsg =~ s/\o{12}/ -- /g;
        $errmsg = "Attempting to 'touch' $count files in $dirspec . . . failure: $errmsg";
        log_debug( $errmsg );
        print STDERR $errmsg, "\n";
        return 0;
    } else {
        log_debug( 
            "Attempting to 'touch' $count files in $dirspec . . .  success" 
                 );
        return $count;
    }
}


=head2 cmp_arrays

Compare two arrays of unique elements, order doesn't matter. 
Takes: two array references
Returns: true (they have the same elements) or false (they differ).

=cut

sub cmp_arrays {
    my ( $ref1, $ref2 ) = @_;
        
    log_debug( "cmp_arrays: we were asked to compare two arrays:");
    log_debug( "ARRAY #1: " . join( ',', @$ref1 ) );
    log_debug( "ARRAY #2: " . join( ',', @$ref2 ) );

    # convert them into hashes
    my ( %ref1, %ref2 );
    map { $ref1{ $_ } = ''; } @$ref1;
    map { $ref2{ $_ } = ''; } @$ref2;

    # make a copy of ref1
    my %ref1_copy = %ref1;

    # for each element of ref1, if it matches an element in ref2, delete
    # the element from _BOTH_ 
    foreach ( keys( %ref1_copy ) ) {
        if ( exists( $ref2{ $_ } ) ) {
            delete $ref1{ $_ };
            delete $ref2{ $_ };
        }
    }

    # if the two arrays are the same, the number of keys in both hashes should
    # be zero
    log_debug( "cmp_arrays: after comparison, hash #1 has " . keys( %ref1 )
    . " elements and hash #2 has " . keys ( %ref2 ) . " elements" );
    if ( keys( %ref1 ) == 0 and keys( %ref2 ) == 0 ) {
        return 1;
    } else {
        return 0;
    }
}

1;
