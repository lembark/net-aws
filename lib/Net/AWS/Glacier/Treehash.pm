########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::Treehash;
use v5.12;
use autodie;

use Scalar::Util    qw( blessed );
use Digest::SHA     qw( sha256  );

########################################################################
# package variables
########################################################################

our $VERSION = '0.71';
$VERSION = eval $VERSION;

my $empty   = sha256 '';

########################################################################
# utility subs
########################################################################

sub MiB() { 2 ** 20 };

# iterate reducing the pairs of 1MiB data units into a single value.
# "2 > @_" intentionally returns undef for an empty list.

my $reduce_hash
= do
{
    my $handler = '';

    $handler
    = sub
    {
        return $_[0]
        if 2 > @_;

        # note that splice returns a single-entry list for the
        # last iteration of an odd list.

        my $count   = @_ / 2 + @_ % 2;

        @_
        = map
        {
            sha256 splice @_, 0, 2
        }
        ( 1 .. $count )

        goto &$handler
    }
};

my $buffer_hash
= sub
{
    my $buffer  = shift;
    my $size    = length $buffer
    or return @_;

    my $count   = $size / MiB;
    ++$count if $size % MiB;

    $reduce_hash->
    (
        map
        {
            sha256 substr $buffer, 0, MiB, ''
        }
        ( 1 .. $count )
    )
};

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

sub single_hash
{
    my ( undef, $buffer ) = @_;

    $buffer_hash->( $buffer )
}

sub part_hash
{
    my ( $t_hash, $buffer ) = @_;

    push @$t_hash, $buffer_hash->( $buffer );
}

sub final_hash
{
    my $t_hash  = shift;

    @$t_hash    or croak 'Bogus final_hash: no part hashes available';

    $reduce_hash->( @$buffer )
}

# keep require happy
1

__END__

=head1 SYNOPSIS

This module implements TreeHash algorithm for Amazon AWS 
Glacier API (version 2012-06-01)

Usage:

	use Net::Amazon::TreeHash;

	my $th = Net::Amazon::TreeHash->new();

    # simplest cases: compute the hash of a single buffer or an 
    # non-partitioned input.

    my $t_hash  = $t_hash->single_hash( $buffer );

    # for multi-part uploads accumulate the partition hashses and
    # get a final one at the end.

    my $t_hash  = $t_hash->part_hash( $buffer );

    for(;;)
    {
        my $part    = get_some_data;

        my $hash    = $t_hash->part_hash( $part );

        send_partition
    }

    my $total_hash  = $t_hash->final_hash;


=head1 SEE ALSO

=head1 AUTHOR

Steven Lembark

=head1 BUGS

=cut

