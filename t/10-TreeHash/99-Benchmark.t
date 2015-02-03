package Net::AWS::Glacier::Test;
use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark           qw( :hireswallclock timeit  timestr );
use Digest::SHA         qw( sha256                  );
use Net::AWS::TreeHash  qw( :buffer_hash );

sub KiB()   { 2 ** 10 };
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

    buffer_hash $a;

    return
};

my $pass4
= sub
{
    state $a    = ' ' x MiB;
    state $i    = -1;

    substr $a, ++$i, 1, $letterz[ $i % @letterz ];

    buffer_hash $a;

    return
};

diag "Substr\t"         => timestr timeit MiB, $pass1;
diag "SHA256\t"         => timestr timeit KiB, $pass2;
diag "BuffHash 1\t"     => timestr timeit KiB, $pass3;
diag "BuffHash 128\t"   => timestr timeit KiB, $pass4;

pass 'Survived testing';
done_testing;
