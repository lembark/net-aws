########################################################################
# housekeeping
########################################################################

package Net::AWS::Glacier::Vault::Inventory;
use v5.20;

use Carp        qw( croak   );
use List::Util  qw( first   );

use Exporter::Proxy
qw
(
    initiate_inventory
    last_inventory
    has_current_inventory
    has_pending_inventory
    download_current_inventory
);

########################################################################
# package varaibles
########################################################################

our $VERSION    = '0.01';
eval $VERSION;

########################################################################
# methods
########################################################################

sub initiate_inventory
{
    state $api_op   = 'initiate_inventory_retrieval';
    state $format   = 'JSON';
    state $snooze   = 3600;
    state $cycles_d = 25;

    my $vault       = shift;
    my $cycles      = shift // $cycles_d;
    my $job_id      = '';

    for( my $i = $cycles ; --$i ; sleep $snooze )
    {
        $job_id
        = eval
        {
            $vault->call_api( $api_op => $format, @_ )
        }
        and last;

        0 < index $@, q{cannot be initiated yet}
        or die;

        my $i   = index $@, 'at /';

        print substr $@, 0, $i;
    }

    $job_id
}

sub last_inventory
{
    # caller gets back job_id of inventory.

    state $api_op   = 'describe_vault';
    state $inv_key  = 'LastInventoryDate';

    my $vault       = shift;

    $$vault
    or croak 'Bogus initiate_inventory: false name';

    $vault->call_api( $api_op )->{ $inv_key }
}

sub has_current_inventory
{
    state $inv_date = '';
    state $filter
    = sub
    {
        my $job = shift;

        $job->{ Action            } eq 'InventoryRetrieval'
        and
        $job->{ CompletionDate    } ge $inv_date
    };

    my $vault   = shift;
    $inv_date   = $vault->last_inventory;

    my @found
    = $vault->filter_jobs
    (
        filter      => $filter,
        completed   => 1,
        statuscode  => 'Succeeded',
    )
    or return;

    shift @found
}

sub has_pending_inventory
{
    state $inv_date = '';
    state $filter
    = sub
    {
        my $job = shift;

        $job->{ Action } eq 'Inventory'
    };

    my $vault   = shift;

    my @found
    = $vault->filter_jobs
    (
        filter      => $filter,
        completed   => 0,
    )
    or return;

    shift @found
}

sub download_current_inventory
{
$DB::single = 1;

    my $dest_d  = './';
    my $loop_d  = 12;       # jobs can take 5+ hours.
    my $snooze  = 1800;     # i.e., 6 hours

    my $vault   = shift;
    my $name    = $$vault
    or croak "Bogus download_current_inventory: false vault name";

    my $dest    = shift // $dest_d;
    my $count   = shift // $loop_d;

    my $job
    = first
    {
        $_  = $vault->has_current_inventory 
        or do
        {
            $vault->has_pending_inventory 
            or 
            $vault->call_api( 'initiate_inventory_retrieval' );

            say "Waiting $snooze sec for inventory ...";

            sleep $snooze;

            ''
        }
    }
    ( 1 .. 12 )
    or
    die "Cutoff time exceeded: $vault\n";

    my $job_id  = $job->{ JobId };

    # caller gets back write path (or an exception due to timeout).

    $vault->write_inventory( $job_id, $dest )
}

# keep require happy
1
__END__

=head1 NAME

Net::AWS::Glacier::Vault::Inventory -- Download & query vault inventory.

=head1 SYNOPSIS

    See Net::AWS::Glacier::Vault for synopsis.

=head1 DESCRIPTION


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
