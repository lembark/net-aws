use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::Glacier::Vault;

for( $proto->list_all ) 
{
    for my $name (  $_->{ VaultName } )
    {
        note "Describe: '$name'";

        eval
        {
            my $vault   = $proto->new( $name );
            my $found   = $vault->describe;

            $found  or die "False describe: '$vault'";
            %$found or die "Empty describe: '$vault'";

            note "Describe: '$vault'\n", explain $found;

            ok exists $found->{ $_ }, "$name contains: '$_'"
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
            
            1
        }
        or fail "Describe fails: '$name', $@";
    }
}

done_testing;

0
__END__
