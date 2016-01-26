use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( realbin base=t subdir=lib subonly   );

use List::Util      qw( first   );
use Scalar::Util    qw( reftype );

use Test::Deep;
use Test::More;
use Test::Glacier::API;

SKIP:
{
    $ENV{ AWS_GLACIER_FULL }
    or skip "AWS_GLACIER_FULL not set", 1;

    my $vault   = "test-glacier-module";

    my $vault_data  = $glacier->describe_vault( $vault ) 
    or BAIL_OUT "Vault '$vault' does not exist, run '12-*' tests";

    $vault_data->{ LastInventoryDate } 
    or do
    {
        diag "Vault '$vault' lacks inventory\n",
        explain $vault_data;

        skip "Vault $vault has no inventory available", 1
    };

    my @jobz    = $glacier->list_all_jobs( $vault )
    or skip "No jobs to list: '$vault'", 1;

    eval
    {
        my @expect = grep { ! $_->{ Completed } } @jobz;

        my ( undef, $found ) = $glacier->list_jobs( $vault, 'false'  );

        cmp_deeply $found, \@expect, "Incomplete jobs";

        1
    }
    or fail "list_jobs incomplete: $@";

    eval
    {
        my @expect = grep { $_->{ Completed } } @jobz;

        my ( undef, $found ) = $glacier->list_jobs( $vault, 'true'  );

        cmp_deeply $found, \@expect, "Complete jobs";

        1
    }
    or fail "list_jobs incomplete: $@";

    eval
    {
        my ( undef, $found ) 
        = $glacier->list_jobs( $vault, undef, 2  );

        ok 2 >= @$found, "Got <= 2 jobs";

        $glacier->list_jobs( $vault, undef, -1 );

        1
    }
    or fail "list_jobs incomplete: $@";

    for my $code ( qw( InProgress Succeeded Failed ) )
    {
        eval
        {
            my @expect  = grep { $code eq $_->{ StatusCode }  } @jobz;

            my ( undef, $found ) 
            = $glacier->list_jobs( $vault, undef, undef, $code );

            cmp_deeply $found, \@expect, "Status: '$code'";

            1
        }
        or fail "list_jobs: '$code', $@";
    }

    eval
    {
        my @expect  = $jobz[0];

        my ( undef, $found )
        = $glacier->list_jobs( $vault, undef, undef, undef, 1 );

        cmp_deeply $found, \@expect, "Oneshot";

        1
    }
};

done_testing;

0
__END__
