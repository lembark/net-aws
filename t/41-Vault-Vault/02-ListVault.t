use v5.20;
use autodie;
use FindBin::libs;

use Scalar::Util    qw( reftype );

use Test::More;
use Test::Glacier::Vault;
 
my $method  = 'list_vaults';

my $vaultz
= eval
{
    my @resultz = $proto->$method;

    note "$method returns:", explain @resultz;

    \@resultz
}
or 
BAIL_OUT "Failed $proto->$method: $@";

for my $struct ( @$vaultz )
{
    my $type    = reftype $struct;

    ok 'HASH' eq $type, "Vault element is a '$type' (HASH)";

    my $name    = $struct->{ VaultName };

    my $vault   = $proto->new( $name );

    is "$vault", $name, "Vault stringifies: '$vault' ($name)";

    for
    (
        [ qw( last_inventory    LastInventoryDate   ) ],
        [ qw( creation_date     CreationDate        ) ],
        [ qw( archive_count     NumberOfArchives    ) ],
        [ qw( size              SizeInBytes         ) ],
        [ qw( arn               VaultARN            ) ],
        [ qw( name              VaultName           ) ],
    )
    {
        my ( $method, $key ) = @$_;

        my $expect  = $struct->{ $key };
        my $found   = $vault->$method;

        is $found, $expect, "$vault $method: '$found' ($expect)";
    }
}

done_testing;

0
__END__
