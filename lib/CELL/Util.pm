package CELL::Util;

use 5.10.0;
use strict;
use warnings;
use Date::Format;

=head1 NAME

CELL::Util - various reuseable functions



=head1 VERSION

Version 0.065

=cut

our $VERSION = '0.065';



=head1 SYNOPSIS

    use CELL::Util qw( timestamp );

=cut


=head1 EXPORTS

This module provides the following public functions:

=over 

=item C<timestamp>

=back

=cut 

use Exporter qw( import );
our @EXPORT_OK = qw( timestamp );


=head1 FUNCTIONS

=head2 timestamp

=cut

sub timestamp {
   return uc time2str("%Y-%b-%d %H:%M", time, 'GMT');
}

1;
