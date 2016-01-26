########################################################################
# housekeping
########################################################################

package Net::AWS::Glacier::Vault::Download;
use v5.20;

use Carp                    qw( carp croak      );
use File::Basename          qw( dirname         );
use File::Spec::Functions   qw( catdir catfile  );

########################################################################
# package variables
########################################################################

our $VERSION = '0.01';
eval $VERSION;

our @CARP_NOT   = ( __PACKAGE__ );

use Exporter::Proxy
qw
(
    write_archive
    write_inventory
    process_jobs
    download_avilable_job
    download_all_jobs
);

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

sub inventory_path
{
    $DB::single = 1;

    my $vault   = shift;
    my $job     = shift
    or croak "Bogus inventory_path: false job_id";

    my $dest_d  = shift || '.';

    for( '', "$vault" )
    {
        $dest_d .= "/$_";

        -e $dest_d || mkdir $dest_d, 02775
        or die "Failed mkdir: '$dest_d' ($!)";

        -w $dest_d  
        or die "Botched inventory_path: non-writeable '$dest_d'";
    }

    # this raises its own exceptions.

    my ( $arn, $date ) 
    = @{ $job->data }{ qw( VaultARN CreationDate ) };

    catfile $dest_d, "inventory-$date.json"
}

sub write_inventory
{
    state $dest_d  = './';

    my $vault   = shift;
    my $job     = shift or croak "false job_id";
    my $path    = shift || $vault->inventory_path( $job );

    my $json    = $vault->call_api( get_job_output => "$job" );

    open my $fh, '>', $path
    or die "Failed open: '$path', $!\n";

    local $\;

    print $fh $json
    or die "Faild write: '$path', $!\n";

    close $fh
    or die "Faild close: '$path', $!\n";

    $path
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
            list_all_jobs =>
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
    state $writerz = 
    {
        qw
        (
            ArchiveRetrieval    write_archive
            InventoryRetrieval  write_inventory
        )
    };

    local @CARP_NOT = ( __PACKAGE__ );

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
