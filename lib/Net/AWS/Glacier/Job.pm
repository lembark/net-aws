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

use List::Util      qw( first           );
use Scalar::Util    qw( blessed refaddr );
use Symbol          qw( qualify_to_ref  );

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

    # intentional meta-data leak: 

    @_
    ? $found->{ $_[0] }
    : $found
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
    my $inputz  = shift
    or croak "Bogus initialize: false input hash ($job)";

    my $id      = $inputz->{ JobId }
    or croak "Bogus fields: missing 'JobId'";

    $$job       = $id;

    if( my $found = $job_datz{ $id } )
    {
        # i.e., preserve any prior state stashed in the 
        # content. callers get to determine if the stuff
        # is stale for themselves.

        $found->[0] = const $inputz
    }
    else
    {
        $job_datz{ $id } = [ const $sanitize->( $inputz ), {} ]
    }

    $job
}

sub new
{
    my $job = &construct;

    $job->EVERY::LAST::initialize( @_ );

    # after this point the job is immutable.
    # not so its inside-out data.

    const $job
}

sub cleanup
{
    my $job = shift;

    delete $job_datz{ refaddr $job };

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
       'JobDescription' => 'Inventory test-glacier-archives'
       'JobId' => 'E_vPiqEmVgLDP7mUUxvT8gAiCb3ai81PVFwlzHuyq-kFa2pQCxAX1NTlRmKElCkk5JGj0Ydi9fYhhvM7BqTuI8w0kijW'
       'RetrievalByteRange' => undef
       'SHA256TreeHash' => undef
       'SNSTopic' => undef
       'StatusCode' => 'Succeeded'
       'StatusMessage' => 'Succeeded'
       'VaultARN' => 'arn:aws:glacier:us-west-2:481917615240:vaults/test-glacier-archives'
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
       'JobDescription' => 'Inventory test-glacier-archives'
       'JobId' => 'E_vPiqEmVgLDP7mUUxvT8gAiCb3ai81PVFwlzHuyq-kFa2pQCxAX1NTlRmKElCkk5JGj0Ydi9fYhhvM7BqTuI8w0kijW'
       'StatusCode' => 'Succeeded'
       'StatusMessage' => 'Succeeded'
       'VaultARN' => 'arn:aws:glacier:us-west-2:481917615240:vaults/test-glacier-archives'
   };


