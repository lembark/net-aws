########################################################################
# housekeeping
########################################################################
package Test::GlacierUtil;
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
    shift;

    state $package  = 'Net::AWS::Glacier::Util';
    state $credz
    = do
    {
        use_ok $package;

        my $config  = "$etc/aws-config";

        -e $config  or die "Non-existant: '$config";
        -s _        or die "Empty file: '$config";
        -r _        or die "Non-readable: '$config";

        open my $fh, '<', $config;

        chomp( my @linz = <$fh> );

        3 == @linz or die "Bogus config: line count != 3";

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
