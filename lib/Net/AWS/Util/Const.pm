########################################################################
# housekeeping
########################################################################
package Net::AWS::Util::Const;
use v5.20;
use autodie;

use Carp        qw( carp croak      );
use Data::Lock  qw( dlock           );
use Symbol      qw( qualify_to_ref  );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.02';
eval $VERSION;

our @CARP_NOT   = ( __PACKAGE__ );

our $debug  = $ENV{ DEBUG_NET_AWS_CONST } || '';

########################################################################
# exported subs
########################################################################

sub const : lvalue
{
    # lvalue delays dlock until after state sets its own magic flag.

    $_[0] = $_[1] if @_ > 1;

    $_[0] // carp "Fixing undefined value"
    if $debug;

    dlock $_[0];

    # returns ref from stack to allow assignment via lvalue.

    $_[0]
}

sub import
{
    const state $def  = 'const';

    # dicard the dispatching class.

    shift;

    my $caller  = caller;
    my $name    = @_ ? shift : $def
    or croak "Bogus Net::AWS::Util::Const: false name";

    *{ qualify_to_ref $name => $caller } = \&const;

    return
}

# keep require happy
1
__END__

=head1 NAME

Net::AWS::Util::Const -- define a variable as constant.

=head1 SYNOPSIS

    # installs "const".
    # this uses Data::Lock, which plays nice with state variables
    # and nested references.

    use Net::AWS::Util::Const;    

    const my    $foo    => 'bar';
    const state $bletch => 'blort';

    # flag the variable as constant after assignment.

    my $verbose = '';

    const $verbose;

    # pick a name, any name...

    use Net::AWS::Util::Const qw( value );

    value my $foo => 'bar';

    # this will carp if debug is set, but works.

    const my $flag => undef;

=head1 DESCRIPTION

The const sub is declared an "lvalue", it returns a dlock-ed 
reference to the initial variable with the second argument.

The main point of this is delaying application of the const flag 
until after state has set its flag.

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
