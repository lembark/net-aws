use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::Glacier::Vault;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my @found 
    = eval
    {
        map 
        {
            $_->{ VaultName } =~ m{^ (test-glacier-\d+) $}x
        }
        $proto->list_vaults
    };

    @_  and BAIL_OUT "Failed list_vaults: $@";

    @found 
    or skip "No cleanup required", 1;

    for( @found )
    {
        note "Remove test vault: '$_'";

        $proto->new( $_ )->delete;
    }
}

done_testing;

0
__END__
