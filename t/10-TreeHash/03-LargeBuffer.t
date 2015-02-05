package Net::AWS::Glacier::Test;

use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark   qw( :hireswallclock );

sub MiB()   { 2 ** 20 };

use Net::AWS::TreeHash qw( tree_hash reduce_hash );

my @letterz = ( 'a' .. 'z' ), ( 'A' .. 'Z' );
my @buffsiz = ( 1, 2, 4, 8, 32, 64, 128 );
my $last    = $buffsiz[-1];

if( $ENV{ EXPENSIVE_TESTS } )
{
    state $big  = [ map { $last * 2 ** $_ } ( 1 .. 3 ) ];
    diag "Adding $big->[0] .. $big->[-1] (EXPENSIVE_TESTS set)";
    push @buffsiz, @$big;
}
else
{
    diag "Skip tests beyond $buffsiz[-1] (EXPENSIVE_TESTS not set)";
}

for my $size ( @buffsiz )
{
    my $a   = $letterz[ rand @letterz ];
    my $b   = $letterz[ rand @letterz ];

    my $buff1   = $a x ( $size * MiB );
    my $buff2   = $b x ( $size * MiB );

    my $t0      = Benchmark->new;

    my $hash0   = tree_hash( $buff1 );
    my $hash1   = tree_hash( $buff2 );

    my $t1      = Benchmark->new;

    my $found   = tree_hash [ $hash0, $hash1 ];
    my $expect  = reduce_hash $hash0, $hash1;

    ok $found == $expect, "Hash $size MiB";

    note timestr timediff $t1, $t0;
}

done_testing;

# this is not a module
0

__END__
