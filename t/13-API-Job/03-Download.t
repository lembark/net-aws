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
    $ENV{ TEST_GLACIER_ARCHIVE }
    or skip "TEST_GLACIER_ARCHIVE not set", 1;

    my $vault   = "test-glacier-archives";

    my $vault_data  = $::glacier->describe_vault( $vault ) 
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

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
            $_->{ Action } eq 'InventoryRetrieval'
        }
        $::glacier->list_jobs( $vault )
    }
    or do
    {
        fail "list_jobs: $@";

        skip "No jobs found ($@)", 1
    };

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
            my $json = $::glacier->get_job_output( $vault, $job_id );
            pass 'Job has output';

            my $struct  = decode_json $json;
            pass 'JSON decodes';

            $struct->{ $_ } and pass "Struct has $_"
            for qw( VaultARN InventoryDate ArchiveList );

            my $type    = reftype $struct->{ ArchiveList };

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
