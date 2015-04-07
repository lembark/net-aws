use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::GlacierAPI;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault
    = eval
    {
        my $name    = "test-glacier-$$";

        $glacier->create_vault( $name )
        or BAIL_OUT "Failed create vault: '$name' ($@_)";

        $name
    }
    or BAIL_OUT "Error installing test vault: $@";

    my $desc
    = eval
    {
        $glacier->describe_vault( $vault )
    }
    or do
    {
        fail "Failed describe_vault: '$vault' ($@)";
    };

    note 'Vault description:', explain $desc;

    my $job_id
    = eval
    {
        # this will fail due to the lack of an existing inventory
        # for the vault.

        $glacier->initiate_inventory_retrieval( $vault, 'JSON' )
    };

$DB::single = 1;

    note 'Error:', $@;

    if( $@ )
    {
        ok 0 < index( $@, 'not yet generated an initial inventory' ),
        'No initial inventory avaiable';
    }
    else
    {
        ok $job_id, "Generated job_id: '$job_id' for inventory";
    }

    eval
    {
        $glacier->delete_vault( $vault )
        and
        pass "Vault deleted: '$vault'"
    }
    or diag "Failed delete vault: '$vault' ($@)";

};

done_testing;

0
__END__
