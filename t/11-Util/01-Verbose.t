use FindBin::libs;
use Test::More;

use Symbol  qw( qualify_to_ref );

my $madness = 'Net::AWS::Util::Verbose';

require_ok Net::AWS::Util::Verbose;

if( my @found = grep {! index $_, 'VERBOSE' } keys %ENV )
{
    delete @ENV{ @found };
}

{
    package Foo::Bar;
    use Symbol  qw( qualify_to_ref );
    use Test::More;

    my $sanity  = qualify_to_ref 'verbose';

    $madness->import;

    ok ! ${ *$sanity }, "Foobar::Verbose is false";
    
    for my $expect ( qw( VERBOSE VERBOSE_FOO  VERBOSE_FOO_BAR ) )
    {
        local $ENV{ $expect } = 1;

        $madness->import;

        my $found   = ${ *$sanity };

        is  $found, $expect, "Foobar::Verbose is '$found' ($expect)";
    }

    $madness->import;

    ok ! ${ *$sanity }, "Foobar::Verbose is false";
}

done_testing;
