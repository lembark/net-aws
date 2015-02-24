use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use JSON::XS        qw( decode_json );
use List::Util      qw( first       );
use Scalar::Util    qw( reftype     );

use Test::More;
use Test::GlacierUtil;

my $vault   = "test-glacier-archives";
my $tmpdir  = './tmp';
my $base    = 'inventory.json';
my $path    = "$tmpdir/$base";
my $format  = 'JSON';

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    for( $tmpdir )
    {
        -e || mkdir $_, 0777
        or BAIL_OUT "Failed mkdir: '$_', $!";
    }

    my $path    
    = eval
    {
        $glacier->retrieve_inventory( $vault, $format );
    };

    if( $path )
    {
        pass "Retrieved: '$path'";

        ok -e $path, "Existing: '$path'";
        ok -s $path, "Non-empty: '$path'";

        my $struct  
        = eval
        {
            my $content = qx{ gzip -dc $path };

            decode_json $content;

            pass "Decoded $format content";

            1
        }
        or fail "Failed extracting content ($path)";

        unlink $path;
    }
    else
    {
        fail "Retrieved: '$vault', $@"
    }
}

done_testing;

0
__END__
