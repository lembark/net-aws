use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use JSON::XS        qw( decode_json );
use List::Util      qw( first       );
use Scalar::Util    qw( reftype     );

use Test::More;
use Test::GlacierUtil;

my $vault   = "test-glacier-archives";
my $tmpdir  = './tmp';
my $base    = 'inventory.json';
my $path    = "$tmpdir/$base";

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    for( $path )
    {
        -e      
        or skip "No inventory: run 02-RetrieveInventory.t";

        -s _    
        or skip "Empty inventory: run 02-RetrieveInventory.t";
    }

    my $

    my $output  = $glacier->get_job_output( $vault => $job_id )
    or do
    {
        fail "Failed download $job_id output";
        skip "No inventory for download", 1
    };

    eval { decode_json $output }
    or do
    {
        fail "Decode inventory: $@";
        skip "Unusable inventory.", 1
    };

    open my $fh, '>', $path;
    print $fh $output;
    close $fh;

    pass "Inventory written: '$path'";

    last
};

done_testing;

0
__END__

my $inventory_job
= sub
{
    my $glacier = shift;

    for(;;)
    {
        state $job_id   = '';

        my @jobz
        = grep
        {
            'InventoryRetrieval' eq $_->{ Action }
        }
        $glacier->list_jobs( $vault )
        or do
        {
            diag 'Submit inventory job...';

            $job_id
            ||= $glacier->initiate_inventory_retrieval( $vault );

            sleep 900;
        };

        my $job
        = first
        {
            $_->{ Completed }
        }
        @jobz
        or do
        {
            diag 'Waiting for inventory...';

            sleep 900;
        };

        return $job->{ JobId };
    }
};

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    for( $tmpdir )
    {
        -e || mkdir $_, 0777
        or BAIL_OUT "Failed mkdir: '$_', $!";
    }

    my $vault
    = eval
    {
        my $found   
        = first 
        {
            $_->{ VaultName } eq $vault
        }
        $glacier->list_vaults
        or
        $glacier->create_vault( $vault )
        or
        die "Failed create vault: '$vault' ($@_)";

        $vault
    }
    or BAIL_OUT "Error installing test vault: '$vault', $@";

    for my $vault_data  ( $glacier->describe_vault( $vault ) )
    {
        $vault_data
        or BAIL_OUT "Error describe_vault: '$vault', $@";

        $vault_data->{ LastInventoryDate }
        or skip "$vault lacks inventory", 1;
    }

    my $job_id  = $glacier->$inventory_job;

    my $output  = $glacier->get_job_output( $vault => $job_id )
    or do
    {
        fail "Failed download $job_id output";
        skip "No inventory for download", 1
    };

    eval { decode_json $output }
    or do
    {
        fail "Decode inventory: $@";
        skip "Unusable inventory.", 1
    };

    open my $fh, '>', $path;
    print $fh $output;
    close $fh;

    pass "Inventory written: '$path'";

    last
};

done_testing;

0
__END__
