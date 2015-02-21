package Net::AWS::Glacier::Test;

use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark   qw( :hireswallclock );
use Digest::SHA qw( sha256          );

sub MiB()   { 2 ** 20 };

use Net::AWS::TreeHash qw( tree_hash reduce_hash );

my @letterz = ( 'a' .. 'z' ), ( 'A' .. 'Z' );
my @buffsiz = map { 2 ** $_ } ( 0 .. 8 );
my $last    = $buffsiz[-1];

if( $ENV{ AWS_GLACIER_FULL } )
{
    state $big  = [ map { $last * 2 ** $_ } ( 1 .. 4 ) ];
    diag "Adding $big->[0] .. $big->[-1] (AWS_GLACIER_FULL set)";
    push @buffsiz, @$big;
}
else
{
    note "Skip tests beyond $buffsiz[-1] (AWS_GLACIER_FULL not set)";
}

for my $size ( @buffsiz )
{
    my $a       = $letterz[ rand @letterz ];
    my $buffer  = $a x ( $size * MiB );

    my $t0      = Benchmark->new;
    my $found   = tree_hash $buffer;
    my $t1      = Benchmark->new;

    my @hashz
    = map
    {
        sha256 substr $buffer, 0, MiB, '' 
    }
    ( 1 .. $size );

    my $expect  = reduce_hash @hashz;

    ok $found == $expect, "Hash $size MiB";

    note 'tree_hash: ', timestr timediff $t1, $t0;
}

done_testing;

# this is not a module
0

__END__
