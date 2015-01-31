package Net::AWS::Glacier::Test;

use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark   qw( :hireswallclock );

sub MiB()   { 2 ** 20 };

use Net::AWS::TreeHash qw( :tree_hash :reduce_hash );

my @letterz = ( 'a' .. 'z' ), ( 'A' .. 'Z' );
my @buffsiz = ( 1, 2, 4, 8, 32, 64, 128, 256, 512, 1024 );

plan tests => @buffsiz * 3;

for my $size ( @buffsiz )
{
    note "Buffer size: $size x MiB";

    my $a   = $letterz[ rand @letterz ];
    my $b   = $letterz[ rand @letterz ];

    my $buff1   = $a x ( $size * MiB );
    my $buff2   = $b x ( $size * MiB );

    my @pass1   = ( Benchmark->new );

    my $hash0   = tree_hash( $buff1 );
    my $hash1   = tree_hash( $buff2 );

    push @pass1, Benchmark->new;

    my $expect  = reduce_hash $hash0, $hash1;

    push @pass1, Benchmark->new;

    my $t_hash  = Net::AWS::TreeHash ->new;

    my @pass2   = ( Benchmark->new );

    $t_hash->part_hash( $buff1 );
    $t_hash->part_hash( $buff2 );

    push @pass2, Benchmark->new;

    my $found   = $t_hash->final_hash;

    push @pass2, Benchmark->new;

    ok $t_hash->[0] == $hash0,  'chunk 0 matches';
    ok $t_hash->[1] == $hash1,  'chunk 1 matches';
    ok $found == $expect, 'summary hash matches';

    for( \@pass1, \@pass2 )
    {
        my $t0  = shift @$_;

        for( @$_ )
        {
            $a  = timestr timediff $_, $t0;
            $t0 = $_;
            $_  = $a;
        }
    }

    $,  = "\n\t";

    say 'Treehash calls:', @pass1;
    say 'Object calls:  ', @pass2;
}

done_testing;

# this is not a module
0

__END__
