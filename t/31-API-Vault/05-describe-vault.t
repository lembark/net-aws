use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::GlacierAPI;

for( $::glacier->list_vaults ) 
{
    my $name    = $_->{ VaultName };
    my $found   = eval { $::glacier->describe_vault( $name ) };

    note 'Describe vault returns:', explain $found;

    ok ! $@,    "Errors: '$@'";

    SKIP:
    {
        $found  or skip "Nothing found for $name", 1;

        ok exists $found->{ $_ }, "Describe $name contains: '$_'"
        for
        qw
        (
            CreationDate
            LastInventoryDate
            NumberOfArchives
            SizeInBytes
            VaultARN
            VaultName
        );
    }
}

done_testing;

0
__END__
