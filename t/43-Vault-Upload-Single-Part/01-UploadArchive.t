use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::More;
use Test::Glacier::Vault;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = $proto->new( 'test-glacier-module' );

    my $vault_data  = $vault->describe 
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

    # the stable archive test vault does exist 

    $a = $vault_data->{ LastInventoryDate }
    ? diag "Vault inventory: '$a'"
    : diag "Vault '$vault' has no inventory", explain $vault_data
    ;

    $DB::single = 1;

    my $content = qx{ cat $0 };

    my $arch_id 
    = eval { $vault->upload_archive( $vault, $content ) };

    my $error   = $@;

    note "Error:", $error   if $error;
    note "ArchID:", $arch_id;

    ok $arch_id, "upload_archive returns archive id ($arch_id)";
};

done_testing;

0
__END__
