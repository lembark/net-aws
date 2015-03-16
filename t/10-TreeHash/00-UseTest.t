package Net::AWS::Glacier::Test;

use v5.20;
use FindBin::libs;

use Test::More;

my $madness = 'Net::AWS::Glacier::TreeHash';

require_ok $madness;

eval
{
    $madness->import( qw( foobar ) );
};

ok $@, "Import rejects 'foobar' ($@)";

done_testing;
