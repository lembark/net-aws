########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::Inventory;
use v5.20;
use autodie;

use Carp;
use Data::Dumper;
use File::Spec::Functions;

use JSON::XS        qw( decode_json             );
use XML::Simple     qw( xml_in                  );

use File::Basename  qw( basename dirname        );
use List::MoreUtils qw( part                    );
use List::Util      qw( reduce                  );
use Scalar::Util    qw( blessed                 );
use Symbol          qw( qualify_to_ref          );

use Exporter::Proxy qw( dispatch=inventory );

########################################################################
# package variables
########################################################################

our $VERSION='0.01';
$VERSION=eval $VERSION;

my @formatz     = qw( JSON XML DUMPER );
my $format_d    = $formatz[0];

########################################################################
# utility subs
########################################################################

my $serialize
= sub
{
    local $Data::Dumper::Terse      = 1;
    local $Data::Dumper::Indent     = 1;
    local $Data::Dumper::Sortkeys   = 1;

    local $Data::Dumper::Purity     = 0;
    local $Data::Dumper::Deepcopy   = 0;
    local $Data::Dumper::Quotekeys  = 0;

    join "\n", map { ref $_ ? Dumper $_ : $_ } @_
};

########################################################################
# methods
########################################################################

########################################################################
# job lists

my $list_jobs
= sub
{
    my ( $glacier, $vault ) = @_;

    # $jobs[ 0 ] => pending
    # $jobs[ 1 ] => finished

    my @jobz
    = part
    {
        $_->{ Completed  }
    }
    grep
    {
        'InventoryRetrieval' eq $_->{ Action }
    }
    $glacier->list_jobs( $vault );

    wantarray
    ?  @jobz
    : \@jobz
};

my $completed_jobs
= sub
{
    my ( $glacier, $vault ) = @_;

    my $compz   = $glacier->$list_jobs( $vault )->[1];

    @$compz
    or return;

    @$compz
    = sort
    {
        $a->{ CompletionDate }
        <=>
        $b->{ CompletionDate }
    }
    @$compz;

    wantarray
    ? @$compz
    :  $compz
};

my $pending_jobs
= sub
{
    my ( $glacier, $vault ) = @_;

    my $pendz   = $glacier->$list_jobs( $vault )->[0];

    @$pendz
    or return;

    wantarray
    ? @$pendz
    :  $pendz
};

sub list_jobs
{
    my $glacier = shift;
    my $vault   = shift or croak 'False vault name';

    my $handler
    =  @_
    ? $_[0]
    ? $completed_jobs
    : $pending_jobs
    : $list_jobs
    ;

    $glacier->$handler( $vault )
}

sub current_inventory
{
    my $glacier = shift;
    my $vault   = shift or croak 'false vault name';

    if( my @jobz = $glacier->$completed_jobs( $vault ) )
    {
        
    }
}

########################################################################
# local files

sub decode
{
    my $glacier = shift;

    my ( $path, $content ) = $glacier->read_inventory( $vault );

    0 < index $path, '.json.gz'
    ? decode_json $content
    0 < index $path, '.xml.gz'
    : xml_in      $content
    : eval "$content"
}

sub read
{
    my $glacier = shift;
    my $vault   = shift or croak 'false vault name';
    my $path    = shift
    or do
    {
        my $glob    = "./inventory_$vault*gz";

        my @found   = glob $glob
        or croak "No available inventory ($glob)";

        $found[0]
    };

    ( $path => qx{ gzip -d $path } )
}

sub write
{
    local @CARP_NOT = ( __PACKAGE__ );

    my $glacier = shift;
    my $vault   = shift or croak 'false vault name';
    my $job_id  = shift or croak 'false job_id';
    my $dest    = shift || './';

    # sanity check: this has not already been downloaded.

    my $date
    = do
    {
        my $vault_data
        = $glacier->{ vault_data }
        || $glacier->vault_data;

        $vault_data->{ InventoryDate }
    };

    my $base    = join '_' => 'inventory', $vault, "$date.$format.gz";
    my $path    = catfile $dest, $base;

    -s $path
    and die "Existing: '$path'\n";

    say "Writing inventory: '$path'"
    if $verbose;

    my ( $expect, $format )
    = do
    {
        # this croaks on a bogus job_id.

        my $statz   = $glacier->describe_job( $vault, $job_id );

        $statz->{ Completed }
        or die "Incomplete: '$job_id'\n";

        (
            $statz->{ InventorySizeInBytes },
            lc $statz->{ InventoryRetrievalParameters }{ Format }
        )
    };

    my $content = $glacier->get_job_output( $vault, $job_id );

    eval
    {
        my $found   = length $content;

        $found != $expect
        and die "Mis-sized content: $found ($expect)\n";

        open my $fh, '|-', "gzip -9 > $path";
        print $fh $content;
        close $fh
    }
    or do
    {
        -e $path && unlink $path;

        die "Failed write: $@\n"
    };

    $path
}

########################################################################
# acquire an inventory

sub current_jobs
{
    my $glacier = shift;
    my $vault   = shift 
    or croak 'Bogus inventory submit: false vault name.';
    my $format  = shift || $default_format;

    my $last_inv
    = do
    {
        my $vault_data
        = $glacier->{ vault_data }
        || $glacier->describe_vault( $vault );

        $vault_data->{ LastInventoryDate }
        or die "Vault lacks Inventory: '$vault'.\n";
    };
    
    # at this point the vault appears to have an inventory worth
    # downloading.

    my @jobz = $glacier->list_jobs( $vault )
    or do
    {
        # make sure that there is something out there to wait for.

        say "Initiate inventory retrieval ($vault)"
        if $verbose;

        my $job_id
        = $glacier->initiate_retrieval
        (
            $vault,
            $format || $default_format
        );

        say "Submitting inventory job: '$format' ($job_id)"
        if $verbose;

        sleep 60;
    };

    # at this point there is at least one inventory job pending.

    return
}

sub start_job
{
    my $glacier = shift;
    my $vault   = shift
    or croak "Bogus available_inventory: false vault name";
    my $format  = shift;

    # format may be false if we don't care what comes back.
    # assumption is that the original request was suitable
    # for retrieval.

    my @jobz    = ();

    my $t0      = time
    if $verbose;

    for(;;)
    {
        state $snooze   = 900;

        @jobz = $glacier->list_completed_inventory_jobs ( $vault )
        or do
        {
            if( $verbose )
            {
                my $t1  = time - $t0;
                say "Waiting +${snooze}s for inventory job ($t1)"
                if $verbose;
            }

            sleep $snooze;
            next;
        };

        if( $format )
        {
            @jobz
            = grep
            {
                $format
                eq
                $_->{ InventoryRetrievalParameters }{ Format }
            }
            @jobz
            or do
            {
                say "Waiting for '$format' job completion"
                if $verbose;

                sleep $snooze;
                next;
            };
        }

        # found the jobs

        last
    }

    # caller gets back the most recent complete inventory
    # job of the appropriate (or any) format.

    $jobz[0]
}

sub download_current
{
$DB::single = 1;

    my $glacier = shift;
    my $vault   = shift or croak 'false vault name';
    my $format  = shift;

    local $glacier->{ vault_data }
    = $glacier->describe_vault( $vault );

    # format may be false to get any inventory available.
    # write_inventory destination is left on the stack.

    $glacier->submit_inventory( $vault, $format );

    my $job     = $glacier->available_inventory( $vault, $format );
    my $job_id  = $job->{ JobId };

    $glacier->write_inventory( $vault, $job_id, @_ )
}


# keep require happy
1
__END__

