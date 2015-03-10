########################################################################
# housekeeping
########################################################################

use v5.20;
use autodie;

use Data::Lock  qw( dlock           );
use Symbol      qw( qualify_to_ref  );

sub const : lvalue
{
    $_[0] = $_[1] if @_ > 1;

    dlock $_[0];

    # returns ref off of stack to allow assignment.

    $_[0]
}

sub import
{
    my $caller  = caller;

    *{ qualify_to_ref const => $caller } = \&const;

    return
}

# keep require happy
1
__END__
