package Net::AWS::Glacier::Test;

use v5.22;
use autodie;
use FindBin::libs;

use Test::More;

use Benchmark   qw( :hireswallclock );
use Digest::SHA qw( sha256          );

use Keyword::Declare;

sub MiB()   { 2 ** 20 };

use Net::AWS::Glacier::TreeHash qw( tree_hash reduce_hash );

my @letterz = ( 'a' .. 'z' );
my @buffsiz = map { 2 ** $_ } ( 0 .. 10 );

my $format  = '(a' . 2**20 . ')*';

sub explicit_tail
{
    my $count   = @_ / 2 + @_ % 2;

    @_
    = map
    {
        sha256 splice @_, 0, 2
    }
    ( 1 .. $count )
    ;

    @_ > 1
    and goto __SUB__;

    $_[0]
}

keyword fold ( Ident $name, Block $new_list )
{
    my $code
    = qq
    {
        sub $name
        {
            ( \@_  = do $new_list ) > 1
            and goto __SUB__;

            shift
        }
    };

    $code
}

fold implicit_tail
{
    my $count   = @_ / 2 + @_ % 2;

    map
    {
        sha256 splice @_, 0, 2
    }
    ( 1 .. $count )
}

for my $size ( @buffsiz )
{
    my @argz
    = do
    {
        my $a       = $letterz[ rand @letterz ];

        unpack $format => $a x ( $size * MiB );
    };

    my @resultz
    = map
    {
        my $handler = __PACKAGE__->can( $_ )
        or BAIL_OUT "Unknown handler: '$_'";

        my $t0      = Benchmark->new; 
        my $hash    = $handler->( @argz );
        my $t1      = Benchmark->new;

        [ $_ => $hash, timestr timediff $t1, $t0 ]
    }
    qw
    (
        explicit_tail
        implicit_tail
        reduce_hash
    );

    my $first   = $resultz[0][0];
    my $expect  = $resultz[0][1];

    for( @resultz[ 1 .. $#resultz ] )
    {
        my ( $name, $found, $time ) = @$_;

        ok $found == $expect, "$first == $name";
    }

    note "Buffer size = $size MiB";
    note map { sprintf "%14s = %s (%x)\n" => @$_[0,2] } @resultz;
}

done_testing;

# this is not a module
0

__END__
