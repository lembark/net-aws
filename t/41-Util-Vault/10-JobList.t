use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::GlacierAPI;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = "test-glacier-archives";

    $glacier->describe_vault( $vault ) 
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

    my @pendz   
    = eval
    {
        $glacier->list_jobs( $vault )
    };

    $@
    ? fail "list_jobs: $@"
    : pass "list_jobs"
    ;

    note "Job data:\n", explain \@pendz;
};

done_testing;

0
__END__
