########################################################################
# housekeeping
########################################################################

package Net::AWS::Glacier::Vault::Jobs;
use v5.20;

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

sub iterate_list_jobs
{
    state $limit_d  = 50;
    state $marker   = '';

    my $vault   = shift;

    my $comp    = shift // '';
    my $limit   = shift // $limit_d;
    my $status  = shift // '';
    my $onepass = shift // '';

    if( $onepass )
    {
        $limit  = 1;
        $marker = '';
    }

    # NB: limit default && validation is dealt with 
    # inside the api call.

    my $decoded 
    = $vault->call_api
    (
        list_jobs =>
        $comp,
        $limit,
        $status,
        $marker
    );

    $marker     = $onepass ? '' : $decoded->{ Marker    };
    my $jobz    = $decoded->{ JobList   };

    ( !! $marker, $jobz )
}

sub list_jobs
{
    my $vault   = shift;
    my @jobz    = ();

    my @passthru
    = do
    {
        state $api_argz = [ qw( complete limit statuscode onepass ) ];

        my %argz    = @_;

        ( $vault => @argz{ @$api_argz } )
    };

    for(;;)
    {
        my ( $continue, $jobz ) 
        = $vault->iterate_list_jobs
        (
            @passthru
        );

        push @jobz, @$jobz;

        $continue or last;
    }

    wantarray
    ?  @jobz
    : \@jobz
}

sub filter_jobs
{
    my $vault   = shift;
    my %argz    = @_;

    my $filter  = delete $tmp{ filter }
    or croak "filter_jobs: missing/false filter value";

    grep { $filter->( $_ ) } $vault->list_jobs( %argz )
}

sub job_status
{
    my $vault   = shift;
    my $job_id  = shift
    or croak "false job_id";

    my $statz   = $vault->call_api( describe_job => $job_id )
    or return;

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

    # sub, not method.
    # set verbosity, default $ENV{ VERBOSE_NET_AWS_GLACIER_VAULT_JOBS }

    Net::AWS::Glacier::Vault::Jobs::verbose( 1 );

    # onepass is used by has_* interfaces;
    # hardwires limit = 1, returns false for continue.
    #
    # note the positional interface.

    my ( $continue, $jobs ) 
    = $vault->iterate_list_jobs
    (

        $complete,  # default ignore
        $limit,     # default 50 jobs per call
        $status,    # default ignore
        $onepass    # default false

    );

    # iterates calling iterate_list_jobs, returnsn all jobs 
    # as a single array.
    #
    # or my @jobz = $vault->list_jobs( ... );
    
    my $jobz
    = $vault->list_jobs
    (
        complete    => $boolean,
        limit       => $count,
        statuscode  => $status,
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

    # returns status code (Success/Failed) for completed jobs 
    # or undef for incomlete jobs. 

    for my $job_id ( ... )
    {
        my $status = $vault->job_status( $job_id )
        or next;

        # $status is one of qw( Successful Failed )
    }


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
