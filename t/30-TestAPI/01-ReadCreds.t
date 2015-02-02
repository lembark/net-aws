use v5.20;
use autodie;
use FindBin::libs   qw( base=etc export scalar );

use Test::More;

my $path    = "$etc/test.conf";

-e $path    or BAIL_OUT "Non-existant: '$path'";
-r _        or BAIL_OUT "Non-readable: '$path'";
-s _        or BAIL_OUT "Zero-size:    '$path'";

my ( $region, $user, $secret )
= do
{
    open my $fh, '<', $path;
    chomp( my @linz = <$fh> );

    @linz
};

$region     or BAIL_OUT "$path missing region";     
$user       or BAIL_OUT "$path missing user";     
$secret     or BAIL_OUT "$path missing secret";     

index $user,    'AWSAccessKeyId='
and BAIL_OUT "user lacks 'AWSAccessKeyId='";

index $secret,  'AWSSecretKey='
and BAIL_OUT "secret lacks 'AWSAccessKeyId='";

pass "Config file: $path";

done_testing;
