use v5.20;
use autodie;
use FindBin::libs;

use Scalar::Util    qw( reftype );

use Test::More;
use Test::GlacierAPI;
 
my $method  = 'list_vaults';

my @found   = eval { $::glacier->$method };
my $error   = $@;

note "Error: $@" if $@;
note "$method returns:", explain @found;

ok ! $error,    "No errors ($error)";

for( @found )
{
    my $type    = reftype $_;

    ok 'HASH' eq $type, "Vault element is a '$type' (HASH)";
}

done_testing;

0
__END__
