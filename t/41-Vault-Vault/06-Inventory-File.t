use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use File::Basename  qw( dirname );
use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use JSON::XS        qw( decode_json );

use Test::More;
use Test::Glacier::Vault;

my $test_vault  = "test-glacier-module";

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    for my $vault ( $proto->new( "test-glacier-$$" ) )
    {
        eval
        {
            $vault->create;

            if( $vault->exists )
            {
                pass "Scratch Vault '$vault' exists";

                if( my $last  = $vault->last_inventory )
                {
                    fail "Inventory exists for '$vault'";
                }
                else
                {
                    pass "No inventory for '$vault'";
                }
            }
            else
            {
                fail "Vault '$vault' does not exist";
            }

            $vault->delete;

            1
        }
        or fail "$vault: $@";
    }

    $proto->new( $test_vault )->last_inventory
    or skip "$test_vault lacks inventory, try tomorrow...", 1;

    for my $vault ( $proto->new( $test_vault ) )
    {
        eval
        {
            if( $vault->exists )
            {
                pass "Vault '$vault' exists";

                if( my $last  = $vault->last_inventory )
                {
                    pass "Inventory exists for '$vault'";

                    my $tmp  = './tmp';
                    -d $tmp || mkdir $tmp
                    or BAIL_OUT "Failed mkdir: '$tmp', $!";

$DB::single = 1;

                    my $path
                    = $vault->acquire_inventory
                    (
                        $tmp
                    );

                    if( -e $path )
                    {
                        -s _    or die "Zero-sized: '$vault' ($path)";
                        -r _    or die "Unreadable: '$vault' ($path)";

                        eval
                        {
                            unlink $path;
                            rmdir  dirname $path;
                            rmdir  $tmp;
                            1
                        }
                        or BAIL_OUT "Failed cleanup: $@ ($path)";
                    }
                    else
                    {
                        fail "No download: '$vault' ($path)";
                    }
                }
                else
                {
                    fail "No inventory for '$vault'";
                }
            }
            else
            {
                fail "Vault '$vault' does not exist";
            }

            1
        }
        or fail "$vault: $@";
    }
};

done_testing;

0
__END__
