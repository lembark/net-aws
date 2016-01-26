use v5.20;
use autodie;
use FindBin::libs;

use Scalar::Util    qw( reftype );

use Test::More;
use Test::Glacier::Vault;
 
my $method  = 'list_vaults';

my @found   = eval { $proto->$method };
my $error   = $@;

note "Error: $@" if $@;
note "$method returns:", explain @found;

ok ! $error,    "No errors ($error)";

for my $struct ( @found )
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
