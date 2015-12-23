use FindBin::libs;
use FindBin::libs   qw( base=etc export scalar );

use Test::More;

use Scalar::Util    qw( reftype );

my $path    = "$etc/test.conf";

-e $path
or BAIL_OUT "Missing test credential file: '$path'";

my $madness = 'Net::AWS::Util::Credential';

use_ok $madness;

eval
{
    my $credz   = read_credential( qw( test Glacier ), $path );

    note "Credentials:\n", explain $credz;

    ok 'ARRAY' eq reftype $credz,   "Test credential is 'ARRAY'";
    ok 3 == @$credz,                "Test credential has 3 elements";

    1
}
or BAIL_OUT "Failed read_credential: $@";

done_testing;
