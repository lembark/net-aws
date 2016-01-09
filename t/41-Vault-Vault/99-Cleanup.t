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

    my @found = eval { $proto->list_vaults }
    or skip "Failed list_vaults: $@", 1;

    for( map { $_->{ VaultName } } @found )
    {
        state $test_rx = qr{^ test- .+ -\d+ $}x;

        /$test_rx/o
        or next;

        note "Remove test vault: '$_'";

        $proto->delete_vault( $_ );
    }
}

done_testing;

0
__END__
