########################################################################
# housekeeping
########################################################################
package Net::AWS::TreeHash;
use v5.20;
use autodie;
use experimental qw( lexical_subs autoderef );

use Const::Fast;

use Carp            qw( croak           );
use Digest::SHA     qw( sha256          );
use List::Util      qw( max             );
use Scalar::Util    qw( blessed         );
use Symbol          qw( qualify_to_ref  );

########################################################################
# package variables
########################################################################

our $VERSION = '0.80';
$VERSION = eval $VERSION;

my $empty   = sha256 '';

########################################################################
# utility subs
########################################################################

const my $reduce_hash =>
sub
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

const my $buffer_hash =>
sub
{
    state $format   = '(a' . 2**20 . ')*';

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
    shift;

    if( @_ )
    {
        my $caller  = caller;

        for
        (
            [ tree_hash     => \&tree_hash      ],
            [ tree_hash_hex => \&tree_hash_hex  ],
            [ reduce_hash   => $reduce_hash     ],
            [ buffer_hash   => $buffer_hash     ],
        )
        {
            my ( $name, $ref ) = @$_;

            grep { "$name" eq $_ } @_
            or next;

            *{ qualify_to_ref $name, $caller  } = $ref;
        }
    }

    return
}

########################################################################
# methods
########################################################################

sub tree_hash
{
    ref $_[0]
    ? $reduce_hash->( values $_[0] )
    : &$buffer_hash
}

sub tree_hash_hex
{
    unpack 'H*', &tree_hash
}

# keep require happy
1

__END__

=head1 SYNOPSIS

This module implements TreeHash algorithm for Amazon AWS
Glacier API (version 2012-06-01)

Usage:

	use Net::Amazon::TreeHash qw( tree_hash );

    # simplest cases: compute the hash of a non-partitioned data.

    my $hash    = tree_hash( $buffer );

    # hash partitions (e.g. with glacier):

    my @part_hashes = ();

    for(;;)
    {
        my $chunk   = read_next_chunk
        or last;

        push @part_hashes, tree_hash $chunk;

        upload_partition $chunk, $part_hashes[-1];
    }

    # the hash list is passed as an arrayref to distinguish it
    # from a buffer being hashed.

    my $final_hash  = tree_hash \@tree_hashes;

    # sha256 results don't play nice with printf.
    # either use  unpack 'H*', tree_hash ... ;
    # or call tree_hash_hex

    my $hash_hex    = tree_hash_hex $buffer;
    my $hash_hex    = tree_hash_hex \@tree_hashes;

=head1 DESCRIPTION

This module requires at least Perl v5.20, which added internal Copy on 
Write semantics for strings.  This obviates the need for 
pass-by-reference for the buffers: they are passed as strings with the 
internal COW mechanics minimizing the overhead.


=head2 Exports

=over 4

=item tree_hash

Takes either a scalar buffer to hash (not a ref) or an arrayref
of hashes to produce a final hash. Returns the binary sha256 result
as-is (for hex see tree_hash_hex, below).

=item tree_hash_hex

Performs an unpack on the result of tree_hash, either with a buffer
or list of hashes (see tree_hash, above).

=item buffer_hash

Takes a scalar (not a ref) and returns the tree-hash (called by 
tree_hash for non-ref arguments).

=item reduce_hash

Takes a list (not a ref) of sha256 values and returns the tree_hash
(called with an expanded list if tree_hash is called with a ref).

=item

buffer_hash and reduce_hash are available for export largely for
testing. The interface is tree_hash & tree_hash_hex.

=back

=head1 NOTES

=over 4

=item This requires Perl 5.20.

The important difference is handing Copy on Write for scalar assignment.
Without COW the overhead of moving around the large buffers normally 
associated with tree-hashing are prohibitively expensive.

=item Speed

The output of  "prove -v t/10-*" has benchmark output for various 
sizes of buffer being hashed. This can be useful for determining the 
appropriate buffer sizes in different environments.

=back

=head1 SEE ALSO

=over 4

=item Net::AWS::Glacier::API

Which uses tree_hash.

=item Treehash documentation at Amazon

<http://docs.aws.amazon.com/amazonglacier/latest/dev/checksum-calculations.html>

=back

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

=head1 BUGS

=cut

