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

    my $name    = "test-net-aws-glacier";
    my $vault   = $proto->new( $name );

    eval
    {
        $vault->exists
        or
        $vault->create
    }
    or BAIL_OUT "Error installing test vault: $@";

    my @pathz   = glob 't/0*.t';

    my %path2arch
    = eval
    {
$DB::single = 1;

        $vault->upload_paths( @pathz );
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

done_testing;

0
__END__
