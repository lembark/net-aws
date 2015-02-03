########################################################################
# housekeeping
########################################################################
package Net::AWS::TreeHash;
use v5.20;
use autodie;
use experimental 'lexical_subs';

use Const::Fast;

use Carp            qw( croak           );
use Digest::SHA     qw( sha256          );
use List::Util      qw( max             );
use Scalar::Util    qw( blessed         );
use Symbol          qw( qualify_to_ref  );

########################################################################
# package variables
########################################################################

our $VERSION = '0.71';
$VERSION = eval $VERSION;

my $empty   = sha256 '';

########################################################################
# utility subs
########################################################################

my sub MiB() { 2 ** 20 };

my $reduce_hash
= sub
{
    # iterate reducing the pairs of 1MiB data units to a single value.
    # "2 > @_" intentionally returns undef for an empty list.

    return $_[0]
    if 2 > @_;

    const my $chunks => ( @_ / 2 ) + ( @_ % 2 );

    @_  
    = map
    {
        const my $i => 2 * ( $_ - 1 );

        sha256 @_[ $i .. max( $i+1, $#_) ]
    }
    ( 1 .. $chunks );

    goto __SUB__
};

my $buffer_hash
= sub
{
    state $format   = '(a' . MiB . ')*';

    my $buffer  = shift;
    my $size    = length $buffer
    or return;

    $reduce_hash->
    (
        map
        {
            sha256 $_
        }
        unpack $format, $buffer
    )
};

sub import
{
    my $caller  = caller;

    grep { ':tree_hash' eq $_ } @_
    and
    *{ qualify_to_ref 'tree_hash', $caller  } = \&tree_hash;

    grep { ':reduce_hash' eq $_ } @_ 
    and
    *{ qualify_to_ref 'reduce_hash', $caller  } = $reduce_hash;

    return
}

########################################################################
# methods
########################################################################

########################################################################
# construction

sub construct
{
    my $proto   = shift;
    bless [], blessed $proto || $proto
}
sub initialize
{
    my $t_hash  = shift;
    @$t_hash    = ();
    return
}
sub new
{
    my $t_hash  = &construct;
    $t_hash->initialize( @_ );
    $t_hash
}

########################################################################
# caller partitions the input, adds hashes to the object.

sub tree_hash
{
    blessed $_[0] and shift;

    &$buffer_hash
}

sub part_hash
{
    my ( $t_hash, $buffer ) = @_;

    $t_hash->[ @$t_hash ] = $buffer_hash->( $buffer )
}

sub final_hash
{
    my $t_hash  = shift;

    @$t_hash
    or croak 'Bogus final_hash: no part hashes available';

    $reduce_hash->( @$t_hash )
}

# keep require happy
1

__END__

=head1 SYNOPSIS

This module implements TreeHash algorithm for Amazon AWS
Glacier API (version 2012-06-01)

Usage:

	use Net::Amazon::TreeHash qw( :import );

    # simplest cases: compute the hash of a non-partitioned data.

    my $hash    = tree_hash( $buffer );

    # for multi-part uploads accumulate the partition hashses and
    # get a final one at the end.

	my $t_hash  = Net::Amazon::TreeHash->new();

    while( my $part = next_chunk_of_data )
    {

        my $hash    = $t_hash->part_hash( $part );

        send_partition ... $hash ... $part;
    }

    my $total_hash  = $t_hash->final_hash;

    send_final_message $total_hash;

    # at this point either let $t_hash go out of scope
    # or call $t_hash->initialize to reset the list of
    # partition hashes.

=head1 DESCRIPTION

Note: Perl-5.20 added internal Copy on Write semantics for strings.
This obviates the need for pass-by-reference for the buffers: they
are passed as strings with the internal COW mechanics minimizing
the overhead.



=head1 SEE ALSO

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

=head1 BUGS

=cut

