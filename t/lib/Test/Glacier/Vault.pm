########################################################################
# housekeeping
########################################################################
package Test::Glacier::Vault;
use v5.20;
use autodie;
use FindBin::libs;
use FindBin::libs   qw( base=etc export scalar );

use Test::More;

use Symbol      qw( qualify_to_ref );

########################################################################
# package variables
########################################################################

my $madness = 'Net::AWS::Glacier::Vault';

########################################################################
# utility subs
########################################################################

sub import
{
    shift;

    my  @credz 
    = eval
    {
        require Test::Glacier::API;

        Test::Glacier::API->read_creds
    }
    or BAIL_OUT "Unable to read credentials ($@)";

    use_ok $madness;

    my $caller  = caller;

    note "Install: Util object -> $caller";

    *{ qualify_to_ref vault => $caller } 
    = \( $madness->new( @credz ) );

    return
}

# keep require happy
1

__END__
