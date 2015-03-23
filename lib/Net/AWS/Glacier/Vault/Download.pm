########################################################################
# housekeping
########################################################################

package Net::AWS::Glacier::Vault::Download;
use v5.20;

########################################################################
# package variables
########################################################################

our $VERSION = '0.01';
eval $VERSION;

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

sub write_inventory
{
    state $dest_d  = './';

    my $vault   = shift;
    my $job_id  = shift or croak "false job_id";
    my $dest    = shift // $dest_d';

    my $statz   = $vault->call_api( describe_job => $job_id );
    my $desc    = $statz->{ Description }

}

sub process_jobs
{
    my $vault       = shift;
    my $callback    = shift
    or croak "Botched process_jobs: false callback";
    my $comp_only   = shift // '';

    for(;;)
    {
        my ( $continue, $jobz )
        = $vault->call_api
        (
            iterate_list_jobs =>
            $comp_only
        );

        $vault->$callback( $_ )
        for @$jobz;

        $continue or last;
    }

    # caller gets back an exception or true.

    1
}

sub download_avilable_job
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
        if( $vault->has_completed_jobs )
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

# keep require happy
1
__END__
