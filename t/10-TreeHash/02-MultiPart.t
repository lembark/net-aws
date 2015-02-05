package Net::AWS::Glacier::Test;

use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

sub MiB()   { 2 ** 20 };

use Net::AWS::TreeHash qw( tree_hash reduce_hash );

__PACKAGE__->can( $_ ) or BAIL_OUT "Failed import: '$_'"
for qw( tree_hash reduce_hash );

for( 1, 4, 32, 128 )
{
    my $size    = $_ * MiB;

    my $buff0   = 'a' x $size;
    my $buff1   = 'z' x $size;

    my $hash0   = tree_hash $buff0;
    my $hash1   = tree_hash $buff1;

    my $found   = tree_hash [ $hash0, $hash1 ];
    my $expect  = reduce_hash $hash0, $hash1;

    ok $found == $expect, "Hash & finalize $size byte buffer";
}

done_testing;
