########################################################################
# housekeeping
########################################################################
package Test::Glacier::API;
use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( base=etc export scalar );

use Test::More;

use Symbol      qw( qualify_to_ref  );
use YAML::XS    qw( Load            );

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
    state $cred_fieldz = 
    [
        'Location',
        'Access Key ID',
        'Secret Access Key'
    ];

    my $config  = "$etc/test.conf";

    -e $config  or die "Non-existant: '$config";
    -s _        or die "Empty file: '$config";
    -r _        or die "Non-readable: '$config";

    my $credz
    = eval
    {
        open my $fh, '<', $config;

        local $/;

        my $yaml    = readline $fh;

        Load $yaml
    }
    or die "Failed read: '$config', $@";

    my $id  = $credz->{ Glacier }
    or die "Bogus $config: Missing 'Glacier'";

    my @linz
    = map
    {
        $id->{ $_ }
        or die "Missing: '$_'"
    }
    @$cred_fieldz;

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
