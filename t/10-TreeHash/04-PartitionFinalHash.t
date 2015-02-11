########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::Test;
use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark           qw( :hireswallclock         );
use Digest::SHA         qw( sha256                  );
use Net::AWS::TreeHash  qw( tree_hash reduce_hash   );

########################################################################
# package variables
########################################################################

sub MiB()   { 2 ** 20 };

my $count
= do
{
    diag 'Test memory footprint with large number of iterations.';

    if( my $env = $ENV{ TREEHASH_TEST_CYCLES } )
    {
        diag "Using cycle count = $env (\$TREEHASH_TEST_CYCLES)";

        $env
    }
    elsif( $ENV{ AWS_GLACIER_FULL } )
    {
        # i.e., roughly 1/2 TB.
        # each 128MiB buffer has 256 sha256 hash values computed.
        # result is ~128K sha256 calc's to process the total input.

        diag "Using large buffer count to test memory footprint.";
        diag "Suggset finding alternate amusements for a while...";

        1024
    }
    else
    {
        note "Using small buffer count to test memory footprint.";
        note "For more effecive, if longer, test set EXPENSEIVE_TESTS";

        32
    }
};

my $size    = 128 * MiB;
my $total   = $size * $count;

note "Buffer:  $size";
note "Cycles:  $count";
note "Input:   $total";

diag 
do
{
    # give the poor slobs who picked EXPENSIVE_TESTS some idea
    # of what they are in for...

    my $t0  = Benchmark->new;
    tree_hash ' ' x $size;
    my $t1  = Benchmark->new;

    my $sec = $count * ( $t1->[0] - $t0->[0] );
    my $est = 1 + int $sec;

    "Est. runtime: $est sec ($total bytes)"
};

########################################################################
# package variables
########################################################################

my @part_hashz
= map
{
    state $letterz  = [ ( 'a' .. 'z' ), ( 'A' .. 'Z' ) ];
    state $buffer   = ' ' x $size;
    state $i        = -1;
    state $a        = '';

    substr $buffer, ++$i, 1, $letterz->[ $i % @$letterz ];

    my $t0      = Benchmark->new;
    my $hash    = tree_hash $buffer;
    my $t1      = Benchmark->new;

    ok sha256( $buffer ) == $hash, "Hash $i";
    note timestr timediff $t1, $t0;

    $hash
}
( 1 .. $count );

my $t0      = Benchmark->new;
my $found   = tree_hash \@part_hashz;
my $t1      = Benchmark->new;

my $expect  = reduce_hash @part_hashz;

ok $found == $expect, 'Matching final hash';
note timestr timediff $t1, $t0;

done_testing;

# this is not a module
0

__END__
