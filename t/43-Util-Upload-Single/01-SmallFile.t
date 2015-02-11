use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use Test::More;

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::GlacierAPI;

my $method  = 'create_vault';
my $vault   = 'test-glacier-module';

my $arch_id = eval { $::glacier->$method( @argz ) };

ok ! $@,    "No errors ($@)";
ok $found,  "$method returns";

note "$method returns:", explain $found;
note "Error: $@" if $@;

done_testing;

0
__END__
