package Net::AWS::Glacier::Test;

use v5.20;
use autodie;
use FindBin::libs;

use Test::More;

use Digest::SHA     qw( sha256          );

sub MiB()   { 2 ** 20 };

my $madness = '';

use Net::AWS::TreeHash qw( tree_hash );

ok __PACKAGE__->can( 'tree_hash' ), "'tree_hash' installed";

for my $length ( 1, 1024, 4096, MiB, 32 * MiB, 128 * MiB )
{
    my $buffer  = ' ' x $length;
    my $expect  = sha256 $buffer;
    my $found   = tree_hash $buffer;

    ok $found == $expect, "Hashed $length buffer";
}

done_testing;
