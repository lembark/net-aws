
use v5.20;
use FindBin::libs;

use Scalar::Util    qw( blessed );

use Test::More;

use_ok 'Test::GlacierAPI';

$::glacier
or BAIL_OUT "glacier not exported by GlacierAPI";

my $expect  = 'Net::AWS::Glacier::API';
my $found   = blessed $::glacier;

$found eq $expect
or BAIL_OUT "Mismatched class: '$found' ($expect)";

pass "Glacier is $expect";

done_testing;
