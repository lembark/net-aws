########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::Test;
use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark           qw( :hireswallclock );
use Net::AWS::TreeHash  qw( :tree_hash      );

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
    elsif( $ENV{ EXPENSIVE_TESTS } )
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
        diag "Using small buffer count to test memory footprint.";
        diag "For more effecive, if longer, test set EXPENSEIVE_TESTS";

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

    my $sec = 2 * $count * ( $t1->[0] - $t0->[0] );
    my $est = 1 + int $sec;

    "Est. runtime: $est sec ($total bytes)"
};

########################################################################
# package variables
########################################################################

my @letterz = ( 'a' .. 'z' ), ( 'A' .. 'Z' );
my $buffer  = ' ' x $size; # "\c@" x $size;

for my $length ( length $buffer )
{
    $size == $length
    or BAIL_OUT "Mismatched buffer size: $length ($size)";
}

my $t_hash  = Net::AWS::TreeHash->new;

for my $i ( 1 .. $count )
{
    my $t0  = Benchmark->new;

    my $th  = $t_hash->part_hash( $buffer );

    my $t1  = Benchmark->new;
    my $dt  = timediff $t1, $t0;
    my $str = timestr $dt;

    note "Pass: $i ($str)";
    my $expect  = tree_hash $buffer;
    my $found   = $t_hash->[-1];

    $th eq $expect
    or do
    {
        fail "Invalid return: pass $i last t_hash != hash returned";
        last
    };

    $expect == $found
    or do
    {
        fail "Botched tree_hash at $i: $found ($expect)";
        last
    };

    $t_hash->[-2]
    ? $t_hash->[-2] ne $t_hash->[-1]
    : 1
    or do
    {
        local $" = ' ';

        fail "Botched tree_hash: identical successive hashes (@{$t_hash}[-1,-2])";
        last
    };
}
continue
{
    state $i        = -1;

    my $a   = $letterz[ ++$i % @letterz ];

    substr $buffer, $i, 1, $a;
}

my $hashes  = @$t_hash;
ok $hashes == $count, "Hash count: $hashes ($count)";

$t_hash->final_hash
and pass 'Final hash produced';

done_testing;

# this is not a module
0

__END__
