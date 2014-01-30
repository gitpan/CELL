package CELL::Status;

use 5.10.0;
use strict;
use warnings;
use Scalar::Util qw( blessed );



=head1 NAME

CELL::Status - class for return value objects



=head1 VERSION

Version 0.065

=cut

our $VERSION = '0.065';



=head1 SYNOPSIS

    use CELL::Status;

    # as a return value: in function XYZ
    return CELL::Status->new( ... );

    # as a return value: in the caller
    my $status = $XYZ( ... );
    return $status if not $status->ok;  # handle failure
    my $payload = $status->payload;     # handle success

    # just to log something more serious than DEBUG or INFO (see
    # CELL::Log for how to log those)
    CELL::Status->new( 'WARN', 'Watch out!' );
    CELL::Status->new( 'NOTICE', 'Look at this!' );



=head1 INHERITANCE

This module inherits from C<CELL::Message>

=cut

use base qw( CELL::Message );



=head1 DESCRIPTION

A CELL::Status object is a reference to a hash containing some or
all of the following keys (attributes):

=over 

=item C<level> - the status level (see L</new>, below)

=item C<message> - message explaining the status

=item C<fullpath> - full path to file where the status occurred

=item C<filename> - alternatively, the name of the file where the status occurred

=item C<line> - line number where the status occurred

=back

The typical use cases for this object are:

=over

=item As a return value from a function call

=item To trigger a higher-level log message

=back

All calls to C<< CELL::Status->new >> with a status other than OK
trigger a log message.



=head1 CONSTANTS


=head2 C<@permitted_levels>

The C<@permitted_levels> array contains a list of permissible log levels.

=cut 

our @permitted_levels = ( 'OK', 'NOTICE', 'WARN', 'ERR', 'CRIT' );



=head1 PUBLIC METHODS

This module provides the following public methods:



=head2 new
 
Construct a status object and trigger a log message if the level is
anything other than "OK". Returns the object.

The most frequent case will be a status code of "OK" with no message (shown
here with optional "payload", which is whatever the function is supposed to
return on success:

    # all green
    return CELL::Status->new( level => 'OK',
                                  payload => $my_return_value,
                                );

To ensure this is as simple as possible in cases when no return value
(other than the simple fact of an OK status) is needed, we provide a
special constructor method:

    # all green
    return CELL::Status->ok;

In most other cases, we will want the status message to be linked to the
filename and line number where the C<new> method was called. If so, we call
the method like this:

    # relative to me
    CELL::Status->new( level => 'ERR', 
                           code => 'CODE1',
                           args => [ 'foo', 'bar' ],
                         );

It is also possible to report the caller's filename and line number:

    # relative to my caller
    CELL::Status->new( level => 'ERR', 
                           code => 'CODE1',
                           args => [ 'foo', 'bar' ],
                           caller => [ caller ],
                         );

It is also possible to pass a message object in lieu of C<code> and
C<msg_args> (this could be useful if we already have an appropriate message
on hand):

    # with pre-existing message object
    CELL::Status->new( level => 'ERR', 
                           msg_obj => $my_msg;
                         );

The C<level> can be one of the following: OK, NOTICE, WARN, ERR, CRIT.

=cut

sub new {
    my $class = shift;
    my $self;
    my %ARGS = (
                    # only level is mandatory
                    level    => '<NO_LEVEL>',
                    @_,
               ); 

    if ( $ARGS{ level } ne 'OK' )
    {
        # default to ERR level
        if ( not grep { $ARGS{level} eq $_ } @permitted_levels ) {
            $ARGS{level} = 'ERR';
        }

        my $parent = $class->SUPER::new(
                             code => $ARGS{code},
                             args => $ARGS{args} || [],
                                  );
        $ARGS{code} = $parent->code;
        $ARGS{text} = $parent->text;
        $ARGS{msgobj} = $parent;
        
        # check for unknown code
        $ARGS{level} = 'ERR' 
                        if $parent->code eq 'CELL_UNKNOWN_MESSAGE_CODE';

        # if caller array not given, create it
        if ( $ARGS{caller} ) {
            ( undef, $ARGS{filename}, $ARGS{line} ) = 
                                                @{ $ARGS{caller} };
        } else {
            ( undef, $ARGS{filename}, $ARGS{line} ) = caller;
        }
    }

    # bless into objecthood
    $self = bless \%ARGS;

    # Log the message
    $self->log;

    # return the created object
    return $self;
}


=head2 log

Write an existing status object to syslog. Takes the object, and logs
it. Always returns true, because we don't want the program to croak just
because syslog is down.

=cut

sub log {
    my $self = shift;
    return 1 if $self->{level} eq 'OK';
    require CELL::Log;
    CELL::Log::status_obj( $self );
}


=head2 ok

If the first argument is blessed, assume we're being called as an
instance method: return true if status is OK, false otherwise.

Otherwise, assume we're being called as a class method: return a 
new OK status object if class is 'CELL::Status', undef otherwise.

=cut

sub ok {

    my ( $class, $self );

    if ( blessed $_[0] ) {

        # instance method
        $self = $_[0];

        if ( not $self->isa( 'CELL::Status' ) ) {
            # we can't return a status object, but we can at least
            # complain to the log
            CELL::Status->new( level => 'ERR',
                                   code => 'IMPROPER_STATUS'
                                 );
            return 0;
        }
        # if it's not an error, it will have status level OK
        return 1 if ( $self->level eq 'OK' );
        # otherwise
        return 0;

    } else {

        # class method
        return CELL::Status->new( level => 'OK' );

    }
        
}


=head2 level

Accessor method.

=cut

sub level {
    my $self = $_[0];

    return $self->{level} if exists $self->{level};
    return "<NO_LEVEL>";
}


=head2 payload

Accessor method.

=cut

sub payload {
    my $self = $_[0];

    return $self->{payload} if exists $self->{payload};
    return "<NO_PAYLOAD>";
}


=head2 msgobj

Accessor method (returns the parent message object)

=cut

sub msgobj {
    my $self = $_[0];

    return $self->{msgobj} if exists $self->{msgobj};
    return undef;
}

1;
