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

    my $vault   = $proto->new( 'test-glacier-archives' );

    my $vault_data  = $vault->describe( $vault ) 
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
        $vault->initiate_inventory_retrieval( 'JSON' );

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
        $vault->list_jobs
    }
    or do
    {
        fail "list_jobs: '$vault', $@";

        skip 'No job list analyze', 1
    };

    for my $i ( qw( has list ) )
    {
        for my $j ( qw( pending completed ) )
        {
            for my $k ( qw( download inventory ) )
            {
                my $name    = join '_' => $i, $j, $k, 'jobs';

                if( $vault->can( $name ) )
                {
                    pass "$vault can '$name'";

                    eval
                    {
                        $vault->$name;

                        pass "$vault->$name returns";

                        1
                    }
                    or fail "$vault->$name fails ($@)";
                }
                else
                {
                    fail "$vault can '$name'";
                }
            }
        }
    }
};

done_testing;

0
__END__
