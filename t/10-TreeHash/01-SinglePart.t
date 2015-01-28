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

for my $length ( 1, 1024, 4096, MiB )
{
    my $buffer  = ' ' x $length;
    my $expect  = sha256 $buffer;
    my $found   = tree_hash( $buffer );

    ok $found == $expect, "Hashed one $length x spaces";
}

my $chunk1  = 'a' x MiB;
my $chunk2  = 'b' x MiB;

my $hash1   = sha256 $chunk1;
my $hash2   = sha256 $chunk2;

my $expect  = sha256 $hash1, $hash2;
my $found   = tree_hash( $chunk1 . $chunk2 );
 
ok $found == $expect, "Hashed mixed buffer";

done_testing;
