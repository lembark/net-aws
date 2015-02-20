use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::GlacierUtil;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $name    = "test-glacier-archives";

    my $vault
    = eval
    {
        my $found   
        = first 
        {
            $_->{ VaultName } eq $name
        }
        $::glacier->list_vaults
        or
        $::glacier->create_vault( $name )
        or
        die "Failed create vault: '$name' ($@_)";

        $name
    }
    or BAIL_OUT "Error installing test vault: $@";

    if( my $vault_data  = $::glacier->describe_vault( $vault ) )
    {
        my @pathz   = glob 't/0*.t';
        my %path2arch
        = eval
        {
            $::glacier->upload_paths( $name => @pathz );
        };

        note "Upload results:\n", explain \%path2arch;

        if( $@ )
        {
            fail "Upload paths: $@";
        }
        else
        {
            $path2arch{ $_ }
            ? pass "Has archive id: '$_'"
            : fail "Lacks archive id: '$_'"
            for @pathz;
        }
    }
    else
    {
        fail "Vault '$vault' does not exist";
    }
};

done_testing;

0
__END__
