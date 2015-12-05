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
        my $time    = time;
        my $name    = "test-glacier-$$-$time";

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
        # this will normally fail due to the lack of an 
        # existing inventory for the vault.

        $glacier->initiate_inventory_retrieval( $vault, 'JSON' )
    };

    note 'Expected error:', $@;

    if
    (
        $@
        &&
        0 < index $@, 'not yet generated an initial inventory'
    )
    {
        pass 'No initial inventory avaiable';
    }
    elsif( $@ )
    {
        chomp $@;
        fail "Non-inventory failure: $@";
    }
    elsif( $job_id )
    {
        pass "Un-expected success: inventory on '$vault' ($job_id)"; 
    }
    else
    {
        fail "Un-managed exception: '$vault' has inventory, no job_id";
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
