use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::GlacierUtil;

SKIP:
{
    $ENV{ TEST_GLACIER_ARCHIVE }
    or skip "TEST_GLACIER_ARCHIVE not set", 1;

    for( $glacier->list_vaults )
    {
        state $test_rx = qr{^ test- .+ -\d+ $}x;

        my $name    = $_->{ VaultName };

        $name   =~ /$test_rx/o
        or next;

        my $message = "Delete test vault: '$name'";

#        eval
#        {
#            $glacier->delete_vault( $name ); 
#
#            pass $message;
#        }
#        or fail $message;
    }
}

done_testing;

0
__END__
