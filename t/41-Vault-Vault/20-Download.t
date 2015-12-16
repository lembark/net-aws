use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first       );
use JSON::XS        qw( decode_json );
use Scalar::Util    qw( reftype     );

use Test::More;
#use Test::Glacier::API;

use Test::Glacier::Vault;

my $sanity_check
= sub
{
    my $vault   = shift;

    my @jobz    = $vault->list_all_jobs;

    @jobz
    or do
    {
        note "No pending jobs ($vault)\n", explain \@jobz;
        return
    };

    @jobz  
    = grep 
    {
        'InventoryRetrieval' eq $_->{ Action }
    }
    @jobz
    or do
    {
        note "No inventory jobs\n", explain \@jobz;
        return
    };

    @jobz
    = grep
    {
        !! $_->{ Completed }
    }
    @jobz
    or note "No completed jobs\n", explain \@jobz;

    \@jobz
};

my $completed_inventory_jobs
= sub
{
    my $vault   = shift;

    my @jobz    = $vault->list_all_jobs;

    @jobz
    or do
    {
        note "No pending jobs ($vault)\n", explain \@jobz;
        return
    };

    @jobz  
    = grep 
    {
        'InventoryRetrieval' eq $_->{ Action }
    }
    @jobz
    or do
    {
        note "No inventory jobs\n", explain \@jobz;
        return
    };

    @jobz
    = grep
    {
        !! $_->{ Completed }
    }
    @jobz
    or note "No completed jobs\n", explain \@jobz;

    \@jobz
};

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

$DB::single = 1;

    my $vault_data  = $vault->describe
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

    if( my $date = $vault_data->{ LastInventoryDate }  )
    {
        pass "$vault has 'LastInventoryDate'($date)";
        note 'Vault data:', explain $vault_data;
    }
    else
    {
        diag "Vault '$vault' lacks inventory\n",
        explain $vault_data;

        skip "Vault $vault has no inventory available", 1
    };

    my $jobz
    = first
    {
        $_  = $vault->$completed_inventory_jobs
        or skip "No pending inventory jobs to wait for ($vault)", 1;

        @$_
        ? $_ 
        : do
        {
            say 'Waiting for jobs to complete...'; sleep 1800; '' 
        }
    }
    ( 1 .. 10 )
    or skip "Inventory jobs not completing ($vault)", 1;

    for( @$jobz )
    {
        my $job_id  = $_->{ JobId };

        my $output  
        = eval 
        {
            my $json = $vault->get_job_output( $vault, $job_id );
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
