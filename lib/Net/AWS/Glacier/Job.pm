########################################################################
# housekeeping
########################################################################

package Net::AWS::Glacier::Job;
use v5.22;
use autodie;
use overload 
    q{""}   => sub { my $job = shift; $$job     },
    q{bool} => sub { my $job = shift; !! $$job  },
;

use Carp;
use NEXT;

use List::Util      qw( first                   );
use Scalar::Util    qw( blessed refaddr reftype );
use Symbol          qw( qualify_to_ref          );

use Net::AWS::Util::Const;
use Net::AWS::Util::Verbose;

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
$VERSION        = eval $VERSION;

our @CARP_NOT   = ( __PACKAGE__ );

our $AUTOLOAD   = '';

my %job_datz    = ();

########################################################################
# utility subs
########################################################################

my $sanitize
= sub
{
    my $hash    = shift;

    while( my ($k,$v) = each %$hash )
    {
        if( defined $v )
        {
            if( 'HASH' eq reftype $v  )
            {
                __SUB__->( $v );

                %$v or delete $hash->{ $k };
            }
            elsif( blessed $v )
            {
                # convert boolean objects to un-blessed scalars.

                $hash->{ $k }   = !! $v;
            }
            else
            {
                # nothing more to do
            }
        }
        else
        {
            delete $hash->{ $k };
        }
    }

    const $hash
};

########################################################################
# methods
########################################################################

sub data
{
    my $job = shift;

    my $id
    = blessed $job
    ? $$job
    : shift
    or 
    croak "Bogus data: un-blessed job with false argument";

    my $found   = $job_datz{ $id }
    or croak "Bogus data: unknown job '$id' ($job)";

    # intentional meta-data leak: caller can manipulate the reference.

    @_
    ? $found->{ $_[0] }
    : $found
}

sub id
{
    my $job = shift;

    $$job
}

########################################################################
# object manglement

sub construct
{
    my $proto   = shift;
    my $class   = blessed $proto;

    bless \( my $a = '' ), $class || $proto
}

sub initialize
{
    my $job     = shift;

    my $id
    = do
    {
        if( 'HASH' eq reftype $_[0] )
        {
            # job_id data from listing.
            # install stats for the job_id.

            my $statz   = shift;

            %$statz
            or croak "Bogus initialize: empty job data ($job)";

            my $id   = $statz->{ JobId }
            or croak "Bogus job stats: false JobId.";

            $$job               = $id;
            $job_datz{ $id }    = $sanitize->( $statz );
        }
        else
        {
            # job_id scalar.
            # re-cycle any existing stats for the job_id.

            my $id  = shift;
            or croak "Bogus job_id: false value.";

            $$job               = $id;
            $job_datz{ $id }    ||= { JobId => $id };
        }
    };

    $job
}

sub new
{
    my $job = &construct;

    $job->EVERY::LAST::initialize( @_ );

    # after this point the job and its inside-out data
    # are immutable (via const) and the inside-out data
    # is sanitized to avoid JSON boolean objects, empty
    # elements.

    const $job
}

sub cleanup
{
    my $job = shift;

    delete $job_datz{ "$job" };

    return
}

DESTROY
{
    my $job = shift;

    $job->EVERY::cleanup;

    return
}

# keep require happy
1
__END__

=head2 Job Initialization

=over 4

=item Input Structure:

Result of JSON::XS:

    my $fieldz = 
    {
       'Action' => 'InventoryRetrieval'
       'ArchiveId' => undef
       'ArchiveSHA256TreeHash' => undef
       'ArchiveSizeInBytes' => undef
       'Completed' => JSON::PP::Boolean=SCALAR(0x22db350)
          -> 1
       'CompletionDate' => '2015-12-28T07:37:56.744Z'
       'CreationDate' => '2015-12-28T03:30:54.286Z'
       'InventoryRetrievalParameters' => HASH(0x3a0f858)
          'EndDate' => undef
          'Format' => 'JSON'
          'Limit' => undef
          'Marker' => undef
          'StartDate' => undef
       'InventorySizeInBytes' => 5235
       'JobDescription' => 'Inventory test-glacier-module'
       'JobId' => 'E_vPiqEmVgLDP7mUUxvT8gAiCb3ai81PVFwlzHuyq-kFa2pQCxAX1NTlRmKElCkk5JGj0Ydi9fYhhvM7BqTuI8w0kijW'
       'RetrievalByteRange' => undef
       'SHA256TreeHash' => undef
       'SNSTopic' => undef
       'StatusCode' => 'Succeeded'
       'StatusMessage' => 'Succeeded'
       'VaultARN' => 'arn:aws:glacier:us-west-2:481917615240:vaults/test-glacier-module'
   };

=item Object contents

    $$job   = $struct->{ JobId };

=item Object Data Contents

A few items are munged:

    Completed is reduced to an un-blessed scalar.
    Keys with values of undef are stripped from all levels.

=item Data Fields

    my $fieldz = 
    {
       'Action' => 'InventoryRetrieval'
       'Completed' => 1,
       'CompletionDate' => '2015-12-28T07:37:56.744Z'
       'CreationDate' => '2015-12-28T03:30:54.286Z'
       'InventoryRetrievalParameters' => HASH(0x3a0f858)
          'Format' => 'JSON'
       'InventorySizeInBytes' => 5235
       'JobDescription' => 'Inventory test-glacier-module'
       'JobId' => 'E_vPiqEmVgLDP7mUUxvT8gAiCb3ai81PVFwlzHuyq-kFa2pQCxAX1NTlRmKElCkk5JGj0Ydi9fYhhvM7BqTuI8w0kijW'
       'StatusCode' => 'Succeeded'
       'StatusMessage' => 'Succeeded'
       'VaultARN' => 'arn:aws:glacier:us-west-2:481917615240:vaults/test-glacier-module'
   };


