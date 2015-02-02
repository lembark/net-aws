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

my $expensive   = $ENV{ EXPENSIVE_TESTS };

my $count
= do
{
    if( $expensive )
    {
        # i.e., roughly 1/2 TB.
        # each 128MiB buffer has 256 sha256 hash values computed.
        # result is ~128K sha256 calc's to process the total input.

        diag "Using large buffer count to test memory footprint.";
        diag "Suggset finding alternate amusements for a while...";

        4096
    }
    else
    {
        diag "Using small buffer count to test memory footprint.";
        diag "For more effecive, if longer, test set EXPENSEIVE_TESTS";
        diag "Expected runtime: ~20 minutes";

        32
    }
};

my $size    = 128 * MiB;
my $total   = $size * $count;
my $time    = 30 + $count;

########################################################################
# package variables
########################################################################

note "This is basically a test for memory leaks processing large files";

note "Buffer:  $size";
note "Cycles:  $count";
note "Input:   $total";
diag "Runtime: $time sec";

my @letterz = ( 'a' .. 'z' ), ( 'A' .. 'Z' );
my $buffer  = "\c@" x $size;

for my $length ( length $buffer )
{
    $size == $length
    or BAIL_OUT "Mismatched buffer size: $length ($size)";
}

my $t_hash  = Net::AWS::TreeHash->new;

for my $i ( 1 .. $count )
{
    my $t0  = Benchmark->new;

    my $j   = $t_hash->part_hash( $buffer );

    my $t1  = Benchmark->new;
    my $dt  = timediff $t1, $t0;
    my $str = timestr $dt;

    note "Pass: $i ($str)";

    my $expect  = tree_hash $buffer;
    my $found   = $t_hash->[-1];

    $i == $j
    or do
    {
        fail "Miscount: $i != $j";
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
    state $sanity   = '';

    $sanity = $buffer;

    my $i   = int rand $size;
    my $a   = $letterz[ rand @letterz ];

    substr $buffer, $i, 1, $a;

    $sanity ne $buffer
    or BAIL_OUT "Failed buffer update: '$a' at $i leaves buffer unchanged";
}

my $hashes  = @$t_hash;
ok $hashes == $count, "Hash count: $hashes ($count)";

$t_hash->final_hash
and pass 'Final hash produced';

done_testing;

# this is not a module
0

__END__
