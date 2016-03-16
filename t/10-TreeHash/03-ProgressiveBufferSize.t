package Net::AWS::Glacier::Test;

use v5.22;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark   qw( :hireswallclock );
use Digest::SHA qw( sha256          );

sub MiB()   { 2 ** 20 };

use Net::AWS::Glacier::TreeHash qw( tree_hash reduce_hash );

my @letterz = ( 'a' .. 'z' );
my @buffsiz = map { 2 ** $_ } ( 0 .. 10 );

my $format  = '(a' . 2**20 . ')*';

sub imperative
{
    $_[0] // return;

    my $count   = @_ / 2 + @_ % 2;

    @_
    = map
    {
        sha256 splice @_, 0, 2
    }
    ( 1 .. $count )
    ;

    @_ > 1
    and goto __SUB__;

    $_[0]
}

for my $size ( @buffsiz )
{
    my @argz
    = do
    {
        my $a       = $letterz[ rand @letterz ];

        unpack $format => $a x ( $size * MiB );
    };

    my ( $expect, $pass1 )
    = do
    {
        my $t0      = Benchmark->new; 
        my $hash    = imperative @argz;
        my $t1      = Benchmark->new;

        ( $hash, timestr timediff $t1, $t0 )
    };

    my ( $found, $pass2 )
    = do
    {
        my $t0      = Benchmark->new;
        my $hash    = reduce_hash @argz;
        my $t1      = Benchmark->new;

        ( $hash, timestr timediff $t1, $t0 )
    };

    ok $found == $expect,   "imperative == FP-ish   ($size MiB)";

    note 'imperative:', $pass1;
    note 'pseudo-fp: ', $pass2;
}

done_testing;

# this is not a module
0

__END__
