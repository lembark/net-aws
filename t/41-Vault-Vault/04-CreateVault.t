use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use Test::More;

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::Glacier::Vault;

my $name    = "test-glacier-$$";

my $find_vault
= sub
{
    eval
    {
        my @vaultz  = $proto->list_vaults;

        note 'Exisiting vaults:', explain @vaultz;

        first 
        {
            $name eq $_->{ VaultName }
        }
        @vaultz
    }
};

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = $proto->new( $name );

    $vault->create;

    ok $find_vault->(), "$name exists ($vault)";

    eval
    {
        $proto->create( $name );

        fail "Re-created vault '$name'";

        1
    }
    or pass "Failed re-create vault: '$name'";

    eval
    {
        $vault->delete;

        pass "Deleted vault";
        1
    }
    or fail "Delete vault: $@";

    ok ! $find_vault->(), "$name removed";
}

done_testing;

0
__END__
