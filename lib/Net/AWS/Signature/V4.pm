########################################################################
# housekeeping
########################################################################
package Net::AWS::Signature::V4;
use v5.20;
use autodie;
use experimental qw( lexical_subs );

use Carp            qw( croak                                   );
use Digest::SHA     qw( sha256_hex hmac_sha256 hmac_sha256_hex  );
use List::Util      qw( reduce                                  );
use Scalar::Util    qw( blessed                                 );

use DateTime::Format::Strptime qw( strptime );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
our @CARP_NOT   = ( __PACKAGE__ );

sub ALGORITHM() { 'AWS4-HMAC-SHA256' }

########################################################################
# utility subs
########################################################################

########################################################################
# extract & format pieces of the request

my $datetime
= sub
{
    my $req     = shift;
	my $date    = $req->header( 'Date' );
    my $is_iso  = $date =~ m{^ \d{8} T \d{6} Z $}x;

    my $stp_format
    = $is_iso
    ? '%Y%m%dT%H%M%SZ'          # ISO 8601
    : '%d %b %Y %H:%M:%S %Z'    # AWS4 test suite
    ;

    # remove weekday, as Amazon's test suite contains 
    # internally inconsistent dates

    substr $date, 0, 4, '' 
    if ! $is_iso;

    strptime $stp_format => $date
};

my $c_hash
= sub
{
    state $field= 'x-amz-content-sha256';

    my $req     = shift;

    $req->header( $field) || sha256_hex( $req->content );
};

my $c_path 
= sub
{
    my $req     = shift;
    my $path    = $req->uri->path;

    for( $path )
    {
        my $trail   = m{ / $}x;

        s{ (?<= [^/] ) $            }{/}x;  # force traling '/' 
        s{ / [.]?           (?=/)   }{}gx;  # remove '/./' or //
        s{ / [^/]? / [.][.] (?=/)   }{}x;   # replace "/foo/bar/../" with "/foo/"

        $trail and last;

        s{ / $}{}x;
    }

    $path
};

my $c_query
= sub
{
    my $req     = shift;

    join '&' =>
    map
    {
        defined $_->[1]
        ? join '=' => @$_
        : $_->[0]
    }
    sort
    {
        $a->[0] cmp $b->[0]
        or 
        $a->[1] cmp $b->[1]
    }
    map
    {
        my ( $key, $val ) = split '=', $_, 2;

        [ lc $key, $val ]
    }
    split '&', $req->uri->query
};

my $sign_heads
= sub
{
    my $req     = shift;

    join ';' =>
    sort
    {
        $a cmp $b
    }
    map
    {
        lc
    }
    $req->headers->header_field_names
};

my $c_heads
= sub
{
    my $req     = shift;
    my $head    = $req->headers;

    my @headz
    = map
    {
        my $field   = $_;
        my @valz    = $head->header( $field );
        
        for( @valz )
        {
            s{^ \s+  }{}x;
            s{  \s+ $}{}x;
        }

        my $value   = join ',' => sort @valz;

        join ':' => $field, $value
    }
    sort
    {
        $a cmp $b
    }
    map
    {
        lc
    }
    $head->header_field_names;

    join "\n" => @headz, ''
};

my $canonical_hash
= sub
{
    my $req     = shift;

    my $method  = $req->method;
    my $path    = $req->$c_path;
    my $query   = $req->$c_query;
    my $hash    = $req->$c_hash;
    my $c_head  = $req->$c_heads;
    my $s_head  = $req->$sign_heads;

    my $c_string
    = join "\n" =>
    (
        $method,
        $path,
        $query,
        $c_head,
        $s_head,
        $hash
    );

    sha256_hex $c_string
};

my $sig_scope
= sub
{
    state $type = 'aws4_request';

    my ( $sig, $req ) = @_;

    my $date    = $req->$datetime->strftime( '%Y%m%d' );

	join '/' => $date, @{ $sig }{ qw( endpoint service ) }, $type
};

my $string_to_sign
= sub
{
    state $iso_fmt  = '%Y%m%dT%H%M%SZ';

    my ( $sig, $req ) = @_;

    my $date    = $req->$datetime->strftime( $iso_fmt );
    my $hash    = $req->$canonical_hash;

    my $scope   = $sig->$sig_scope( $req );

    join "\n" =>
    ALGORITHM,
    $date,
    $scope,
    $hash
};

my $authz
= sub
{
    state $cred_tag = 'aws4_request';

    my ( $sig, $req ) = @_;

    my $secret  = 'AWS4' . $sig->{ secret };
    my $endpt   = $sig->{ endpoint  };
    my $serv    = $sig->{ service   };
    my $key     = $sig->{ key       };

    my $ymd         = $req->$datetime->strftime( '%Y%m%d' );
    my $authz_head  = $req->$sign_heads;

    my $sign_this   = $sig->$string_to_sign( $req );

    my $authz_cred  = join '/', $key, $ymd, $endpt, $serv, $cred_tag;

    my $signiture   
    = reduce
    {
        # notice the order of ymd and secret due to "$b, $a".

        hmac_sha256 $b, $a
    }
    $secret, $ymd, $endpt, $serv, $cred_tag;

    my $authz_sig   = hmac_sha256_hex $sign_this, $signiture;

    join ' ' =>
    ALGORITHM,
    "Credential=$authz_cred",
    "SignedHeaders=$authz_head",
    "Signature=$authz_sig"
};

########################################################################
# methods
########################################################################
########################################################################
# object manglement

sub construct
{
    my $proto   = shift;
    bless {}, blessed $proto || $proto
}
sub initialize
{
    state $fieldz   = [ qw( key secret endpoint service ) ];
    my $sig         = shift;

    for my $key ( @$fieldz )
    {
        $sig->{ $key } = shift
        or croak "Botched initialize: false '$key' ";
    }

    $sig
}
sub new
{
    my $sig = &construct;
    $sig->initialize( @_ );
    $sig
}

########################################################################
# sign a message

sub sign
{
    my $sig     = shift;
    my $req     = shift
    or croak "Bogus sign: false request";

    my $value   = $sig->$authz( $req );

    $req->header( Authorization => $value );

    return
}

# keep require happy
1
__END__
