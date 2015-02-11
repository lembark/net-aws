use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::Deep;
use Test::GlacierUtil;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = "test-glacier-archives";

    $::glacier->describe_vault( $vault ) 
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

    my @pass1   
    = eval
    {
        $::glacier->list_jobs( $vault )
    };

    $@
    ? fail "list_jobs: $@"
    : pass "list_jobs"
    ;

    do
    {
        my @expect  = grep { ! $_->{ Completed } } @pass1;
        my @found   = $::glacier->list_pending_jobs( $vault );

        cmp_deeply \@found, \@expect, 'Pending Jobs';
    };

    do
    {
        my @expect  = grep {   $_->{ Completed } } @pass1;
        my @found   = $::glacier->list_completed_jobs( $vault );

        cmp_deeply \@found, \@expect, 'Completed Jobs';
    };
};

done_testing;

0
__END__
