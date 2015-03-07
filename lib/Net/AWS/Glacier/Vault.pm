########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::Vault;
use v5.20;
use autodie;

use Carp;
use Const::Fast;
use Data::Dumper;
use File::Spec::Functions;

use JSON::XS        qw( decode_json             );
use XML::Simple     qw( xml_in                  );

use File::Basename  qw( basename dirname        );
use List::Util      qw( reduce                  );
use Scalar::Util    qw( blessed refaddr         );
use Symbol          qw( qualify_to_ref          );

use Net::AWS::Glacier::API;

use overload 
    q{"}    => sub { my $vault = shift; $$vault }
    q{bool} => sub { my $vault = shift; !! $$vault }
;

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
$VERSION        = eval $VERSION;

our @CARP_NOT   = ();

my $verbose         = '';
my $default_format  = 'JSON';
my %vault_argz      = ();
my @arg_fieldz      = qw( api region key secret );

########################################################################
# utility subs
########################################################################

########################################################################
# methods
########################################################################

sub verbose
{
    shift;  # ignore the invocant

    @_
    ? ( $verbose = !! shift )
    : $verbose
}

########################################################################
# object manglement

while( my ($i, $name ) = each @arg_fieldz )
{
    # setting these is mainly useful for the factory object.

    *{ qualify_to_ref $name }
    = sub
    {
        my $vault   = shift;
        my $argz    = $vault_argz{ refaddr $vault }
        or croak "Bogus $name: uninitialized object '$vault'";

        my $value   = shift
        // return $argz->[ $i ];

        $argz->[ $i ] = $value
    };
}

sub construct
{
    my $proto   = shift;
    my $class   = blessed $proto;

    my $vault   = bless \( my $a = '' ), $class || $proto;

    $vault_argz{ refaddr $vault }
    = $class
    ? $vault_argz{ refaddr $proto }
    : []
    ;

    $vault
}

sub initialize
{
    my $vault   = shift;
    $$vault     = shift;
    
    # note that the name might be false for a factory object.

    if( @_ )
    {
        my %initz   = @_;

        for( @arg_fieldz )
        {
            my $value   = $initz{ $_ } // next;

            $vault->$_( $value );
        }
    }

    $vault
}

sub new
{
    my $vault   = &construct;

    $vault->intialize( @_ );

    $vault
}

DESTROY
{
    my $vault = shift;

    delete $vault_argz{ refaddr $vault }

    return
}

########################################################################
# interface to low-level calls.
# everything below this point passes through here at some point.
########################################################################

sub call_api
{
    my $vault   = shift;
    my $name    = $$vault
    || croak "Botched call_api: vault must have a name";

    my $op  = shift
    or croak "Bogus call_api: missing operation ($name)";

    my $argz    = $vault_argz{ refaddr $vault }
    or croak "Un-initialized vault: '$vault'";

    my $api     = $argz->[0]
    ||= do
    {
        state $proto    = 'Net::AWS::Glacier::API';

        $proto->new( @{ $argz }[ 1 .. $#arg_fieldz ]
    };

    $api->glacier_api( $op, $name, @_ )
}

########################################################################
# job and download management
########################################################################

########################################################################
# standard collection of job queries

for
(
    [ has   => 1 ],
    [ list  => 0 ],
)
{
    my ( $output, $onepass ) = @$_;

    for
    (
        [ qw( pending  false   ) ],
        [ qw( completed true    ) ],
    )
    {
        my ( $status, $completed ) = @_;

        for
        (
            [ qw( inventory Inventory   ) ],
            [ qw( download  Download    ) ],
        )
        {
            my ( $type, $action ) = @$_;

            my $name    = join '_' => $output, $status, $type, 'jobs';

            *{ qualify_to_ref $name }
            = sub
            {
                local @CARP_NOT = ( __PACKAGE__ );

                my $vault   = shift;
                my $limit   = $onepass ? 1 : shift;

                # note: limit validation is dealt with in the api call.

                for( ;; )
                {
                    my ( $cont, $found ) 
                    = $vault->call_api
                    (
                        iterate_list_jobs => $limit, $status
                    );

                    # onepass: caller gets back true if N > 0 jobs.

                    return !! @$found
                    if $onepass;

                    # otherwise accumulate the jobs until there is
                    # nothing left.

                    push @jobz, @$found;
                    $cont       or last;
                }

                # not a one-pass lookup: hand back the list.

                wantarray
                ?  @jobz
                : \@jobz
            };
        }
    }
}

sub has_current_inventory
{
    state $filter_complete
    = sub
    {
        my ( $vault, $cutoff ) = @_;

        first
        {
            $_->{ Action            } eq 'Inventory'
            and
            $_->{ CompletionDate    } gt $cutoff
        }
        $vault->list_completed_jobs
    };
    state $desc     = 'describe_vault';
    state $inv_key  = 'LastInventoryDate'; 

    my $vault       = shift;
    my $inv_date    = $vault->call_api( $desc )->{ $inv_key };

    # this will eventually exit since a job is submitted if necessary
    # and they will eventually complete.

    for(;;)
    {
        $vault->$filter_complete( $inv_date )
        and last;
    }

}

########################################################################
# output contents of jobs once they are completed

sub write_archive
{
    local @CARP_NOT = ( __PACKAGE__ );

    my $vault   = shift;
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

        my $output  
        = $vault->call_api
        (
            get_job_output => $job_id
        );

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

########################################################################
# acquire job contents: inventory or archive.

sub download_completed_job
{
    # avoid re-processing jobs we've alrady snagged.

    state $seen     = {};

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

    my $vault   = shift;
    my $dest    = shift || '.';

    say "Download to: '$dest' ($vault)";

    if( $dest )
    {
        $dest   .= '/';
        make_path $dest;
    }

    my $jobz    = $vault->call_api( 'list_completed_jobs' ); 

    for( @$jobz )
    {
        my ( $job_id, $type, $desc )
        = @{ $_ }{ qw( JobId Action JobDescription ) };

        # note that there may be an existing false value due to 
        # a failed $valut->$writer( ... ), below.

        $seen->{ $job_id }
        and next;

        my $writer = $writerz->{ $type }
        or do
        {
            carp "Unknown job type: '$type' ($desc)";

            next
        };

        say "Download: '$desc' ($job_id)";

        # use carp down here, not croak in order to process all
        # available jobs.
        #
        # success leaves $seen with a value of the local path.

        eval
        {
            $seen->{ $job_id }
            = $vault->$writer( $vault, $job_id, $dest, $desc )
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

    my $vault   = shift;
    my $dest    = shift // '.';

    my @pathz   = '';

    for( ;; )
    {
        if( $vault->has_completedjobs )
        {
            my $seen    = $vault->download_completed_job( $dest );
            my @a       = values %$seen;

            push @pathz, @a;

            local $,    = "\n\t";
            say 'Downloads:', @a;
        }
        else
        {
            say "No completed jobs to download: $_[0]";
        }

        if(  $vault->has_pending_jobs )
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

sub download_current_inventory
{
    state $filter_complete
    = sub
    {
        my ( $vault, $cutoff ) = @_;

        first
        {
            $_->{ Action            } eq 'Inventory'
            and
            $_->{ CompletionDate    } gt $cutoff
        }
        $vault->list_completed_jobs
    };
    state $desc     = 'describe_vault';
    state $inv_key  = 'LastInventoryDate'; 

    my $vault       = shift;
    my $inv_date    = $vault->call_api( $desc )->{ $inv_key };

    # this will eventually exit since a job is submitted if necessary
    # and they will eventually complete.

    for(;;)
    {
        $vault->$filter_complete( $inv_date )
        and last;
    }

    # if there isn't an completed inventory job later than the last
    # inventory or a pending one then submit a new job.

    $vault->$filter_jobs( $inv_date )

    # now download any completed inventory jobs until at least one
    # of them is afte the last vault inventory.
    # 

    for(;;)
    {
        $found
        = first
    }


    for my $job $vault->list_completed_jobs


    # return a path to the latest inventory available.
}

########################################################################
# archive and upload management

sub upload_paths
{
    my $vault = shift;

    @_  or return;

    my %path2arch   = ();

    for( @_ )
    {
        my ( $path, $desc )
        = (ref)
        ? @$_
        : $_
        ;

        $path2arch{ $path } 
        = eval
        {
            $vault->call_api( upload_archive => $path, $desc )
        }
        or carp "'$path', $@"; 
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

    my $factory = Net::AWS::Glacier::Vault->new
    (
        ''
        $region,
        $user_key,
        $user_secret
    );

    my $vault   = $factory->vault( 'vault_name' );

    # push a list of files into glacier. default description is 
    # the path. returns a hash[ref] of path => archive_id.
    # false explicit descriptions are set to the path (i.e., this
    # won't let you upload with a false description).

    my $path2arch = $vault->upload_paths
    (
        $path,              # use path for description
        [ $path, $desc ],   # explicit description
        ...
    );

    my $path2arch = $vault->upload_paths
    (
        {
            path => '',     # use path for description
            path => desc,   # use explicit description
            ...
        }
    );

    # download and record any completed jobs,
    # loop w/ 1-hour wait while any pending jobs.

    my @local   = $vault->download_all_jobs
    (
        $vault_name,    # required
        $dest_dir       # optional, defaults to '.'
    );

    # iterate write_archive for all completed jobs.
    # returns local paths.

    my @local   = $vault->download_completed_job
    (
        $vault_name,    # required
        $dest_dir       # optional, defaults to '.'
    );

    # write the completed archive job's output to a local path.
    # basename defaults to archive_id, dir defaults to '.'.
    # returns false if content not written.

    my $path    = $vault->write_archive
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

    my $path    = $vault->write_inventory
    (
        $vault_name,
        $completed_job_id,
        $directory
    );

    # return counts of completed or pending incomplete jobs.

    $vault->has_completedjobs( $vault_name );
    $vault->has_pending_jobs( $vault_name );

    # return array[ref] of completed or pending incomplete jobs.

    $vault->list_completed_jobs( $vault_name );
    $vault->list_pending_jobs( $vault_name );

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
