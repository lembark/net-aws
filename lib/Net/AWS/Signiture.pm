########################################################################
# housekeeping
########################################################################
package Net::AWS::Signiture;
use v5.20;
use autodie;

use Disgest::SHA    qw( sha256_hex  );
use Scalar::Util    qw( blessed     );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';

########################################################################
# utility subs
########################################################################

my $request2string
= sub
{
    my $request = shift;
};

my $request_date
= sub
{
    
};


my $authz
= sub
{
    my ( $sig, $req ) = @_;

    my $date    = $str2date->( $req->head( 'Date' ) );
    my $string  = $sig->
};

########################################################################
# methods
########################################################################
########################################################################
# object manglement

sub construct
{
    my $proto   = shift;
    bless {}, blessed $proto || $proto
}
sub initialize
{
    my $sig = shift;
    @{ $sig }{ qw( key secret endpoint service ) } = @_;
    $sig
}
sub new
{
    my $sig = &construct;
    $sig->initialize( @_ );
    $sig
}

########################################################################
# sign a message

sub sign
{
    my ( $self, $request )  = @_;

}

# keep require happy
1
__END__
