use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::Glacier::API;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault
    = eval
    {
        my $name    = "test-glacier-archives";

        my $found   
        = first 
        {
            $_->{ VaultName } eq $name
        }
        $glacier->list_vaults
        or
        $glacier->create_vault( $name )
        or
        BAIL_OUT "Failed create vault: '$name' ($@_)";

        $name
    }
    or BAIL_OUT "Error installing test vault: $@";

    if( my $vault_data  = $glacier->describe_vault( $vault ) )
    {
        my $date = $vault_data->{ LastInventoryDate } 
        or do
        {
            diag "Vault '$vault' lacks inventory\n",
            explain $vault_data;

            skip "Vault $vault has no inventory available", 1
        };

        diag "Vault inventory on '$date'";

        my $job_id
        = eval
        {
            $glacier->initiate_inventory_retrieval( $vault, 'JSON' );
        };

        my $error   = $@;

        note "Error:", $error   if $error;

        ok $job_id, "Inventory retrieval returns job id.";
        note "JobID:", $job_id;
    }
    else
    {
        BAIL_OUT "Vault '$vault' does not exist, unable to create";
    }
};

done_testing;

0
__END__
