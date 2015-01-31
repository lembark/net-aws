########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier;
use v5.16;
use autodie;
use parent          qw( Net::AWS::Glacier::API  );

use Carp;
use File::Spec::Functions;
use JSON::XS;
use Object::Trampoline;

use File::Basename  qw( basename dirname        );
use Scalar::Util    qw( blessed                 );
use Symbol          qw( qualify_to_ref          );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
$VERSION        = eval $VERSION;

our @CARP_NOT   = ();

my $verbose = '';

########################################################################
# utility subs
########################################################################

########################################################################
# methods
#
# Note: construcion is handled by the API.
########################################################################

sub verbose
{
    shift;  # ignore the invocant

    @_
    ? ( $verbose = !! shift )
    : $verbose
}

########################################################################
# bundle API calls 
########################################################################

########################################################################
# job and download management

for
(
    [ qw( has_completedjobs     true    ) ],
    [ qw( has_pending_jobs      false   ) ]
)
{
    my ( $name, $status ) = @$_;

    *{ qualify_to_ref $name }
    = sub
    {
        local @CARP_NOT = ( __PACKAGE__ );

        my ( $glacier, $vault, $limit ) = @_;

        # "onepass" == true

        my ( undef, $jobz ) 
        = $glacier->chunk_list_jobs( $vault, 0, $status, 1 );

        # i.e., true if there is anything out there

        scalar @$jobz
    };
}

for
(
    [ qw( list_completed_jobs    true    ) ],
    [ qw( list_pending_jobs     false   ) ]
)
{
    my ( $name, $status ) = @$_;

    *{ qualify_to_ref $name }
    = sub
    {
        local @CARP_NOT = ( __PACKAGE__ );

        my ( $glacier, $name, $limit ) = @_;

        my @jobz    = ();

        for( ;; )
        {
            # "onepass" == false

            my ( $cont, $found ) 
            = $glacier->chunk_list_jobs( $name, $limit, $status );

            push @jobz, @$found;

            $cont or last;
        }

        wantarray
        ?  @jobz
        : \@jobz
    };
}

sub write_archive
{
    local @CARP_NOT = ( __PACKAGE__ );

$DB::single = 1;

    my $glacier = shift;
    my $vault   = shift or croak 'false vault name';
    my $job_id  = shift or croak 'false job_id';
    my $dest    = shift || './';
    my $desc    = shift // '';

    # grab the job contents in any case to get the job out
    # of the queue.

    my $path
    = do
    {
        my $base    = $desc || $job_id;

        -d $dest
        ? catfile $dest, $base
        : $dest
    };

    if( -e $path )
    {
        say "Existing path: '$path'";
        return
    }
    else
    {
        my $dir = dirname $path;

        -e $dir or croak "non-existant destination dir ($dir)";
        -w _    or croak "non-writeable '$dir'";

        say "Writing: '$path'";
    }

    eval
    {

        my $output  = $glacier->get_job_output( $vault, $job_id );

        open my $fh, '>', $path;

        $fh->binmode( 1 );

        print $fh $output;
        close $fh
    }
    or do
    {
        unlink $path;

        croak "Failed writing content: '$path', $@"
    };
}

sub write_inventory
{
    local @CARP_NOT = ( __PACKAGE__ );

$DB::single = 1;

    my $glacier = shift;
    my $vault   = shift or croak 'false vault name';
    my $job_id  = shift or croak 'false job_id';
    my $dest    = shift || './';
    my $desc    = shift // '';

    my $struct 
    = eval
    {
        # extracting the struct is expensive but saves time over
        # writing a botched inventory or discovering there isn't
        # date; having the struct beats parsing JSON with a regex.

        my $content = $glacier->get_job_output( $vault, $job_id );

        decode_json $content
    }
    or croak "Failed write_inventory: botched json, $@";

    my $date    = $struct->{ InventoryDate }
    or croak "Failed write_inventory: json lacks 'InventoryDate'";

    my $base    = "inventory-$vault-$date.json.gz";
    my $path    = catfile $dest, $base;

    -e $path
    and do
    {
        say "Skip existing: '$path'";

        return
    };

    say "Writing inventory: '$path'";

    eval
    {
        # helluva lot easier to read the stuff this way, minimal
        # difference in zipped size.

        state $coder    = JSON::XS->new->ascii->pretty;

        open my $fh, '-|', "gzip -9 > $path";

        print $fh $coder->encode( $struct );

        close $fh
    }
    or do 
    {
        unlink $path;

        croak "Failed writing inventory: $@"
    };

    $path
}

sub download_completed_job
{
    local @CARP_NOT = ( __PACKAGE__ );

    state $writerz = 
    {
        qw
        (
            ArchiveRetrieval    write_archive
            InventoryRetrieval  write_inventory
        )
    };
    state $seen = {};

    my $glacier = shift;
    my $vault   = shift or croak "false vault name";
    my $dest    = shift || '.';

    say "Download to: '$dest'";

    my %seen    = ();

    if( $dest )
    {
        $dest   .= '/';
        make_path $dest;
    }

    my $jobz    = $glacier->list_completed_jobs( $vault );

    for( @$jobz )
    {
        my ( $job_id, $type, $desc )
        = @{ $_ }{ qw( JobId Action JobDescription ) };

        $seen->{ $job_id }
        and next;

        my $writer = $writerz->{ $type }
        or do
        {
            carp "Unknown job type: '$type' ($desc)";

            next
        };

        say "Download: '$desc' ($job_id)";

        eval
        {
            $seen->{ $job_id }
            = $glacier->$writer( $vault, $job_id, $dest, $desc )
        }
        or 
        carp "Failed write: '$desc' $@ ($job_id)";
    }

    # caller can determine if the jobs should be downloaded
    # again by removing the value or track which paths are
    # available locally with the values.
    
    $seen
}

sub download_all_jobs
{
    local @CARP_NOT = ( __PACKAGE__ );

    my $glacier = shift;
    my $vault   = shift or croak "false vault";
    my $dest    = shift;

    my @pathz   = '';

    for( ;; )
    {
        if( $glacier->has_completedjobs( $vault ) )
        {
            my $seen    
            = $glacier->download_completed_job( $vault, $dest );

            my @a   = values %$seen;

            push @pathz, @a;

            local $,    = "\n\t";
            say 'Downloads:', @a;
        }
        else
        {
            say "No completed jobs to download: $_[0]";
        }

        if(  $glacier->has_pending_jobs( @_ ) )
        {
            say "Wait for pending jobs...";

            my $time    = 3600;

            for( 1 .. 60 )
            {
                local $\;
                print "Remaining: $time ...\r";

                sleep 60;

                $time   -= 60;
            }
        }
        else
        {
            say "No pending jobs: download complete";

            last
        }
    }
}

########################################################################
# archive and upload management

my $upload_path
= sub
{
    my $[
};

sub upload_paths
{
    my $glacier = shift;
    my $vault   = shift or croak "false vault name";

    @_  or return;

    my @path2arch   = ();

    for( @_ )
    {
        my ( $path, $desc )
        = (ref)
        ? @$_
        : $_
        ;

        $desc   ||= $path;

        push 
        $path2arch{ $path }
        = eval
        {
            -e $path    or die "Non-existant: '$path'\n";
            -r _        or die "Un-readable: '$path'\n";
            -s _        or die "Empty: '$path'\n";

            $glacier->upload_archive( $vault, $path, $desc )
        }
        or carp $@; 
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

Net::AWS::Glacier::Util - higher-level utilities using 
AWS::Glacier::API

=head1 SYNOPSIS

    # package or object, same results.

    my $vebose  = Net::AWS::Glacier::Util->verbose;
    my $vebose  = Net::AWS::Glacier::Util->verbose( 1 );
    my $vebose  = Net::AWS::Glacier::Util->verbose( '' );

    # these all croak on errors.

    # util object dispatches API calls into Net::AWS::Glacier::API.

    my $glacier = Net::AWS::Glacier::Util->new
    (
        $site,
        $user_key,
        $user_secret
    );

    # push a list of files into glacier. default description is 
    # the path. returns a hash[ref] of path => archive_id.
    # false explicit descriptions are set to the path (i.e., this
    # won't let you upload with a false description).

    my $path2arch = $glacier->upload_paths
    (
        $path,              # use path for description
        [ $path, $desc ],   # explicit description
        ...
    );

    my $path2arch = $glacier->upload_paths
    (
        {
            path => '',     # use path for description
            path => desc,   # use explicit description
            ...
        }
    );

    # download and record any completed jobs,
    # loop w/ 1-hour wait while any pending jobs.

    my @local   = $glacier->download_all_jobs
    (
        $vault_name,    # required
        $dest_dir       # optional, defaults to '.'
    );

    # iterate write_archive for all completed jobs.
    # returns local paths.

    my @local   = $glacier->download_completed_job
    (
        $vault_name,    # required
        $dest_dir       # optional, defaults to '.'
    );

    # write the completed archive job's output to a local path.
    # basename defaults to archive_id, dir defaults to '.'.
    # returns false if content not written.

    my $path    = $glacier->write_archive
    (
        $vault_name,
        $completed_job_id,
        $path
    );

    # write completed inventory job to a local path.
    # basename is one of
    #   "$vault_id-$inventory_date.json.gz"
    #   "$vault_id-$inventory_date.xml.gz"
    #

    my $path    = $glacier->write_inventory
    (
        $vault_name,
        $completed_job_id,
        $directory
    );

    # return counts of completed or pending incomplete jobs.

    $glacier->has_completedjobs( $vault_name );
    $glacier->has_pending_jobs( $vault_name );

    # return array[ref] of completed or pending incomplete jobs.

    $glacier->list_completed_jobs( $vault_name );
    $glacier->list_pending_jobs( $vault_name );

=head1 DESCRIPTION

None of these are necessary for accessing the AWS::Glacier API.

These provide some higher-level looping utilities for moving data in
and out of AWS' Glacier service.

=head2 Arguments

User key & secret, vault name, description are passed to Glacier::API.

The key & secret are provided by Amazon, Vault name is UTF8, 
description is printable ASCII with a length < 1025 chars. 

See Glacier::API for detailed information.

=head2 Constructor & Class Methods

=over 4

=item new

Inherited from Net::AWS::Glacier::API. This takes a facility,
user key, and user secret, returning the object.

=item verbose

    # new value is stored via "!! $value" to avoid lifecycle
    # issues with objects.

    my $curr_value  = $prototype->verbose;
    my $curr_value  = $prototype->verbose( $new_value );

=back

=head2 Pending & Completed Jobs

These return the list if complete/incomplete jobs for a vault
or a boolean (i.e., scalar @jobs_found).

These all take a vault name and maximum number of jobs to download.
The maximum job limit is 1000.

    # the first call returns an unlimited list,
    # the second call returns at most 10 jobs.

    $glacier->list_completed_jobs( $vault_name      );
    $glacier->list_completed_jobs( $vault_name, 10  );

=over 4

=item list_completed_jobs list_pending_jobs

Returns an array[ref] of Job structs.
See Net::AWS::Glacier::API under "list_jobs" for details of the
job structure.

=item has_completedjobs has_pending_jobs

These call list_*_jobs with a limit of 1, returning true or false if
any jobs are found.

=back

=head2 Download

Both write_inventory & write_archive avoid overwriting exising files.
download_completed_job tracks job_id values and will avoid acquiring 
content multiple times within the same session (e.g., if called
repeatedly from download_all_jobs).

These all take a vault name simplify calling them
from external subroutines.

=item write_inventory( $vault_name, $job_id, $local_directory );

Download & write gzip-ed output (these can get large) with a 
basename of the vault name & inventory generation timesetamp.
The optional local directory defaults to the current working
directory via './'.

=item write_archive( $vault_name, $job_id, $local_path );

Download and write the archive output as-is, the local path defaults
to the archive_id.

=item download_completed_job( $vault_name, $local_directory );

Iterates completed jobs through write_archive or write_inventory,
returning the list of downloaded paths.

=item download_all_jobs( $vault_name, $local_directory );

This has an outer loop that iterates while there are any 
incomplete jobs pending for the vault, downloading any completed
jobs each time. Each iteration includes a 1-hour sleep.
This returns the accumulated paths from all calls to download_completed.

I<Note that this call can easily take hours to complete given
the 5-hour nominal turnaround for retrieving archive content.>

=head2 Upload


TODO


=head1 SEE ALSO

=over 4

=item Net::AWS::Glacier::API

Low-level calls that mimic the Glacier API specification.

=item AWS Glacier docs

L<https://aws.amazon.com/documentation/glacier/>

=back

=head1 LICENSE

This module is licensed under the same terms as Perl 5.20 or any
later verison of Perl.

=head1 AUTHOR

Steven Lembark
