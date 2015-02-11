use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first       );
use JSON::XS        qw( decode_json );
use Scalar::Util    qw( reftype     );

use Test::More;
use Test::GlacierAPI;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = "test-glacier-archives";

    my $vault_data  = $::glacier->describe_vault( $vault ) 
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

    note 'Vault data:', explain $vault_data;

    if( my $date = $vault_data->{ LastInventoryDate }  )
    {
        pass "LastInventoryDate: '$date'";
    }
    else
    {
        diag "Vault '$vault' lacks inventory\n",
        explain $vault_data;

        skip "Vault $vault has no inventory available", 1
    };

    my $jobz
    = eval
    {
        my @jobz    = $::glacier->list_jobs( $vault )
        or skip "No pending jobs", 1;

        note "Job listing:\n", explain \@jobz;

        @jobz       = grep { !! $_->{ Completed } } @jobz
        or skip "No completed jobs", 1;

        my @jobz  
        = grep 
        {
            'InventoryRetrieval' eq $_->{ Action }
        }
        @jobz
        or skip "No inventory jobs", 1;

        \@jobz
    }
    or do
    {
        fail "list_jobs: $@";
        skip "Failed list_jobs available ($@)", 1
    };

    for( @$jobz )
    {
        my $job_id  = $_->{ JobId };

        my $output  
        = eval 
        {
            my $json = $::glacier->get_job_output( $vault, $job_id );
            pass 'Job has output';

            my $struct  = decode_json $json;
            pass 'JSON decodes';

            $struct->{ $_ } and pass "Struct has $_"
            for qw( VaultARN InventoryDate ArchiveList );

            my $type    = reftype $struct->{ ArchiveList };

            ok 'ARRAY' eq $type , "ArchiveList is '$type' (ARRAY)";

            1
        }
        or do
        {
            fail "No job output: $@";

            next
        };

    }
}

done_testing;

0
__END__
