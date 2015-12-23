########################################################################
# housekeeping
########################################################################
package Test::Glacier::Vault;
use v5.20;
use autodie;

use Test::More;

use Symbol                      qw( qualify_to_ref  );

use Net::AWS::Util::Credential  qw( read_credential );

########################################################################
# package variables
########################################################################

my $madness = 'Net::AWS::Glacier::Vault';

########################################################################
# utility subs
########################################################################

sub import
{
    state $proto
    = do
    {
        require_ok $madness;

        my $keyz = [ qw( region key secret ) ];
        my %tmp = ();
        @tmp{ @$keyz }  = read_credential( qw( test Glacier ) );

        $madness->new( '' => %tmp )
    };

    my $caller  = caller;

    note "Install: Util object -> $caller";

    *{ qualify_to_ref proto => $caller } = \$proto;

    return
}

# keep require happy
1

__END__
