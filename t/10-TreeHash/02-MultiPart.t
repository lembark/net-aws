package Net::AWS::Glacier::Test;

use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

sub MiB()   { 2 ** 20 };

use Net::AWS::TreeHash qw( tree_hash reduce_hash );

ok __PACKAGE__->can( 'tree_hash' ), 'tree_hash installed';
ok __PACKAGE__->can( 'reduce_hash' ), 'reduce_hash installed';

for my $size ( 1, 4, 32, 128 )
{
    note "Buffer size: $size x MB";

    my $buff0   = 'a' x ( $size * MiB );
    my $buff1   = 'z' x ( $size * MiB );

    my $hash0   = tree_hash $buff0;
    my $hash1   = tree_hash $buff1;

    my $found   = tree_hash [ $hash0, $hash1 ];
    my $expect  = reduce_hash $hash0, $hash1;

    ok $found == $expect, 'summary hash matches';
}

done_testing;

# this is not a module
0

__END__
