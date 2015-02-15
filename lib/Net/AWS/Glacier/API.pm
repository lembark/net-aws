########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::API;
use v5.20;
use autodie;
use experimental    qw( lexical_subs );

use HTTP::Request;
use JSON 2.61;
use LWP::UserAgent;
use POSIX;

use Carp            qw( carp croak                          );
use Digest::SHA     qw( sha256_hex                          );
use List::Util      qw( first                               );
use Scalar::Util    qw( blessed reftype looks_like_number   );
use Symbol          qw( qualify_to_ref                      );

use Net::AWS::Signature::V4;
use Net::AWS::TreeHash      qw( tree_hash tree_hash_hex );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.16';
$VERSION        = eval $VERSION;

our @CARP_NOT   = ( __PACKAGE__ );

my  $verbose    = '';

########################################################################
# utility subs
########################################################################
########################################################################
# these lack an object, chew data

my $decode_result_content
= sub
{
    my $res = shift;

    eval
    {
        my $json    = $res->decoded_content
        or die "Successful reqeust lacks content\n";

        decode_json $json
    }
    or do
    {
        croak "Invalid request content: $@";
    }
};

my $sanitize_description
= sub
{
    state $max_desc = 1024;

    my $desc    = first{ $_ } @_;

    for( $desc )
    {
        tr/\x20-\x7f//cd 
        and croak "Invalid description: contains non-ascii characters, '$_'";

        my $size    = length;

        $size > $max_desc
        and croak "Oversize description: $size > $max_desc, '$_'";
    }

    shift
};

my $floor_mib
= sub
{
    state $ln2  = log 2;

    my $size    = shift or return;

    my $exp     = int( log( $size ) / $ln2 );

    $exp >= 20
    or croak "Floor in MiB: '$size' < 1MiB ($exp)";

    2 ** $exp
};

########################################################################
# these take an object
########################################################################

########################################################################
# bottom half of HTTP request handlers

my $generate_request
= sub
{
    state $aws_version  = '2012-06-01';
    state $fixed        = [ 'x-amz-glacier-version' => $aws_version ];
    state $empty        = [];

    my $api     = shift;
    my $method  = shift or croak "false HTTP method";
    my $url     = shift or croak "false URL";
    my $fieldz  = shift || $empty;

    # any thing else on the stack is passed to HTTP::Request.

    for my $type ( reftype $fieldz )
    {
        'ARRAY' eq $type
        or croak "Non-arrayref request headers: '$type' ($fieldz)";
    }

    my $host    
    = join '.' => 'glacier', $api->{region}, 'amazonaws.com';

    my $date    = POSIX::strftime( '%Y%m%dT%H%M%SZ', gmtime );

    my $http_headz = 
    [
        @$fixed,
        Host                    => $host,
        Date                    => $date,
        @$fieldz
    ];

    my $req = HTTP::Request->new
    (
        $method => "https://$host$url",
        $http_headz,
        @_
    );

    # caller gets back signed request

    $api->{ sig }->sign( $req );

    $req
};

my $send_request
= sub
{
    my ( $api ) = @_;

    my $req = &$generate_request;
    my $res = $api->{ua}->request( $req );

    $res->is_success
    or do
    {
        # try to decode Glacier error, failing that 
        # report ua errors.

        my $status  = $res->status_line;
        my $content = $res->decoded_content;

        my $message
        = eval
        {
            my $struct  = decode_json $content;

            $struct->{ message }
        }
        || $res->message;

        croak "Failed request: $status, $message"
    };

    $res
};

# few common additions to send_request: get a header, decode the 
# content, return true (vs. handing back the entire response object).

my $execute_request
= sub
{
    !! &$send_request;
};

my $acquire_content
= sub
{
    my $api = shift;

    $api->$send_request( @_ )->$decode_result_content
};

my $acquire_header
= sub
{
    my $field   = splice @_, 1, 1;
    my $res     = &$send_request;

    $res->header( $field )
};

my $loop_request
= sub
{
    my $api     = shift;
    my $url     = shift;
    my $key     = shift // '';

    my @valz    = ();
    my $marker  = '';

    for( ;; )
    {
        my $content 
        = $api
        ->$send_request( GET => $url . $marker )
        ->$decode_result_content
        ;

        if( $key )
        {
            if( my $val = $content->{ $key } )
            {
                'ARRAY' eq reftype $val
                ? push @valz, @$val
                : push @valz,  $val
                ;
            }
            else
            {
                carp "Content lacks '$key'";
            }
        }

        my $marker  = $content->{ Marker }
        or last;

        $marker = '&' . $marker;
    }

    wantarray
    ?  @valz
    : \@valz
};

my $upload_content
= sub
{
$DB::single = 1;

    # anything larger than 4GB requires a mutipart upload.
    # anything larger than 128GB should use multipart upload.

	my ( $api, $name, $content, $desc ) = @_;


};

my $upload_single_archive
= sub
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $archive = shift or croak "false content";
    my $desc    = $sanitize_description->( @_, $name );

    my $content
    = do
    {
        my $type    = reftype $archive;

        if( 'GLOB' eq $type )
        {
            # open file handle

            local $/;
            readline $archive
        }
        elsif( $type )
        {
            croak "Unhandled structure: '$type' ($archive)";
        }
        else
        {
            $archive
        }
    };

    my $hash    = tree_hash_hex $content;
    my $sha     = sha256_hex $content;

	my $location = $api->$acquire_header
    (
        location =>

		POST => "/-/vaults/$name/archives",
		[
			'x-amz-archive-description' => $desc,
			'x-amz-sha256-tree-hash'    => $hash,
			'x-amz-content-sha256'      => $sha,
		],
		$content
	);

    my $arch_id
    = do
    {
        my @partz   = split '/' => $location;

        'vaults'    eq $partz[2]
        or croak "Unusable location: missing 'vaults', $location";

        $name       eq $partz[3]
        or croak "Unusable location: missing '$name', $location";

        'archives'  eq $partz[4]
        or croak "Unusable location: missing 'archives', $location";

        $partz[-1]
    };

    $arch_id
};

########################################################################
# methods
########################################################################

sub verbose
{
    shift;  # ignore the invocant

    @_
    ? ( $verbose = shift // '' )
    : $verbose
}

sub construct
{
    my $proto   = shift;
    bless +{}, blessed $proto || $proto
}

sub initialize
{
    state $ua   = LWP::UserAgent->new
    (
        agent=> __PACKAGE__ . '/' . $VERSION
    );

    my $api     = shift;
    my $region  = shift or croak "false 'region'";
    my $key     = shift or croak "false 'key'";
    my $secret  = shift or croak "false 'secret'";

    my $sig     = Net::AWS::Signature::V4->new
    (
        $key, $secret, $region, 'glacier'
    );

    say "# Initialize: '$region' api"
    if $verbose;

    %$api =
    (
		region  => $region,
		ua      => $ua,
		sig     => $sig,
	);

	return
}

sub new
{
    my $api = &construct;
    $api->initialize( @_ );
    $api
}

sub initialize_hash
{
    my $api     = shift;
    $api->{ hash_list }
    or croak 'Bogus initial_hash: multipart upload in progress.';

    $api->{ hash_list } = [];

    return
}

sub add_part_hash
{
    my $api     = shift;
    my $content = shift
    or croak "Bogus part_hash: missing 'content' argument";
    my $hashz   = $api->{ hash_list }
    or croak "Botched part_hash: multipart upload not in progress.";

    push @$hashz, tree_hash $content;

    unpack 'H*', $hashz->[-1]
}

sub final_hash
{
    my $api     = shift;
    my $hashz   = delete $api->{ hash_list }
    or croak "Botched final_hash: multipart upload not in progress.";

    tree_hash $hashz
}

########################################################################
# vault operations
########################################################################

for
(
    [ $execute_request, qw( create_vault    PUT       ), ],
    [ $execute_request, qw( delete_vault    DELETE    ), ],
    [ $acquire_content, qw( describe_vault  GET       ), ],
    [
        $acquire_content,
        qw
        (
            get_vault_notifications
            PUT
            /notification-configuration
        )
    ],
    [
        $execute_request,
        qw
        (
            delete_vault_notifications
            DELETE
            notification-configuration
        )
    ]
)
{
    my ( $handler, $name, $op, $post ) = @$_;

    $post   //= '';

    *{ qualify_to_ref $name }
    = sub
    {
        my $api     = shift;
        my $vault   = shift or croak "false vault name";

        $api->$handler( $op => "/-/vaults/$vault$post" )
    };
}

sub list_vaults
{
    my $api = shift;

    $api->$loop_request
    (
        '/-/vaults?limit=1000', 
        'VaultList'
    )
}

sub set_vault_notifications
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $topic   = shift or croak "false sns topic";
    my $eventz  = shift or croak "false event list";

    for my $type ( reftype $eventz )
    {
        'ARRAY' eq $type
        or croak "Non-arrayref event list ($type)";

        @$eventz
        or croak "Empty event list";
    }

	my $content = 
    {
        SNSTopic    => $topic,
        Events      => $eventz
    };

	$api->$execute_request
    (
		PUT =>
        "/-/vaults/$name/notification-configuration",
		[],
		encode_json $content
	)
}

########################################################################
# single-file archive operations
########################################################################
# using the lexical sub leaves the call stack one level deep
# for upload* methods.

for
(
    [ upload_archive    => $upload_single_archive           ],
    [ initiate_job      => \&initiate_inventory_retrieval   ],
)
{
    my ( $name, $ref ) = @$_;

    *{ qualify_to_ref $name } = $ref;
}    

sub upload_file
{
    # default archive desc == path, which is lost when
    # the file handle is passed.

    $_[3] // splice @_, 3, 1, $_[2];

    # convert path on the stack to an open file handle.

    for( $_[2] )
    {
        state $max  = 2 ** 32 - 1;

        $_      or croak "false path";

        -e _    or croak "non-existant: '$_'";
        -f _    or croak "non-file: '$_'";
        -r _    or croak "non-readable: '$_'";

        my $size = -s _
        or croak "empty file: '$_'";

        $size > $max
        and croak "Oversize file: '$_' (> $max), use multipart upload";

        open my $fh, '<', $_;
        splice @_, 2, 1, $fh;
    }

    goto &$upload_single_archive
}

sub delete_archive
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $arch_id = shift or croak "false archive id";

    $api->$execute_request
    (
        DELETE =>
        "/-/vaults/$name/archives/$arch_id"
    )
}

########################################################################
# multi-part archive operations
########################################################################

sub maximum_partition_size
{
    state $default  = 2 ** 30;
    state $curr     = $default;

    state $min      = 2 ** 20;
    state $max      = 2 ** 32;

    # caller gets back the current value either way.
    # passing in false value resets to default.

    if( @_ )
    {
        my $size    = shift || $default;

        looks_like_number $size
        or croak "Non-numeric maximum paritition size: '$size'";

        $size < $min
        and croak "Partition size to small: '$size' < $min";

        $size > $max
        and croak "Partition size to large: '$size' > $max";

        $curr   = $floor_mib->( $size );
    }

    $curr
}

sub calculate_multipart_upload_partsize
{
    my $max_count   = 10_000;

    my $api     = shift;
    my $size    = shift or croak "False archive size";

    looks_like_number $size
    or croak "Non-numeric archive size: '$size'";

    my $part    = $api->maximum_partition_size;
    my $max     = $max_count * $part ;

    $size > $max
    and croak "Archive size too large for current partition: $part";

    $part
}

sub multipart_upload_init
{
    my $api     = shift;

    $api->initialize_hash;

    my $name    = shift or croak "false vault name";
    my $size    = shift or croak "false partition size";
    my $desc    = $sanitize_description->( @_, $name );

    $api->$send_request
    (
        'x-amz-multipart-upload-id',

		POST => "/-/vaults/$name/multipart-uploads",
		[
			'x-amz-archive-description' => $desc,
			'x-amz-part-size'           => $size,
		],
	)
    or croak "Successful request lacks 'x-amz-multipart-upload-id'"
}

sub multipart_upload_upload_part
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $mult_id = shift or croak "false multi-part load id";
    my $size    = shift or croak "false partition size";
    my $index   = shift or croak "false partition index";
    my $content = shift or croak "false parition content";

    my $length  = length $content
    or croak "Empty content (chunk $index)";

    $length == $size
    or croak "Mis-sized content: $length ($size)";

    my $hash    = $api->add_part_hash( $content );
    my $sha     = sha256_hex $content;
    my $bytes   
    = do
    {
        my $start   = $size * $index;
        my $finish  = $start + $size - 1;
        
        'bytes ' . $start . '-' .  $finish  . '/*'
    };

	# range end must not be ( $size * ( $index + 1 ) - 1 )
    # or last part will fail.

	my $found
    = $api->$acquire_header
    (
        # NB: $sha, documentation seems to suggest
        # x-amz-content-sha256 may not be needed but it is!

        'x-amz-sha256-tree-hash',

		PUT =>
        "/-/vaults/$name/multipart-uploads/$mult_id",
		[
			'Content-Range'             => $bytes,
			'Content-Length'            => $size,
			'Content-Type'              => 'application/octet-stream',
			'x-amz-sha256-tree-hash'    => $hash,
			'x-amz-content-sha256'      => $sha,
		],
		$content
	);

	# check glacier tree-hash = local tree-hash

    $hash eq $found 
    or croak "Request returns invalid tree hash: '$found' ($hash)";

    $hash
}

sub multipart_upload_complete 
{
    state $arch_id_rx   = m{^ /[^/]+/vaults/[^/]+/archives/(.*) $}x;

    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $mult_id = shift or croak "false multipart upload id";
    my $size    = shift or croak "false total archive size";

    looks_like_number $size
    or croak "Non-numeric archive size: '$size'";

	my $hash    = $api->final_hash;

	my $location
    = $api->$acquire_header
    (
        location =>

		POST => "/-/vaults/$name/multipart-uploads/$mult_id",
		[
			'x-amz-sha256-tree-hash'    => $hash,
			'x-amz-archive-size'        => $size,
		],
	);

    my ( $arch_id ) = $location =~ $arch_id_rx
    or croak "Mismatched archive location: '$location'";

	$arch_id
}

sub multipart_upload_abort
{
    state $expect   = 204;

    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $mult_id = shift or croak "false multipart upload id";

    my $found = $api->$send_request
    (
		DELETE =>
        "/-/vaults/$name/multipart-uploads/$mult_id"
	)
    ->code;

    $found == $expect
    or croak "Invalid response code: '$found' ($expect)";

    delete $api->{ hash_list };

    1
}

sub multipart_upload_list_parts
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $mult_id = shift or croak "false multipart upload id";

    $api->$loop_request
    (
        "/-/vaults/$name/multipart-uploads/$mult_id?limit=1000",
        'Parts'
    )
}

sub multipart_upload_list_uploads
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";

    $api->$loop_request
    (
        "/-/vaults/$name/multipart-uploads?limit=1000",
        'UploadsList'
    )
}

########################################################################
# archive operations
########################################################################

sub initiate_archive_retrieval
{
    state $empty    = [];

    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $arch_id = shift or croak "false archive id";
    my $desc    = $sanitize_description->( @_, $name );
    my $topic   = shift // '';

    my $content = 
    {
        qw( Type archive-retrieval ArchiveID ), $arch_id
    };

    $content->{ Description } = $desc;
    $content->{ SNSTopic    } = $topic  if $topic ne '';

    $api->$acquire_header
    (
        'x-amz-job-id', 

        POST => "/-/vaults/$name/jobs",
        $empty,
        encode_json $content
    )
}

sub initiate_inventory_retrieval
{
    state $empty    = [];
    state $valid    = [ qw( JSON XML ) ];

    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $format  = shift or croak "false return data format ($name)";
    my $desc    = $sanitize_description->( @_, 'Inventory ' . $name );
    my $topic   = shift // '';

    first { $format eq $_ } @$valid
    or do
    {
        local $"    = ' ';
        croak "Invalid format: '$format' valid formats are (@$valid)";
    };

	my $content =
    { qw( Type inventory-retrieval Format ), $format };

    $content->{ Description } = $desc;
    $content->{ SNSTopic    } = $topic  if $topic ne '';

	$api->$acquire_header
    (
        'x-amz-job-id', 

		POST => "/-/vaults/$name/jobs",
		$empty,
		encode_json $content
	)
}

########################################################################
# job operations

sub describe_job
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $job_id  = shift or croak "false job id";

	$api->$acquire_content
    (
        GET =>
        "/-/vaults/$name/jobs/$job_id"
    )
}

sub get_job_output
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $job_id  = shift or croak "false job id";
    my $range   = shift;

	my @headz
    = $range
    ? ( Range => $range )
    : ()
    ;

	my $res = $api->$send_request
    (
        GET =>
        "/-/vaults/$name/jobs/$job_id/output",
        \@headz
    );

	wantarray
    ?   (
            $res->decoded_content,
            $res->header('x-amz-sha256-tree-hash')
        ) 
    : $res->decoded_content
}

sub list_jobs
{
    my $api     = shift;
    my $name    = shift or croak "false vault name";

    $api->$loop_request
    (
        "/-/vaults/$name/jobs?limit=1000",
        'JobList'
    )
}

sub iterate_list_jobs
{
    state $limit_d      = 50;
    state $comp_d       = 'true';
    state $onepass_d    = '';
    state $prior        = '';
    state $count        =  0;

    my $api     = shift;
    my $name    = shift or croak "false vault name";
    my $limit   = shift || $limit_d;
    my $comp    = shift || $comp_d;
    my $onepass = shift || $onepass_d;

    if( $onepass )
    {
        $limit  = 1;
        $prior  = '';
    }

    my $request = "/-/vaults/$name/jobs?limit=$limit&completed=$comp";

    $request    .= "&marker=$prior"
    if $prior;

    my $decoded = $api->$acquire_content( GET => $request );

    my $new     = $decoded->{ Marker    };
    my $jobz    = $decoded->{ JobList   };

    if( $onepass )
    {
        $count  = 0;
        $prior  = '';
    }
    else
    {
        my $n       = @$jobz;
        $count      += $n;

        say 
        $prior && $new 
        ? "Next list chunk: '$name' ($n, $count)"
        : $new 
        ? "Initial list chunk: '$name' ($n, $count)"
        : $prior
        ? "Final list chunk: '$name' ($n, $count)" 
        : "Single list: '$name' ($n)" 
        ;

        $count  = 0 if ! $new;
        $prior  = $new;
    }

    my $continue    = !! $new;

    ( $continue => $jobz )
}

# keep require happy

1

__END__

=head1 NAME

Net::AWS::Glacier::API - Amazon Glacier RESTful 2012-06-01 API.

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

	use Net::AWS::Glacier::API;

	my $api = Net::AWS::Glacier::API->new;
    (
		'eu-west-1',
		'AKIMYACCOUNTID',
		'MYSECRET',
	);

    # all of these croak on invalid arguments, HTTP failures.
    # methods shown here in void context return 1.
    #
    # all descriptions are printable ASCII with length <= 1024.

    # vault operations.

    $api->create_vault( $vault_name );
    $api->delete_vault( $vault_name );

    my $hashref = $api->list_vaults;
    my $hashref = $api->describe_vault( $vault_name );
    my $hashref = $api->get_vault_notifications( $vault_name );

    $api->delete_vault_notifications( $vault_name );
    $api->set_vault_notifications
    (
        $vault_name,
        $topic,
        [ event, event ... ]
    );

    # submit inventory request. 

    my $job_id  = $api->initiate_inventory_retrieval
    (
        # a.k.a. "initiate_job"

        $vault_name,
        $return_format,     # JSON or CSV 
        $job_description,   # optional
        $sns_topic          # optional
    );

    my $job_id  = $api->initiate_archive_retrieval
    (
        $vault_name,
        $archive_id_string, # from upload or inventory
        $description,       # optional
        $sns_topic          # optional
    );

    # operations on submitted jobs.
    # list & describe both include status.

    my $hashref = $api->list_jobs( $vault_name );
    my $hashref = $api->describe_job( $vault_name, $job_id );

    my $content = $api->get_job_output
    (
        # depending on what you requested this will be an inventory
        # or a nice, juicy archive.

        $vault_name,
        $job_id,        # from inventory or archive retrieval
        $range          # for multi-part retrieval.
    );

    my ( $content, $sha256_hash ) = $api->get_job_output
    (
        $vault_name,
        $job_id,        # from inventory or archive retrieval
        $range          # for multi-part retrieval.
    );

    # multi-part archives

    # partition sizes need to be 2**N with 20 <= N <= 32
    # (i.e., 1MiB .. 4GiB in multiples of 2**x * MiB).
    #
    # maximum_partition_size accounts for smaller machines that will
    # thrash attempting to upload oversize chunks of data.
    # default size is 1GiB (2**30).
    #
    # calculated multipart upload size is either $curr_max_part or
    # MiB floor of the archive size / 10_000 (max partition count).

    my $curr_max_part   = $api->maximum_partition_size;
    my $new_max_part    = $api->maximum_partition_size( $new );

	my $part_size
    = $api->calculate_multipart_upload_partsize
    (
        $archive_total_size
    );

	my $upload_id = $api->multipart_upload_init
    (
        $vault_name,
        $part_size,         # from calculate or maximum partition size
        $description        # optional
    );

    $api->multipart_upload_upload_part
    (
        $vault_name,
        $upload_id,     # from multipart_upload_init
        $size,          # size in bytes
        $index,         # 1 .. N
        $partition      # partition contents
    );

    my $archive_id  = $api->multipart_upload_complete 
    (
        $vault_name,
        $upload_id,         # from multipart_upload_init
        $tree_hash_list,    # arrayref of $tree_hash from upload
        $archive_size       # total archive size
    );

    $api->multipart_upload_abort
    (
        $vault_name,
        $upload_id          # from multipart_upload_init
    );

    my @partiton_list   = $api->multipart_upload_list_parts
    (
        # returns array[ref] of partition data 

        $vault_name,
        $upload_id          # from multipart_upload_init
    );

    my @upload_list     =  $api->multipart_upload_list_uploads
    (
        # returns array[ref] of multipart uploads

        $vault_name,
    );

=head1 DESCRIPTION

    2do:

    Main groups.
    "job_id"
    "archive_id"

=head2 Vault Operaitons

=over 4

=item Basic operations: create, delete, list, query

    $api->create_vault( $vault_name );
    $api->delete_vault( $vault_name );

    # the list is an array[ref] of names.
    # querys to glacier are chunked in units of 1000 and returned
    # as a single list.

    my @vaults  = $api->list_vaults;
    my $vaults  = $api->list_vaults;

    # Data includes the name, creation, and last_inventory date.

    my $data    = $api->describe_vault( $vault_name );
    my @data    = $api->describe_vault( $vault_name );
    my %data    = $api->describe_vault( $vault_name );

=item Vault Notifications

=item set_vault_notifications

This takes a vault name, SNS topic, and arrayref of the events for 
notification.

Valid events are:

    "ArchiveRetrievalCompleted"
    "InventoryRetrievalCompleted"

=item get_vault_notifications

This takes a vault name and returns a structure of the 
events currently enabled.

{add example structure}

=item delete_vault_notifications

This takes a vault name and deletes all notification events. 

=back

=head2 Job Management

=over 4

=item list_jobs iterate_list_jobs describe_job

list_jobs takes a vault name and returns all of the jobs available
in one pass. 

iterate_list_jobs is I<not> part of the the AWS Glacier 
specification but seems basic enough to include here. This 
helps automate the cycle of querying jobs. It takes a 
vault name, and optional parameters for filtering the list 
and returns a boolean and the current chunk of jobs. If 
the boolean is true then the next call will return anohter 
chunk of the current job list.

Optional parameters include the maximum number of jobs to list (50),
whether to only list completed jobs (true), and whether to run only
one pass. 

Passing true for onepass forces the list limit to one job and will 
always return false for continue. Its use is in quickly determining
if any jobs are avilable at all without having to manage the entire
list.

    for(;;)
    {
        my ( $continue, $job_list ) 
        = $api->iterate_list_jobs
        (
            $vault_name,
            $list_limit,    # default 50
            $only_complete, # default 'true'
            $onepass        # default false, see below
        );

        for my $job ( @$job_list )
        {
            # process the returned jobs
        }

        $continue or last;
    }


=head3 Job status structure.

=over 4

=item Job Description JSON structure:

    {     
        "Action": String,
        "ArchiveId": String,
        "ArchiveSizeInBytes": Number,
        "ArchiveSHA256TreeHash": String,
        "Completed": Boolean,
        "CompletionDate": String,
        "CreationDate": String,
        "InventorySizeInBytes": String,
        "JobDescription": String,
        "JobId": String,
        "RetrievalByteRange": String,
        "SHA256TreeHash": String,
        "SNSTopic": String,
        "StatusCode": String,
        "StatusMessage": String,
        "VaultARN": String,
        "InventoryRetrievalParameters":
        {
            "Format": String,
            "StartDate": String,
            "EndDate": String,
            "Limit": String,
            "Marker": String
        }     
    }

Notes:

=item

"CompletionDate", "InventorySizeInBytes" value will be undef
until "Completed" is true.

=item

"Completed" comes across blessed as 1 or 0, which can cause 
problems for dumping the data. Use "!! $value" to get a 
perly true/false value rather than boolean object.

=item 

"ArchiveSHA256TreeHash" is used to validate multi-part download 
results. See Example "Download it in chunks" for how to use this
field.

=back

=back 

=head2 Retrieval Operations

These create a job to perform extract the requested data: an inventory
or some archive in the vault, returning a job_id on success. The job_id
value used to locate the job via list_jobs or query its 
status via describe_job.

Once completed, job contents can be retrieved using "get_job_output".

=over 4

=item initiate_inventory_retrieval initiate_job

Requests the inventory for a given vault with a specific format,
optional description and SNS topic.

The description is available as the JobDescription in listings
returned from describe_job. SNS topics are used to trigger notification
when the inventory is available for download.

Valid formats are "JSON" and "XML".

"initiate_job" is an alias for "initiate_inventory_retrieval". 

Once completed, inventory job contents can be retrieved
using "get_job_output".

=item initiate_archive_retrieval

Requests the archive contents for a given vault and archive_id.
The optional description is available in the "JobDescription" field
in the structure returned by describe_job; optional SNS topic is
used with notificaiton events to signal when the archive is ready
for download.

=item get_job_output

Given a vault_name and job_id this attempts to return the content
for that job, returning undef if the job is not complete (i.e., the
content is not avialable). The optional "Range" paremter is the 
start and ending bytes to extract.

In a scalar context this returns the decoded HTTP request content;
an array context returns the content followed by the amazon tree hash.

=back

=head2 Single-part upload

=over 4

=item upload_archive upload_archive_from_ref

These upload a single file from storage or scalar from memory. If the 
total size is greater than 100MB Amazon stronly encourages users to 
use multi-part uploads to handle the files (see next section).

=back

=head2 Multi-part uploads

=over 4

=back

=head1 Examples

=head2 Notes

=over 4

=item 

These are short examples showing how the methods work, not complete
programs. In most cases the glacier method calls should be wrapped
in eval's at some level since all of them croak on invalid input.

=item

Inventory and archive requests once submitted and may not be available
for hours. Listing the status of a job_id string or querying the 
status of completed jobs regularly is one only way to find out when
the content is available for download, using the SNS notification 
system is the other.

For details of the SNS notification system use the AWS Documentation
link under "See Also", below.

=item Construct the glacier API object.

The region is a string like 'us-east-1", they key and secret are 
credentials supplied by Amazon.

    my $api->new( $region, $key, $secret );

=item Create a Vault

    eval
    {
        $api->create_vault( $vault_name );

        say "It worked";
    }
    or say "It failed: $@";

=item Archive a single-file

Two ways: pass in an open file handle or a sclar with the content 
to upload: Both of these return an exception or the archive_id 
value.

    my $archive_id  = $api->upload_archive
    (
        $vault_name,
        $archive_path
        $description
    );

=item Submit an inventory request

    my $job_id  = $api->initiate_inventory_retrieval
    (
        $vault_name,
        'json',                     # or csv
        'Daily inventory',          # optional
        $sns_topic                  # optional
    );

=item Submit an archive request

    my $job_id  = $api->initiate_archive_retrieval
    (
        $vault_name, 
        $archive_id,
        'Download /foo/bar',        
        $sns_topic
    ); 

=item Poll status of an individual job

The main issue at this point is "Completed":

    for(;; sleep 1800 )
    {
        my $status  = $api->describe_job
        (
            $vault_name,
            $job_id         # from initiate_*_request
        );

        $status->{ Completed }
        or next;

        return $status
    }

caller eventually gets back either the structure or an exception 
via Carp::croak describing how the request failed.

=item Download an archive in one pass.

    my $content = $api->get_job_output
    (
        $vault_name,
        $job_id
    );

=item Download an archive in chunks.

    my $total   = $status->{ ArchiveSizeInBytes };
    my $chunk   = 2 ** 27;  # i.e., 128 MiB
    my $start   = 0;
    my $finish  = $chunk - 1;

    my @hashz   = ();

    while( $start < $total
    {
        my $range   = "bytes=$start-$finish";

        my ( $piece, $piece_hash ) = $api->get_job_output
        (
            $vault_name,
            $job_id,
            Range   => $range
        ); 

        push @hashz, $piece_hash;

        # do something with this piece of the archive...
        # e.g., print $fh, $piece;

        $start  += $chunk;
        $finish += $chunk;
    }

    # at this point all of the contents are downloaded, 
    # the tree-hash of it all can be computed to validate the
    # download.
    #
    # this is compared to ArchiveSHA256TreeHash from the 
    # describe_job results to validate the contents.

    my $arch_hash   = $api->final_hash;


=item Load a multi-partition archive

=item Generate a multi-partition inventory

=item Download a multi-part archive


=back

=head1 BUG REPORTS

Please report any bugs or feature requests to
C<bug-net-aws-amazon-glacier-api at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-AWS>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SEE ALSO

=over 4

=item AWS Glacier API documentation

L<https://aws.amazon.com/documentation/glacier/>

This module uses the REST-ful API.

=item Net::AWS::Glacier::Util

Higher-level calls for download, upload, vault and job management.

=item Net::Amazon::Signature::V4 Net::Amazon::TreeHash

Alternate implementations of the AWS API.

=back

=head1 AUTHORS

Steven Lembark <lembark@wrkhors.com>

Based on Gonzalo Barco's Net::Amazon::Glacier.

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Steven lembark

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl-5.20 or any later verison of Perl.

See http://dev.perl.org/licenses/ for more information.

 
########################################################################
########################################################################
# retained for reference
########################################################################
########################################################################

=head2 Methods

=head3 list_jobs( $vault_name )

Return an array with information about all recently completed jobs for the
specified vault.
L<Amazon Glacier List Jobs (GET jobs)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-jobs-get.html>.

A call to list_jobs can result in many calls to the Amazon API at a rate of
1 per 1,000 recently completed job in existence.
Calls to List Jobs in the API are L<free|http://aws.amazon.com/glacier/pricing/#storagePricing>.

=head3 get_job_output( $vault_name, $job_id, [ $range ] )

Retrieves the output of a job, returns a binary blob. Optional range
parameter is passed as an HTTP header.
L<Amazon Glacier Get Job Output (GET output)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-job-output-get.html>.

If you pass a range parameter, you're going to want the tree-hash for your
chunk.  That will be returned in an additional return value, so collect it
like this:

	($bytes, $tree_hash) = get_job_output(...)

=head3 describe_job( $vault_name, $job_id )

Retrieves a hashref with information about the requested JobID.

L<Amazon Glacier Describe Job (GET JobID)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-describe-job-get.html>.

=head3 initiate_job( ( $vault_name, $archive_id, [ $description, $sns_topic ] )

Effectively calls initiate_inventory_retrieval.

Exists for the sole purpose or implementing the Amazon Glacier Developer Guide (API Version 2012-06-01)
nomenclature.

L<Initiate a Job (POST jobs)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-initiate-job-post.html>.

=head3 initiate_inventory_retrieval( $vault_name, $format, [ $description,
$sns_topic ] )

Initiates an inventory retrieval job. $format is either CSV or JSON.

A job description of up to 1,024 printable ASCII characters may be supplied.
Net::Amazon::Glacier does it's best to enforce this restriction. When unsure
send the string and look for Carp.

An SNS Topic to send notifications to upon job completion may also be supplied.

L<Initiate a Job (POST jobs)|docs.aws.amazon.com/amazonglacier/latest/dev/api-initiate-job-post.html#api-initiate-job-post-requests-syntax>.

=head1 JOB OPERATIONS

=head3 initiate_archive_retrieval( $vault_name, $archive_id, [
$description, $sns_topic ] )

Initiates an archive retrieval job. $archive_id is an ID previously
retrieved from Amazon Glacier.

A job description of up to 1,024 printable ASCII characters may be supplied.
Net::Amazon::Glacier does it's best to enforce this restriction. When unsure
send the string and look for Carp.

An SNS Topic to send notifications to upon job completion may also be supplied.

L<Initiate a Job (POST jobs)|docs.aws.amazon.com/amazonglacier/latest/dev/api-initiate-job-post.html#api-initiate-job-post-requests-syntax>.

sub initiate_archive_retrieval {
=head3 multipart_upload_list_uploads( $vault_name )

Returns an array ref with information on all non completed multipart uploads.
Useful to recover multipart upload ids.
L<List Multipart Uploads (GET multipart-uploads)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-multipart-list-uploads.html>

A call to multipart_upload_list can result in many calls to the Amazon API
at a rate of 1 per 1,000 recently completed job in existence.
Calls to List Multipart Uploads in the API are L<free|http://aws.amazon.com/glacier/pricing/#storagePricing>.

=head3 multipart_upload_list_parts ( $vault_name, $multipart_upload_id )

Returns an array ref with information on all uploaded parts of the, probably
partially uploaded, online archive.

Useful to recover file part tree hashes and complete a broken multipart upload.

L<List Parts (GET uploadID)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-multipart-list-parts.html>

A call to multipart_upload_part_list can result in many calls to the
Amazon API at a rate of 1 per 1,000 recently completed job in existence.
Calls to List Parts in the API are L<free|http://aws.amazon.com/glacier/pricing/#storagePricing>.

=head2 multipart_upload_abort( $vault_name, $multipart_upload_id )

Aborts multipart upload releasing the id and related online resources of
a partially uploaded archive.

L<Abort Multipart Upload (DELETE uploadID)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-multipart-abort-upload.html>.

=head2 multipart_upload_complete( $vault_name, $multipart_upload_id, $tree_hash_array_ref, $archive_size )

Signals completion of multipart upload.

$tree_hash_array_ref must be an ordered list (same order as final assembled online
archive, as opposed to upload order) of partial tree hashes as returned by
multipart_upload_upload_part

$archive_size is provided at completion to check all parts make up an archive an
not before hand to allow for archive streaming a.k.a. upload archives of unknown
size. Beware of dead ends when choosing part size. Use
calculate_multipart_upload_partsize to select a part size that will work.

Returns an archive id that can be used to request a job to retrieve the archive
at a later time on success and 0 on failure.

On failure multipart_upload_list_parts could be used to determine the missing
part or recover the partial tree hashes, complete the missing parts and
recalculate the correct archive tree hash and call multipart_upload_complete
with a successful result.

L<Complete Multipart Upload (POST uploadID)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-multipart-complete-upload.html>.

=head2 multipart_upload_upload_part( $vault_name, $multipart_upload_id, $part_size, $part_index, $part )

Uploads a certain range of a multipart upload.

$part_size must be the same supplied to multipart_upload_init for a given
multipart upload.

$part_index should be the index of a file of N $part_size chunks whose data is
passed in $part.

$part can must be a reference to a string or be a filehandle and must be exactly
the part_size supplied to multipart_upload_initiate unless it is the last past
which can be any non-zero size.

Absolute maximum online archive size is 4GB*10000 or slightly over 39Tb.
L<Uploading Large Archives in Parts (Multipart Upload) Quick Facts|docs.aws.amazon.com/amazonglacier/latest/dev/uploading-archive-mpu.html#qfacts>

Returns uploaded part tree-hash (which should be store in an array ref to be
passed to multipart_upload_complete

L<Upload Part (PUT uploadID)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-upload-part.html>.

=head2 multipart_upload_init( $vault_name, $part_size, [ $description ] )

Initiates a multipart upload.
$part_size should be carefully calculated to avoid dead ends as documented in
the API. Use calculate_multipart_upload_partsize.

Returns a multipart upload id that should be used while adding parts to the
online archive that is being constructed.

Multipart upload ids are valid until multipart_upload_abort is called or 24
hours after last archive related activity is registered. After that period id
validity should not be expected.

L<Initiate Multipart Upload (POST multipart-uploads)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-multipart-initiate-upload.html>.

=head1 MULTIPART UPLOAD OPERATIONS

Amazon requires this method for files larger than 4GB, and recommends it for
files larger than 100MB.

L<Uploading Large Archives in Parts (Multipart Upload)|http://docs.aws.amazon.com/amazonglacier/latest/dev/uploading-archive-mpu.html>

=head2 calculate_multipart_upload_partsize ( $archive_size )

Calculates the part size that would allow to uploading files of $archive_size

$archive_size is the maximum expected archive size

Returns the smallest possible part size to upload an archive of
size $archive_size, 0 when files cannot be uploaded in parts (i.e. >39Tb)

=head2 delete_archive( $vault_name, $archive_id )

Issues a request to delete a file from Glacier. $archive_id is the ID you
received either when you uploaded the file originally or from an inventory.
L<Delete Archive (DELETE archive)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-archive-delete.html>

=head2 upload_archive_from_ref( $vault_name, $ref, [ $description ] )

DEPRECATED at birth. Will be dropped in next version. A more robust
upload_archive will support file paths, refs, code refs, filehandles and more.

In the meanwhile...

Like upload_archive, but takes a reference to your data instead of the path to
a file. For data greater than 4GB, see multi-part upload. An archive
description of up to 1024 printable ASCII characters can be supplied. Returns
the Amazon-generated archive ID on success, or false on failure.

=head1 ARCHIVE OPERATIONS

=head2 upload_archive( $vault_name, $archive_path, [ $description ] )

Uploads an archive to the specified vault. $archive_path is the local path to
any file smaller than 4GB. For larger files, see MULTIPART UPLOAD OPERATIONS.

An archive description of up to 1024 printable ASCII characters can be supplied.

Returns the Amazon-generated archive ID on success, or false on failure.

L<Upload Archive (POST archive)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-archive-post.html>

=head2 delete_vault_notifications( $vault_name )

Deletes vault notifications for a given vault.

Return true on success, croaks on failure.

L<Delete Vault Notifications (DELETE notification-configuration)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-vault-notifications-delete.html>.

=head2 get_vault_notifications( $vault_name )

Gets vault notifications status for a given vault.

Returns a hash with an 'SNSTopic' and and array of 'Events' on success, croaks
on failure.

L<Get Vault Notifications (GET notification-configuration)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-vault-notifications-get.html>.

=head2 set_vault_notifications( $vault_name, $sns_topic, $events )

Sets vault notifications for a given vault.

An SNS Topic to send notifications to must be provided. The SNS Topic must
grant permission to the vault to be allowed to publish notifications to the topic.

An array ref to a list of events must be provided. Valid events are
ArchiveRetrievalCompleted and InventoryRetrievalCompleted

Return true on success, croaks on failure.

L<Set Vault Notification Configuration (PUT notification-configuration)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-vault-notifications-put.html>.

=head2 list_vaults

Lists the vaults. Returns an array with all vaults.
L<Amazon Glacier List Vaults (GET vaults)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-vaults-get.html>.

A call to list_vaults can result in many calls to the Amazon API at a rate
of 1 per 1,000 vaults in existence.
Calls to List Vaults in the API are L<free|http://aws.amazon.com/glacier/pricing/#storagePricing>.

Croaks on failure.

=head2 describe_vault( $vault_name )

Fetches information about the specified vault.

Returns a hash reference with
the keys described by L<http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-vault-get.html>.

Croaks on failure.

L<Describe Vault (GET vault)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-vault-get.html>

=head1 VAULT OPERATORS

=head2 create_vault( $vault_name )

Creates a vault with the specified name. Returns true on success, croaks on failure.
L<Create Vault (PUT vault)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-vault-put.html>

=head2 delete_vault( $vault_name )

Deletes the specified vault. Returns true on success, croaks on failure.

L<Delete Vault (DELETE vault)|http://docs.aws.amazon.com/amazonglacier/latest/dev/api-vault-delete.html>

=head1 SYNOPSIS

Amazon Glacier is Amazon's long-term storage service and can be used to store
cold archives with a novel pricing scheme.
This module implements the full Amazon Glacier RESTful API, version 2012-06-01
(current at writing). It can be used to manage Glacier vaults, upload archives
as single part or multipart up to 40.000Gb in a single element and download them
in ranges or single parts.

Perhaps a little code snippet:

	use Net::Amazon::Glacier;

	my $api->new(
		'eu-west-1',
		'AKIMYACCOUNTID',
		'MYSECRET',
	);

	my $vault = 'a_vault';

	my @vaults = $api->list_vaults();

	if ( $api->create_vault( $vault ) ) {

		if ( my $archive_id = $api->upload_archive( './archive.7z' ) ) {

			my $job_id = $api->inititate_job( $vault, $archive_id );

			# Jobs generally take about 4 hours to complete
			my $job_description = $api->describe_job( $vault, $job_id );

			# For a better way to wait for completion, see
			# http://docs.aws.amazon.com/amazonglacier/latest/dev/api-initiate-job-post.html
			while ( $job_description->{'StatusCode'} ne 'Succeeded' ) {
				sleep 15 * 60 * 60;
				$job_description = $api->describe_job( $vault, $job_id );
			}

			my $archive_bytes = $api->get_job_output( $vault, $job_id );

			# Jobs live as completed jobs for "a period", according to
			# http://docs.aws.amazon.com/amazonglacier/latest/dev/api-jobs-get.html
			my @jobs = $api->list_jobs( $vault );

			# As of 2013-02-09 jobs are blindly created even if a job for the same archive_id and Range exists.
			# Keep $archive_ids, reuse the expensive job resource, and remember 4 hours.
			foreach my $job ( @jobs ) {
				next unless $job->{ArchiveId} eq $archive_id;
				my $archive_bytes = $api->get_job_output( $vault, $job_id );
			}

		}

	}

The functions are intended to closely reflect Amazon's Glacier API. Please see
Amazon's API reference for documentation of the functions:
L<http://docs.amazonwebservices.com/amazonglacier/latest/dev/amazon-glacier-api.html>.

=head1 CONSTRUCTOR

=head2 new( $region, $access_key_id, $secret )

=head1 ROADMAP

=over 4

=item * Online tests.

=item * Implement a "simple" interfase in the lines of

		use Net::Amazon::Glacier;

		# Bless and upload something
		my $api->new( $region, $aws_key, $aws_secret, $metadata_store );

		# Upload intelligently, i.e. in resumable parts, split very big files.
		$api->simple->upload( $path || $scalar_ref || $some_fh );

		# Support automatic archive_id to some description conversion
		# Ask for a job when first called, return while it is not ready,
		# return content when ready.
		$api->simple->download( $archive_id || 'description', [ $ranges ] );

		# Request download and spawn something, wait and execute $some_code_ref
		# when content ready.
		$api->simple->download_wait( $archive_id || 'description' , $some_code_ref, [ $ranges ] );

		# Delete online archive
		$api->simple->delete( $archive_id || 'description' );

=item * Implement a simple command line cli with access to simple interface.

		glacier new us-east-1 AAIKSAKS... sdoasdod... /metadata/file
		glacier upload /some/file
		glacier download /some/file (this would spawn a daemon waiting for download)
		glacier ls

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Amazon::Glacier

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Amazon-Glacier>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Amazon-Glacier>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-Amazon-Glacier>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-Amazon-Glacier/>

=item * Check the GitHub repo, development branches in particular.

L<https://github.com/gbarco/Net-Amazon-Glacier>

=item * Gonzalo Barco

C<< <gbarco uy at gmail com, no spaces> >>

=back

