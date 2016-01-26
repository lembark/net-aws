use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use Test::More;

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::Glacier::API;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = "test-glacier-$$";

    for
    (
        [ create_vault  => 1 ],
        [ delete_vault  => 0 ],
    )
    {
        my ( $method, $exist ) = @$_;

        eval
        {
            $glacier->$method( $vault );

            pass "$method( $vault )";
            1
        }
        or BAIL_OUT "$method( $vault ), $@";

        eval
        {
            my @vaultz  = $glacier->list_vaults;

            note 'Exisiting vaults:', explain @vaultz;

            my $found   
            = first 
            {
                $vault eq $_->{ VaultName }
            }
            @vaultz;

            $exist
            ? ok $found,  "Found vault named '$vault ($method)"
            : ok ! $found,"No vault named '$vault' ($method)"
            ; 

            1
        }
        or BAIL_OUT "Failed list_vaults: $@";
    }
}

done_testing;

0
__END__
