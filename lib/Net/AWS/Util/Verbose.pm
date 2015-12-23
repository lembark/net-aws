########################################################################
# housekeeping
########################################################################
package Net::AWS::Util::Verbose;

use v5.22;
use autodie;

use List::Util  qw( first           );
use Symbol      qw( qualify_to_ref  );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';

########################################################################
# utility subs
########################################################################

sub import
{
    my $caller  = caller;

    my @namz    = ( VERBOSE => split /\W+/, $caller );

    my $found
    = first
    {
        $ENV{ $_ }
    }
    map
    {
        uc join '_' => @namz[ 0 .. $_ ]
    }
    ( 0 .. $#namz );

    $found //= '';

    *{ qualify_to_ref verbose => $caller } = \$found;

    return
}


# keep require happy
1
__END__
