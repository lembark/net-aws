package Net::AWS::Glacier::Test;
use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark   qw( :hireswallclock );

SKIP:
{
    $ENV{ EXPENSIVE_TESTS }
    or skip 'Skip expensive test ($EXPENSIVE_TESTS false)', 1;

    sub MiB()   { 2 ** 20 };

    use Net::AWS::TreeHash qw( :tree_hash :reduce_hash );

    my $size    = 128 * MiB;
    my $count   = 1024;
    my $total   = $size * $count;

    # i.e., 137_438_953_472 == 128GiB total.
    # each 128MiB buffer has 256 sha256 hash values computed.
    # result is 262_144 sha256 calc's to process the total input.

    note
    "This is basically a test for memory leaks processing large files";

    note "Buffer: $size";
    note "Count:  $count";
    note "Total:  $total";

    my @letterz = ( 'a' .. 'z' ), ( 'A' .. 'Z' );
    my $buffer  = ' ' x $size;

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
            my $e   = sprintf '%X', $expect;
            my $f   = sprintf '%X', $found;

            fail "Botched tree_hash: $i ($f != $e)";
            last
        };
    }
    continue
    {
        my $i   = int rand $size;
        substr $buffer, $i, 1, $letterz[ rand @letterz ];
    }

    my $hashes  = @$t_hash;
    ok $hashes == $count, "Hash count: $hashes ($count)";

    $t_hash->final_hash
    and pass 'Final hash produced';
}

done_testing;

# this is not a module
0

__END__
