########################################################################
# housekeeping
########################################################################
package Test::GlacierAPI;
use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( base=etc export scalar );

use Test::More;

use Symbol      qw( qualify_to_ref );

########################################################################
# package variables
########################################################################

sub import
{
$DB::single = 1;

    shift;

    state $package  = 'Net::AWS::Glacier::API';
    state $credz
    = do
    {
        use_ok $package;

        my $config  = "$etc/test.conf";

        -e $config  or die "Non-existant: '$config";
        -s _        or die "Empty file: '$config";
        -r _        or die "Non-readable: '$config";

        my @linz
        = do
        {
            open my $fh, '<', $config;

            chomp( my @a = readline $fh );

            @a
        };

        3 == @linz or die "Bogus config: line count != 3";

        $linz[1]    =~ s{^ AWSAccessKeyId=  }{}x
        or die 'Config missing AWSAccessKeyId';

        $linz[2]    =~ s{^ AWSSecretKey=    }{}x
        or die 'Config missing AWSSecretKey';

       \@linz
    };

    my $caller  = caller;

    diag "Install: API object -> $caller";

    *{ qualify_to_ref glacier => $caller }
    = \( $package->new( @$credz ) );

    return
}

# keep require happy
1

__END__
