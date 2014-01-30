package CELL::Message;

use 5.10.0;
use strict;
use warnings;
use Data::Printer;
use CELL::Config;
use CELL::Log qw( log_debug log_info );



=head1 NAME

CELL::Message - handle messages the user might see



=head1 VERSION

Version 0.065

=cut

our $VERSION = '0.065';



=head1 SYNOPSIS

    use CELL::Message;

    # server messages: pass message code only, message text
    # will be localized to the site default language, if 
    # assertainable, or, failing that, in English
    my $message = CELL::Message->new( code => 'FOOBAR' )
    # and then we pass $message as an argument to 
    # CELL::Status->new

    # client messages: pass message code and session id,
    # message text will be localized according to the user's language
    # preference setting
    my $message = CELL::Message->new( code => 'BARBAZ',
                                          session => $s_obj );
    $msg_to_display = $message->CELL::Message->text;

    # a message may call for one or more arguments. If so,
    # include an 'args' hash element in the call to 'new':
    args => [ 'FOO', 'BAR' ]
    # they will be included in the message text via a call to 
    # sprintf



=head1 EXPORTS AND PUBLIC METHODS

This module provides the following public functions and methods:

=over 

=item C<new> - construct a C<CELL::Message> object

=item C<text> - get text of an existing object

=item C<max_size> - get maximum size of a given message code

=back

=cut 



=head1 DESCRIPTION

A CELL::Message object is a reference to a hash containing some or
all of the following keys (attributes):

=over 

=item C<code> - message code (see below)

=item C<text> - message text

=item C<language> - message language (e.g., English)

=item C<max_size> - maximum number of characters this message is
guaranteed not to exceed (and will be truncated to fit into)

=item C<truncated> - boolean value: text has been truncated or not

=back

The information in the hash is sourced from two places: the
C<$mesg> hashref in this module (see L</CONSTANTS>) and the SQL
database. The former is reserved for "system critical" messages, while
the latter contains messages that users will come into contact with on
a daily basis. System messages are English-only; only user messages
are localizable.



=head1 CONSTANTS

=head2 C<@min_supp_lang>)

The minimal list of supported languages, specified by their respective
language tags (currently 'en-US' only).

See the W3C's "Language tags in HTML and XML" white paper for a
detailed explanation of language tags:

    http://www.w3.org/International/articles/language-tags/

And see here for list of all language tags:

    http://www.langtag.net/registries/lsr-language.txt

=cut

our @min_supp_lang = ( 'en' );


=head2 C<$mesg>

The C<CELL::Message> module stores messages in a package variable, C<$mesg>
(which is a hashref).

=cut 

our $mesg;



=head1 FUNCTIONS AND METHODS


=head2 init

Load messages (keys and values) from the relevant configuration file(s).
Be re-entrant.

=cut

sub init {

    # re-entrant function
    use feature "state";
    state $firsttime = 1;
    return CELL::Status->ok if not $firsttime;

    my ( $status, $count );

    INIT_BLOCK: {

        my $quantfiles = 0;
        # get site configuration directory 
        my $configdir = CELL::Config::get_siteconfdir();
        if ( not $configdir ) {
            $status = CELL::Status->new (
                    level => 'CRIT',
                    code => 'NO_SITE_CONFIGURATION_DIRECTORY',
                                        );
            last INIT_BLOCK;
        }

        # initialize $mesg
        $mesg = {};

        # find message files in $configdir
        my $message_files = CELL::Load::find_files( 'message', $configdir );
    
        foreach my $file ( @$message_files ) {
            $quantfiles += 1;
            $count = CELL::Load::parse_message_file( File => $file,
                                            Dest => $mesg );
            CELL::Log::arbitrary ( 'NOTICE',
                      "Imported $count messages from file $file" );
        }
        if ( not $count ) {
            $status = CELL::Status->new (
                    level => 'WARN',
                    code => 'CELL_NO_MESSAGES_LOADED',
                                        );
            last INIT_BLOCK;
        }

        # success
        $firsttime = 0;
        CELL::Status->new (
                    level => 'NOTICE',
                    code => "Imported $count messages from"
                            . " $quantfiles files"
                          );
        return CELL::Status->ok;

    }

    # if, for some reason, we fail to get configured . . .
    $mesg->{ 'CELL_UNKNOWN_MESSAGE_CODE' } = { 
                                                'en' => { 
                        'Text' => "Unknown message code ->%s<-" 
                                                        }
                                             };
    return $status;
}


=head2 new
  
Construct a message object. Takes a message code and, optionally, a
reference to an array of arguments. Returns the object. See L</SYNOPSIS>.

=cut

sub new {
    my $class = shift;
    my %ARGS = (
                code => '<NO_CODE>',
                @_,
               ); 
    my $text;

    if ( CELL::Config::get_param('meta','CELL_CONFIG_INITIALIZED') )
    {
        # if code not found, deal with it
        if ( not exists $mesg->{ $ARGS{code} } ) {
            $ARGS{args} = [ $ARGS{code} || '<NO_CODE>' ];
            $ARGS{code} = 'CELL_UNKNOWN_MESSAGE_CODE';
        }
        $text = $mesg->{ $ARGS{code} }->{ 'en' }->{ 'Text' };
    }
    else 
    {
        # special regime if running before config initialization
        $text = $ARGS{code};
    }

    # strip out anything that resembles a newline
    $text =~ s/\n//g;
    $text =~ s/\o{12}/ -- /g;

    $ARGS{text} = sprintf( $text, @{ $ARGS{args} || [] } );

    # bless into objecthood
    my $self = bless \%ARGS;

    # Log everything -- check a site configuration parameter for this?
    CELL::Log::log_debug( "Message object " . $ARGS{code} . " created" );

    # return the created object
    return $self;
}


=head2 code

Accessor method for the 'code' attribute.

=cut

sub code {
    my $self = $_[0];

    if ( not $self->{code} ) {
        return 'CELL_UNKNOWN_MESSAGE_CODE';
    } else {
        return $self->{code};
    }
}


=head2 args

Accessor method for the 'args' attribute.

=cut

sub args {
    my $self = $_[0];

    if ( not $self->{args} ) {
        return [];
    } else {
        return $self->{args};
    }
}


=head2 text
 
Accessor method for the 'text' attribute. Returns content of 'text'
attribute, or "<NO_TEXT>" if it can't find any content.

=cut

sub text {
    my $self = $_[0];
    
    if ( not $self->{text} ) {
        return "<NO_TEXT>";
    } else {
        return $self->{text};
    }
}

1;
