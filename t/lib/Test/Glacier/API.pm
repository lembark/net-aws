########################################################################
# housekeeping
########################################################################
package Test::Glacier::API;
use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( base=etc export scalar );

use Test::More;

use Symbol      qw( qualify_to_ref );

use Net::AWS::Glacier::Signature;

########################################################################
# package variables
########################################################################

my $madness = 'Net::AWS::Glacier::API';

########################################################################
# utility subs
########################################################################

sub read_creds
{
    state $default  = "$etc/test.conf";
    state $authnz =
    [
        qw
        (
            Region
            AWSAccessKeyId
            AWSSecretKey
        )
    ];

    my $config  = shift // $default;

    -e $config  or die "Non-existant: '$config'";
    -r _        or die "Non-readable: '$config'";
    -s _        or die "Empty file:   '$config'";

    my %found
    = do
    {
        open my $fh, '<', $config;

        map
        {
            chomp;
            split '='
        }
        readline $fh
    };

    my @linz
    = map
    {
        $found{ $_ }
        or die "Bogus $config: false '$_'";
    }
    @$authnz;

    wantarray
    ?  @linz
    : \@linz
}

sub import
{
    shift;

    use_ok $madness;
    state $credz    = read_creds;

    my $caller  = caller;

    Net::AWS::Glacier::Signature->verbose
    (
        !! $ENV{ GLACIER_TEST_VERBOSE }
    );

    diag "Install: API object -> $caller";

    *{ qualify_to_ref glacier => $caller } 
    = \( $madness->new( @$credz ) );

    return
}

# keep require happy
1
__END__
