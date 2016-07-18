use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use Test::More;

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::Glacier::API;

my $vault   = "test-net-aws-glacier";
my $find
= sub
{
    my $name    = shift;

    first 
    {
        $name eq $_->{ VaultName }
    }
    $glacier->list_vaults

};

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my @vaultz  = 
    eval 
    {
        $find->( $vault )
        or 
        $glacier->create_vault( $vault );
    }
    or BAIL_OUT "Failed making $vault: $@";

    my $statz   = $find->( $vault )
    or BAIL_OUT "Failed listing '$vault'";

    note "Test vault data:\n", explain $statz;

    pass "Test vault exists: '$vault'";
}

done_testing;

0
__END__
