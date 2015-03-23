########################################################################
# housekeeping
########################################################################

package Net::AWS::Glacier::Vault::Inventory;
use v5.20;

########################################################################
# package varaibles
########################################################################

our $VERSION    = '0.01';
eval $VERSION;

########################################################################
# methods
########################################################################

sub last_inventory
{
    state $api_op   = 'describe_vault';
    state $inv_key  = 'LastInventoryDate'; 

    my $vault       = shift;

    $vault->call_api( $api_op )->{ $inv_key }
}

sub has_current_inventory
{
    state $inv_date = '';
    state $filter
    = sub
    {
        my $job = shift;

        $job->{ Action            } eq 'Inventory'
        and
        $job->{ CompletionDate    } gt $inv_date
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
    my $dest_d  = './';
    my $time_d  = 3600 * 6;         # jobs can take up to 5 hours.

    my $vault   = shift;
    my $dest    = shift;
    my $timeout = shift // $time_d;

    my $job_id  = '';
    my $path    = '';

    my $cutoff  = time + $timeout;

    $job_id
    = do
    {
        if( my $job = $vault->has_current_inventory )
        {
            $job->{ JobId }
        }
        elsif( $job = $vault->has_pending_inventory )
        {
            $job->{ JobId }
        }
        else
        {
            $vault->call_api( 'initiate_inventory_retrieval' )
        }
    };

    for(;;)
    {
        if( $vault->job_completed( $job_id ) )
        {
            $path   = $vault->write_inventory( $job_id, $dest )
            and last;
        }
        elsif( $time > $cutoff )
        {
            die "Cutoff time exceeded: '$job_id'";
        }
        else
        {
            say "Waiting for '$job_id'";
            sleep 1800;
        }
    }

    $path
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
