########################################################################
# housekeeping
########################################################################

package Testify;
use FindBin::libs;

use Test::More;

use Net::AWS::Util::Const qw( value );

########################################################################
# package variables
########################################################################

########################################################################
# run tests
########################################################################

sub lexical_assign
{
    value my $a => 'foo';

    ok 'foo' eq $a, "Initialized to 'foo'";

    my $b   = eval { $a = 'bar'; fail "Assigned to \$a ($a)" };

    ok 'foo' eq $a, "Assignment failed ($a)";
    ok ! $b, 'b not assigned';
    like $@, qr{read-only}, "Got 'read-only' error";
}

sub our_assign
{
    value our $a => 'bar';

    ok 'bar' eq $a, "Initialized to 'bar'";

    my $b   = eval { $a = 'foo'; fail "Assigned to \$a ($a)" };

    ok 'bar' eq $a, "Assignment failed ($a)";
    ok ! $b, 'b not assigned';
    like $@, qr{read-only}, "Got 'read-only' error";
}

sub make_const
{
    my $a = 'bar';

    ok 'bar' eq $a, "Initialized 'bar' ($a)";

    $a  = 'foo';

    ok 'foo' eq $a, "Assigned 'foo' ($a)";

    value $a;

    ok 'foo' eq $a, "Value unchanged ($a)";

    my $b   = eval { $a = 'var'; fail "Assigned to \$a ($a)" };

    ok 'foo' eq $a, "Assignment failed ($a)";
    ok ! $b, 'b not assigned';
    like $@, qr{read-only}, "Got 'read-only' error";
}

can_ok __PACKAGE__, 'value';

lexical_assign;
our_assign;
make_const;

done_testing;
