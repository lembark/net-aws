use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( base=etc export scalar  );

use Test::More;
use Scalar::Util    qw( blessed                 );

my $madness = 'Test::Glacier::Vault';

use_ok $madness;

my @methodz
= qw
(
    last_inventory
    creation_date
    archive_count
    size
    arn
    name
);

# delay compiling this until the use has completed and
# installed the object.

eval
q{
    $proto
    // BAIL_OUT 'Failed installing prototype vault ($proto)';

    for my $found ( blessed $proto )
    {
        my $expect  = 'Net::AWS::Glacier::Vault';

        $found eq $expect
        or BAIL_OUT "$madness installs: '$found' ($expect)";
    }

    can_ok $proto, $_ for @methodz;
};

done_testing;
