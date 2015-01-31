package Net::AWS::Glacier::Test;

use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

sub MiB()   { 2 ** 20 };

use Net::AWS::TreeHash qw( :tree_hash :reduce_hash );

ok __PACKAGE__->can( 'tree_hash' ), 'tree_hash installed';

for my $size ( 1, 4, 32, 128 )
{
    note "Buffer size: $size x MB";

    my $buff1   = 'a' x ( $size * MiB );
    my $buff2   = 'z' x ( $size * MiB );

    my $hash0   = tree_hash( $buff1 );
    my $hash1   = tree_hash( $buff2 );

    my $expect  = reduce_hash $hash0, $hash1;

    my $t_hash  = Net::AWS::TreeHash->new;

    $t_hash->part_hash( $buff1 );
    $t_hash->part_hash( $buff2 );

    my $found   = $t_hash->final_hash;

    ok $t_hash->[0] == $hash0,  'chunk 0 matches';
    ok $t_hash->[1] == $hash1,  'chunk 1 matches';
    ok $found == $expect, 'summary hash matches';
}

done_testing;

# this is not a module
0

__END__
