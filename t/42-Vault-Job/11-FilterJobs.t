use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::Deep;
use Test::Glacier::Vault;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = $proto->new( 'test-net-aws-glacier' );

    $vault->describe 
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

    my @pass1   
    = eval
    {
        $vault->list_jobs;
    }
    or BAIL_OUT "Unable to list jobs: $@";

    pass 'list_jobs';

    do
    {
        my @expect  
        = grep
        {
            $_->{ Completed }
            &&
            'InventoryRetrieval' eq $_->{ Action }
        }
        @pass1;

        my @found   = $vault->list_completed_inventory_jobs;

        cmp_deeply \@found, \@expect, 'Completed Jobs';
    };

    do
    {
        my @expect  
        = grep
        {
            ! $_->{ Completed }
            &&
            'InventoryRetrieval' eq $_->{ Action }
        }
        @pass1;

        my @found   = $vault->list_pending_inventory_jobs;

        cmp_deeply \@found, \@expect, 'Pending Jobs';
    };

};

done_testing;

0
__END__
