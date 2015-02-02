use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( base=etc export scalar  );

use Test::More;
use Scalar::Util    qw( blessed                 );

my $madness = 'Test::GlacierUtil';

use_ok $madness;

$::glacier
or BAIL_OUT 'Failed installing $glacier test object';

for my $found ( blessed $::glacier )
{
    my $expect  = 'Net::AWS::Glacier';

    $found eq $expect
    or BAIL_OUT "$madness installs: '$found' ($expect)";
}

done_testing;
