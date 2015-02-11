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

    for( qw( pending completed ) )
    {
        my $list    = join '_' => 'list', $_, 'jobs';
        my $has     = join '_' => 'has',  $_, 'jobs';

        my @a   = $::glacier->$list( $vault );
        my $i   = @a > 0;
        my $j   = $::glacier->$has( $vault );

        ok $i == $j, "Has $_ jobs matches job list";
    }
};

done_testing;

0
__END__
