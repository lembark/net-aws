########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::Vault::Upload;
use v5.20;
use autodie;

use File::Spec::Functions;

use File::Basename  qw( basename );

use Carp    qw( carp croak  );
use Fcntl   qw( O_RDONLY    );

use Exporter::Proxy
qw
(
    maximum_partition_size
    default_partition_size
    minimum_partition_size

    current_partition_size

    calculate_multipart_upload_partsize
    upload_multipart
    upload_singlepart
    upload_paths
);

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
$VERSION        = eval $VERSION;

our @CARP_NOT   = ( __PACKAGE__ );

my %vault_argz  = ();
my @arg_fieldz  = qw( api region key secret );
my $verbose     = '';

my $min_part    = 2 ** 20;
my $def_part    = 2 ** 27;
my $max_part    = 2 ** 32;

########################################################################
# utility subs
########################################################################

sub MiB()   { 2 ** 20 }

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
# methods
########################################################################

sub verbose
{
    shift;

    @_
    ? ( $verbose = shift )
    : $verbose
}

########################################################################
# archive and upload management

sub maximum_partition_size { $max_part }
sub default_partition_size { $def_part }
sub minimum_partition_size { $min_part }
sub current_partition_size
{
    state $curr = $def_part;

    my $vault   = shift;

    if( @_ )
    {
        my $size    = shift || $def_part;

        looks_like_number $size
        or croak "Non-numeric maximum paritition size: '$size' ($vault)";

        $size > $max_part
        and croak "Partition size to large: $size > $max_part ($vault)";

        $size < $min_part
        and croak "Partition size to small: $size < $min_part ($vault)";

        $curr   = $floor_mib->( $size );

        say "Using partition size: $curr"
        if $vault->verbose;
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

sub upload_multipart
{
    state $chunk_d  = 64 * MiB;
    state $buffer   = '';

    my $vault   = shift;
    my $file    = shift or croak "false file ($vault)";
    my $desc    = shift or croak "false description ($vault)";
    my $chunk   = shift || $chunk_d;

    my $fh
    = do
    {
        if( ref $file )
        {
            $file
        }
        elsif( -e $file )
        {
            sysopen my $fh, $file, 'O_RDONLY';

            $fh
        }
        else
        {
            croak "file is neither a GLOB nor existing path: '$file'"
        }
    };

    # somewhere over the rainbow...

    ...
}

sub upload_singlepart
{
    my $vault   = shift;
    my $name    = $$vault   or croak "false vault name";
    my $file    = shift     or croak "false file ($vault)";
    my $desc    = shift     or croak "false description ($vault)";

    my $fh
    = do
    {
        if( ref $file )
        {
            $file
        }
        elsif( -e $file )
        {
            -r _        or die  "Non-readable: '$file'\n";
            -s _        or warn "Zero-sized:   '$file'\n";

            sysopen my $fh, $file, 'O_RDONLY';

            $fh
        }
        else
        {
            croak "File is neither a GLOB nor existing path: '$file'"
        }
    };

    say "Upload: '$desc' ($name)";

    $vault->call_api( upload_archive => '', $fh, $desc )
}

sub upload_paths
{
    my $vault = shift;
    @_  or return;

    "$vault"
    or croak "Bogus upload_paths: vault lacks name";

    my %path2arch   = ();

    for( @_ )
    {
        my ( $path, $desc )
        = ( ref )
        ? @$_
        : ( $_, '' )
        ;

        $desc   ||= join '-', split /\s+/, $_;

        eval
        {
            say "Upload: '$path' as '$desc' ($vault)";

# check -s here to decide on single- or multi-part uploads.

            $path2arch{ $path } 
            = $vault->upload_singlepart( $path, $desc );

            say "Upload: complete";

# find the max upload rate and avoid overrunning
# it here.

            sleep 10 if @_ > 10;
        }
        or do
        {
            warn "Failed upload: $@";
            warn "Aborting upload at: '$path' ($vault)";

            last
        };
    }

    wantarray   // return;

    wantarray
    ?  %path2arch
    : \%path2arch
}

# keep require happy 
1
__END__

=head1 NAME

Net::AWS::Glacier::Vault::Upload - high-level upload functionality.

=head1 SYNOPSIS

    # see Net::AWS::Glacier::Vault for usage examples.

=head1 DESCRIPTION

Uploads, especially multi-part, are bulky enough to warrant segregating
into their own module. This also helps keep the methods honest in 
using interfaces for lower-level requests since the data required
for them is internal to Net::AWS::Glacier::Vault (sneaky, eh?).

=head2 Generic

=over 4

=item upload_paths

Stack is either path strings or arrayref's of [ path => description ],
with default description of the path.

If the file is larger than max_partition_size then it is handled as
a multi-part-upload; otherwise it is a single-part.


=item maximum_partition_size

Manages the value used to generate warnings for oversize-uploads on 
single-part uploads, croak on excessive partition size for multi-part 
uploads, and determining whether to use single- or multi-part uploads 
for files passed in as paths.

Min == 2 ** 20 (  1 Mib)
Def == 2 ** 27 (128 MiB)
Max == 2 ** 32 (  4 Gib)

Note: Amazon prefers partitions < 100MiB, 128MiB is close enough for love,
hence the default.

This rounds any amount down to the nearest MiB to comply with Glacier's
reqiurement that parititions be in units of MiB (exept for the final
one).

Passing in explicit false value resets to default; called with no 
args returns current value.

Override this with, say, a sanity check on free or total memory 
to get dynamic behavior based on system load.

=back

=head2 

=head2 Single-part uploads

=over 4

=item upload_singlepart

=back

=over 4

=item calculate_multipart_upload_partsize

=item upload_multipart

=back


=head1 SEE ALSO

=over 4

=item AWS Glacier docs

L<https://aws.amazon.com/documentation/glacier/>

=back

=head1 LICENSE

This module is licensed under the same terms as Perl 5.20 or any
later verison of Perl.

=head1 AUTHOR

Steven Lembark
