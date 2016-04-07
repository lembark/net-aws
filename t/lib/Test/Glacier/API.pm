########################################################################
# housekeeping
########################################################################
package Test::Glacier::API;
use v5.20;
use autodie;

use Test::More;

use Symbol      qw( qualify_to_ref  );
use YAML::XS    qw( Load            );

use Net::AWS::Glacier::Signature;

use Net::AWS::Util::Credential  qw( read_credential );

########################################################################
# package variables
########################################################################

my $madness = 'Net::AWS::Glacier::API';

########################################################################
# utility subs
########################################################################

sub import
{
$DB::single = 1;

    use_ok $madness;

    my @credz   = read_credential qw( test Glacier );
    my $caller  = caller;

    Net::AWS::Glacier::Signature->verbose
    (
        !! $ENV{ GLACIER_TEST_VERBOSE }
    );

    diag "Install: API object -> $caller";

    *{ qualify_to_ref glacier => $caller } 
    = \( $madness->new( @credz ) );

    return
}

# keep require happy
1
__END__
