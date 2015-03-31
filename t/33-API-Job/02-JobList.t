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

    my $vault   = "test-glacier-archives";

    my $vault_data  = $api->describe_vault( $vault ) 
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

    $vault_data->{ LastInventoryDate } 
    or do
    {
        diag "Vault '$vault' lacks inventory\n",
        explain $vault_data;

        skip "Vault $vault has no inventory available", 1
    };

    my $job_id
    = eval
    {
        $api->initiate_inventory_retrieval( $vault, 'JSON' );

        pass 'initiate_inventory_retrieval';

        1
    }
    or do
    {
        fail "initiate_inventory_retrieval: $@";

        skip 'No inventory job to analyze', 1
    };

    my @found   
    = eval
    {
        $api->list_jobs( $vault )
    }
    or do
    {
        fail "list_jobs: $@";

        skip 'No job list analyze', 1
    };


};

done_testing;

0
__END__
