package Net::AWS::Glacier::Test;

use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Digest::SHA     qw( sha256          );

sub MiB()   { 2 ** 20 };

my $madness = 'Net::AWS::Glacier::TreeHash';

require_ok $madness ;
$madness->import( ':tree_hash' );

ok __PACKAGE__->can( 'tree_hash' ), "'tree_hash' installed";

for my $size ( 1, 4, 32, 128 )
{
    note "Buffer size: $size x MiB";

    my $buff1   = 'a' x ( $size * MiB );
    my $buff2   = 'z' x ( $size * MiB );

    my $hash0   = tree_hash( $buff1 );
    my $hash1   = tree_hash( $buff2 );
    my $expect  = sha256 $hash0, $hash1;

    my $t_hash  = $madness->new;

    isa_ok $t_hash, $madness;

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
