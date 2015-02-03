package Net::AWS::Glacier::Test;

use v5.20;
use autodie;

use Test::More;

use Benchmark           qw( timethese       );
use Digest::SHA         qw( sha256          );
use Net::AWS::Treehash  qw( :tree_hash );

sub MiB()   { 2 ** 20 };

my @letterz = ( 'a' .. 'z' );

my $pass1
= sub
{
    state $a    = ' ' x MiB;
    state $i    = -1;

    substr $a, ++$i, 1, $letterz[ $i % @letterz ];

    return
};

my $pass2
= sub
{
    state $a    = ' ' x MiB;
    state $i    = -1;

    substr $a, ++$i, 1, $letterz[ $i % @letterz ];

    sha256 $a;

    return
};

my $pass3
= sub
{
    state $a    = ' ' x MiB;
    state $i    = -1;

    substr $a, ++$i, 1, $letterz[ $i % @letterz ];

    tree_hash $a;

    return
};

diag timethese MiB =>
{
    Substr      => $pass1,
    SHA256      => $pass2,
    TreeHash    => $pass3,
};

pass "Survived the benchmark on 1MiB buffer";

done_testing;
