########################################################################
# housekeeping
########################################################################

package Net::AWS::Glacier::Vault::Jobs;
use v5.20;

use Carp    qw( croak   );

use Exporter::Proxy
qw
(
    list_jobs
    filter_jobs
    job_status
);

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
eval $VERSION;

my $verbose     = $ENV{ VERBOSE_NET_AWS_GLACIER_VAULT_JOBS };

########################################################################
# utility subs
########################################################################

sub verbose
{
    @_
    ? ( $verbose = shift )
    : $verbose
}

########################################################################
# jobs
########################################################################

sub list_jobs
{
    my $vault   = shift;

    my @passthru
    = do
    {
        state $api_argz = [ qw( complete limit statuscode onepass ) ];

        my %argz    = @_;

        ( @argz{ @$api_argz } )
    };

    my @jobz
    = map
    {
        Net::AWS::Glacier::Job->new( $_ )
    }
    $vault->call_api
    (
        list_all_jobs => @passthru
    );

    wantarray
    ?  @jobz
    : \@jobz
}

sub filter_jobs
{
    my $vault   = shift;
    my %argz    = @_;

    my $filter  = delete $argz{ filter }
    or croak "filter_jobs: missing/false filter value";

    grep { $filter->( $_ ) } $vault->list_jobs( %argz )
}

sub job_status
{
    my $vault   = shift;
    my $arg     = shift
    or croak "Bogus job_status: false job object/id";

    my $job
    = blessed $_[0]
    ? shift
    : Net::AWS::Glacier::Job->new( @_ )
    ;

    my $job_id  = $job->id;

    $job->statz
    (
        $vault->call_api( describe_job => $job_id )
    )
}

sub job_complete
{
    my $vault   = shift;
    my $statz   = $vault->job_status( @_ );

    $statz->{ Completed } 
    or return;

    $statz->{ StatusCode }
}

# keep require happy
1
__END__

=head1 NAME

Net::AWS::Glacier::Vault::Jobs -- internals of job management.

=head1 SYNOPSIS

    # see Net::AWS::Glacier::Vault for usage examples.

=head2 DESCRIPTION

    # returns all jobs as a single array[ref].
    # if complete & statuscode filter the request to [in]complete
    # jobs only or jobs with code of Incomplete/Successful/Failed.
    # limit defaults to 50, unless onepass is true.
    # onepass is used for "has_*" interfaces, it requests a single
    # job only.
    
    my $jobz
    = $vault->list_jobs
    (
        complete    => $boolean,
        statuscode  => $status,
        limit       => $count,
        onepass     => $boolean
    );

    # equivalent to grep { $filter->( $_ ) } $vault->list_jobs( @_ );
    
    my $jobz
    = $vault->filter_jobs
    (
        complete    => $boolean,
        limit       => $count,
        statuscode  => $status,
        onepass     => $boolean,

        filter      => sub { ... },
    );

    # returns status code (Successful/Failed) for completed jobs 
    # or undef for incomlete jobs. 

    for my $job_id ( ... )
    {
        my $status = $vault->job_status( $job_id )
        or next;

        # qw( Successful Failed )

        say "Job completed with status: $status";
    }


=head1 SEE ALSO

=over 4

=item Low-level API

Net::AWS::Glacier::API

=item AWS Glacier docs

L<https://aws.amazon.com/documentation/glacier/>

=back

=head1 LICENSE

This module is licensed under the same terms as Perl 5.20 or any
later verison of Perl.

=head1 AUTHOR

Steven Lembark
