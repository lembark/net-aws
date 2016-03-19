########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::TreeHash;
use v5.20;
use autodie;
use experimental qw( lexical_subs autoderef );

use Carp            qw( croak           );
use Digest::SHA     qw( sha256          );
use List::Util      qw( min             );
use Scalar::Util    qw( reftype         );
use Symbol          qw( qualify_to_ref  );

use Net::AWS::Util::Const qw( const           );

use Keyword::Declare;

keyword fold ( Ident $name, Block $new_list )
{
    my $code
    = qq
    {
        sub $name
        {
            ( \@_  = do $new_list ) > 1
            and goto __SUB__;

            shift
        }
    };

    $code
}

########################################################################
# package variables
########################################################################

our $VERSION = '0.80';
$VERSION = eval $VERSION;

########################################################################
# utility subs
########################################################################

fold reduce_hash
{
    const my $last = int( @_ / 2 + @_ % 2 - 1 );

    map
    {
        const sha256 @_[ $_, $_ + 1 ]
    }
    map
    {
        const ( 2 * $_ )
    }
    ( 0 .. $last )
}

const my $reduce_hash 
= sub
{
    const my $last = int( @_ / 2 + @_ % 2 - 1 );

    @_
    = map
    {
        sha256 @_[ $_, $_ + 1 ]
    }
    map
    {
        2 * $_
    }
    ( 0 .. $last );

    $last
    and goto __SUB__;

    $_[0]
};

const my $buffer_hash =>
sub
{
    state $format   = '(a' . 2**20 . ')*';
    const my $buffer => shift;

    length $buffer
    ? $reduce_hash->( unpack $format, $buffer )
    : ()
};

sub import
{
    const state $exportz =>
    {
        tree_hash       => \&tree_hash,
        tree_hash_hex   => \&tree_hash_hex,
        reduce_hash     => $reduce_hash,
        buffer_hash     => $buffer_hash,
    };

    shift;

    const my $caller    => caller;

    for( @_ )
    {
        const my $ref   => $exportz->{ $_ };

        *{ qualify_to_ref $_, $caller  } = $ref;
    }

    return
}

########################################################################
# methods
########################################################################

sub tree_hash
{
    @_ > 1
    and croak 'Bogus tree_hash: multiple arguments';

    const my $type  => reftype $_[0];
    
    # caller gets back buffer_hash, reduce_hash, or death.

    if( '' eq $type  )
    {
        &$buffer_hash
    }
    elsif( 'ARRAY' eq $type )
    {
        $reduce_hash->( values $_[0] )
    }
    else
    {
        croak "Bogus tree_hash: '$_' neither arrayref nor string"
    }
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

    use Net::Amazon::Glacier::TreeHash qw( tree_hash );

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

Normal use will require tree_hash and possibly tree_hash_hex.
Importing buffer_hash or reduce_hash is mainly for testing the
interface.

=over 4

=item tree_hash

Takes either a scalar buffer to hash (not a ref) or an arrayref
of hashes to produce a final hash. Returns the binary sha256 result
as-is (for hex see tree_hash_hex, below).

This will croak if its first argument is neither an arrayref nor
a non-ref scalar.

=item tree_hash_hex

Performs an unpack on the result of tree_hash, either with a buffer
or list of hashes (see tree_hash, above).

=item buffer_hash

Takes a scalar (not a ref) and returns the tree-hash (called by 
tree_hash for non-ref arguments).

=item reduce_hash

Takes an arrayref of sha256 values and returns their tree_hash value.

=back

=head1 NOTES

=over 4

=item Managing local buffer sizes

The output of  "prove -v t/10-*" has benchmark output for various 
sizes of buffer being hashed. This can be useful for determining the 
appropriate buffer sizes in different environments.

Running:

    EXPENSIVE_TESTS=1 prove -v t/10-*;

will include some -- probably excessively large -- buffers that
can be used to determine likely swapping limits. Without the 
EXPENSIVE_TESTS set they run shorter validation tests. Turning
on "verbose" with prove displays timing information for each
buffer size and for successive buffers.

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

=over 4

=item

None, so far.

=back
