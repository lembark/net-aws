########################################################################
# housekeeping
########################################################################
package Net::AWS::Const;
use v5.20;
use autodie;

use Carp        qw( carp            );
use Data::Lock  qw( dlock           );
use Symbol      qw( qualify_to_ref  );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
eval $VERSION;

our @CARP_NOT   = ( __PACKAGE__ );

our $debug  = $ENV{ DEBUG_NET_AWS_CONST } || '';

########################################################################
# exported subs
########################################################################

sub const : lvalue
{
    $_[0] = $_[1] if @_ > 1;

    $_[0] // carp "Fixing undefined value"
    if $debug;

    dlock $_[0];

    # returns ref from stack to allow assignment via lvalue.

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

=head1 NAME

Net::AWS::Const -- assign a constant to a variable or symbol.

=head1 SYNOPSIS

    # installs "const".
    # this uses Data::Lock, which plays nice with state variables
    # and nested references.

    use Net::AWS::Const;    

    const my    $foo    => 'bar';
    const state $bletch => 'blort';

    # this will carp, but still does the deed.
    # this leaves verbose undef throuhout execution.

    const my $verbose;

=head1 DESCRIPTION

The const sub is declared an "lvalue", it returns a dlock-ed 
reference to the initial variable with the second argument.

=head1 SEE ALSO

=over 4

=item Data::Lock

This is where the locking mechanism comes from, and includes an 
unlock (useful for debugging and testing).

=back

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

=head1 LICENSE

This code is licensed under the same terms as Perl-5.20 itself.
