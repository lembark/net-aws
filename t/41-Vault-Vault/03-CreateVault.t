use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use Test::More;

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::Glacier::Vault;

my @methodz = qw( create delete );

my $vault   = $proto->new( 'test-glacier-module' );

for my $method ( @methodz )
{
    eval
    {
        $vault->$method;
        pass "$vault: '$method'";

        my @vaultz  = $vault->list_all;
        note 'Exisiting vaults:', explain @vaultz;

        my $found   
        = first { "$vault" eq $_->{ VaultName } } @vaultz;

        if( 'create' eq $method )
        {
            $found
            ? pass "Found '$vault'"
            : fail "Missing: '$vault'"
            ;
        }
        else
        {
            $found
            ? fail "Leftover: '$vault'"
            : pass "Removed: '$vault'"
            ;
        }

        1
    }
    or fail "$vault: '$method', $@";
}

done_testing;

0
__END__
