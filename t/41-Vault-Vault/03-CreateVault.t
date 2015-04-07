use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use Test::More;

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::GlacierAPI;

my $method  = 'create_vault';
my @argz    = qw( test-glacier-module );

my $found   = eval { $glacier->$method( @argz ) };

ok ! $@,    "No errors ($@)";
ok $found,  "$method returns";

note "$method returns:", explain $found;
note "Error: $@" if $@;

for( reftype $found )
{
    if( ! $_ )
    {
        # nothing more to do
    }
    elsif( 'ARRAY' eq $_ )
    {
        ok @$found, "Found is populated";
    }
    elsif( 'HASH' eq $_ )
    {
        ok %$found, "Found is populated";
    }
    else
    {
        pass "Un-handled return type: '$_'";
    }
}

my @vaultz  = $glacier->list_vaults;

note 'Exisiting vaults:', explain @vaultz;

my $found   = first { $argz[0] eq $_->{ VaultName } } @vaultz;

ok $found,  "Found vault named '$argz[0]'";

done_testing;

0
__END__