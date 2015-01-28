use v5.20;
use autodie;
use FindBin::libs   qw( base=etc export scalar );

use Test::More;

my ( $region, $user, $secret )
= do
{
    open my $fh, '<', "$etc/aws-config";
    chomp( my @linz = <$fh> );

    @linz
};

ok $region, "Read region";
ok $user,   "Read user";
ok $secret, "Read secret";

done_testing;
