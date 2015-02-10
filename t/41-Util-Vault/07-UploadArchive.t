use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::GlacierAPI;

SKIP:
{
    $ENV{ TEST_GLACIER_ARCHIVE }
    or skip "TEST_GLACIER_ARCHIVE not set", 1;

    my $vault
    = eval
    {
        my $name    = "test-glacier-archives";

        my $found   
        = first 
        {
            $_->{ VaultName } eq $name
        }
        $::glacier->list_vaults
        or
        $::glacier->create_vault( $name )
        or
        BAIL_OUT "Failed create vault: '$name' ($@_)";

        $name
    }
    or BAIL_OUT "Error installing test vault: $@";

    if( my $vault_data  = $::glacier->describe_vault( $vault ) )
    {
        # the stable archvie test vault does exist 

        $a = $vault_data->{ LastInventoryDate }
        ? diag "Vault inventory: '$a'"
        : diag "Vault '$vault' has no inventory", explain $vault_data
        ;

        my $arch_id
        = eval
        {
            open my $fh, '<', $0;
            $glacier->upload_archive( $vault, $fh, $0 )
        };
        my $error   = $@;

        note "Error:", $error   if $error;

        ok $arch_id, "upload_archive returns archive id.";
        note 'ArchiveID: ', $arch_id;
    }
    else
    {
        fail "Vault '$vault' does not exist";
    }
};

done_testing;

0
__END__
