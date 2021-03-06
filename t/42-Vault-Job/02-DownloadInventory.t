use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first       );
use JSON::XS        qw( decode_json );
use Scalar::Util    qw( reftype     );

use Test::More;
use Test::Glacier::Vault;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = $proto->new( 'test-net-aws-glacier' );

    my $vault_data  = $vault->describe
    or BAIL_OUT "Vault '$vault' does not exist, run prior tests";

    note 'Vault data:', explain $vault_data;

    $vault_data->{ LastInventoryDate } 
    or do
    {
        diag "Vault '$vault' lacks inventory\n",
        explain $vault_data;

        skip "Vault $vault has no inventory available", 1
    };

    my @jobz
    = eval
    {
        grep
        {
            'InventoryRetrieval' eq $_->{ Action }
        }
        $vault->list_all_jobs
    }
    or do
    {
        fail "list_jobs: $@";

        skip "No jobs found ($@)", 1
    };

    note "Inventory jobs:\n", explain \@jobz;

    my @compz
    = grep
    {
        $_->{ Completed }
    }
    @jobz
    or do
    {
        skip "No completed jobs to download ($@)", 1
    };

    for( @compz )
    {
        my $job_id  = $_->{ JobId };

        my $output  
        = eval 
        {
            note "Retrieve: '$job_id'";

            my $json = $vault->get_job_output( $job_id );
            pass 'Job has output';

            my $struct  = decode_json $json;
            pass 'JSON decodes';

            $struct->{ $_ } and pass "Struct has $_"
            for qw( VaultARN InventoryDate ArchiveList );

            my $arch    = $struct->{ ArchiveList };
            note "Archives:\n", explain $arch;

            my $type    = reftype $arch;

            ok 'ARRAY' eq $type , "ArchiveList is '$type' (ARRAY)";
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
