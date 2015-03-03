use v5.20;
use autodie;
use FindBin::libs;

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::GlacierAPI;

SKIP:
{   
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $method  = 'delete_vault';
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

    ok ! $found,  "Found vault named '$argz[0]'";
}

done_testing;

0
__END__
