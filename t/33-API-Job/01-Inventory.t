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

    my $vault   = "test-net-aws-glacier";

    my $vault_data  = $glacier->describe_vault( $vault ) 
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
        $glacier->initiate_inventory_retrieval( $vault, 'JSON' );

    }
    or do
    {
        fail "initiate_inventory_retrieval: $@";

        skip 'No inventory job to analyze', 1
    };

    pass "initiate_inventory_retrieval '$job_id' ($vault)";

    my @found   
    = eval
    {
        $glacier->list_all_jobs( $vault )
    }
    or do
    {
        fail "list_jobs: $@";

        skip 'No job list analyze', 1
    };

    if
    (
        my $job_statz
        = first
        {
            $job_id eq $_->{ JobId }
        }
        @found
    )
    {
        note "Job description: '$job_id' ($vault)\n", $job_statz;
        pass "Inventory job: '$job_id'";
    }
    else
    {
        diag "Job list lacks job: '$job_id'\n", explain \@found;

        fail "list_jobs does not return '$job_id'";

        skip 'Job list lacks test job', 1
    };
};

done_testing;

0
__END__
