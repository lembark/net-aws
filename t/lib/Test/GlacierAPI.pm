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

my $madness = 'Net::AWS::Glacier::API';

########################################################################
# utility subs
########################################################################

sub read_creds
{
    state $credfile_rx = 
    [
        qr{ ^ Location \W+ }x,
        qr{ ^ Access \s* Key \s* ID \W+ }x,
        qr{ ^ Secret \s* Access \s* Key \W+ }x
    ];

    my $config  = "$etc/test.conf";

    -e $config  or die "Non-existant: '$config";
    -s _        or die "Empty file: '$config";
    -r _        or die "Non-readable: '$config";

    my @linz
    = do
    {
        open my $fh, '<', $config;

        chomp ( my @l = readline $fh );

        grep { $_ } @l
    };

    @linz
    = map
    {
        my $rx  = $_;

        my @found
        = map
        {
            s{ $rx }{}x
            ? $_
            : ()
        }
        @linz;

        1 == @found
        or die "Missing/multiple matching lines ($rx)";

        @found
    }
    @$credfile_rx;

    @linz == @$credfile_rx
    or do
    {
        my $n   = @$credfile_rx;
        my $m   = @linz;

        die "Botched $config: $m lines ($n expected)";
    };

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

    diag "Install: API object -> $caller";

    *{ qualify_to_ref glacier => $caller } = \( $madness->new( @$credz ) );

    return
}

# keep require happy
1

__END__
