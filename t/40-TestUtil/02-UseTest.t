use v5.20;
use autodie;
use FindBin::libs;

use Symbol  qw( qualify );

use Test::More;

my $madness = 'Test::GlacierUtil';

use_ok $madness;

done_testing;

0
__END__
