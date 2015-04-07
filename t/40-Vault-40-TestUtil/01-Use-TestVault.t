use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( base=etc export scalar  );

use Test::More;
use Scalar::Util    qw( blessed                 );

my $madness = 'Test::Glacier::Vault';

use_ok $madness;

eval
q{
    $vault
    // BAIL_OUT 'Failed installing $vault test object';

    for my $found ( blessed $vault )
    {
        my $expect  = 'Net::AWS::Glacier::Vault';

        $found eq $expect
        or BAIL_OUT "$madness installs: '$found' ($expect)";
    }
};

done_testing;
