########################################################################
# housekeeping
########################################################################

package Net::AWS::Glacier;
use v5.20;
use autodie;

use Carp    qw( carp croak  );
use Symbol  qw( qualify     );

use Net::AWS::Glacier::API;
use Net::AWS::Glacier::Vault;

########################################################################
# package variables
########################################################################

our $VERSION = '0.01';

########################################################################
# methods 
########################################################################

sub glacier
{
    my ( $proto, $type ) = splice @_, 0, 2;

    my $class   = qualify $type;

    my $handler = $class->can( 'new' )
    or croak "Botched new: '$type' lacks 'new' ($class)";

    $proto->$handler( @_ )
}

# keep require happy 
1
__END__

=head1 NAME

Net::AWS::Glacier - Documentation for Net::AWS::Glacier::* modules.

=head1 SYNOPSIS

    # high-level work is done with vaults, lower-level calls
    # mimic the API.

    # everything from here down croaks on errors with the 
    # CARP_NOT usuallly set to the NET::AWS::Glacier call
    # stack so that the origin of an error is discernable.

    # derived classes may find it convienent to use the 
    # re-dispatching constructor "glacier" which takes the
    # object type and standard colleciton of arguments.

    my $vault   = Some::Class->glacier( Vault => ... );
    my $api     = Some::Class->glacier( API   => ... );

    # Vault objects have a pre-assigned vault name and will 
    # inherit their region, secret, and key from a parent
    # vault object at initializtion time.

    # if you only deal with one vault, by all means: construct
    # it fully populated.

    my $vault = Net::AWS::Glacier::Vault->new
    (
        'prod_backup', 
        region  => 'us-east-1',
        secret  => 'very, very secret',
        key     => '0xkey to happyness'
    );

    my $api   = Net::AWS::Glacier::API->new
    (
        'vault name', 
        'us-east-1',
        'very, very secret',
        '0xkey to happyness'
    );
    
    # if you want to iterate multiple vaults in a region it will
    # probably be easier to create a prototype.

    my $proto = Net::AWS::Glacier::Vault->new
    (
        '', 'us-west-1', 'secret', '0xkey',
    );

    for my $name ( qw( prod_backup test_data ) )
    {
        $proto->new( $name )->download_current_inventory;
    }

    # cron job to pull down any completed inventory/download jobs.
    # download includes check for exisiting path to avoid duplicates.

    for my $name ( @vault_names )
    {
        my $vault   = $proto->new( $name );

        if( $vault->has_complete_jobs  )
        {
            $vault->download_completed_jobs
            (
                dest    => "/download/glacier/$name"
            );
        }
        elsif( $vault->has_pending_jobs )
        {
            # or list them with $vault->list_pending_jobs.

            say "Nothing to download, all jobs pending.";
        }
        else
        {
            say "Vault has no jobs at all.";
        }
    }

    # package or object, same results.
    # with an argument assigns boolean, without returns current.

    my $curr    = Net::AWS::Glacier::Vault->verbose;
    my $true    = Net::AWS::Glacier::Vault->verbose( 1 );
    my $false   = Net::AWS::Glacier::Vault->verbose( '' );

    my $curr    = Net::AWS::Glacier::API->verbose;
    my $true    = Net::AWS::Glacier::API->verbose( 1 );
    my $false   = Net::AWS::Glacier::API->verbose( '' );


=head1 DESCRIPTION

This is user documentation for Net::AWS::Glacier::Vault
and Net::AWS::Glacier::API. The "Vault" class supports operations on
single vaults (e.g., "acquire the most recent inventory", "download
the contents of all completed jobs"); the API class mimics AWS'
low-level where that is useful.

Incuded here are basic usage examples of the Vault class and a 
description of the data structures returned from both Vault and API
methods. Details of using each class, including its methods and 
sanity checks, are in the respective modules.

This module provides a single constructor with an added type argument:

    my $vault   = Net::AWS::Glacier->new( Vault => ... );
    my $api     = Net::AWS::Glacier->new( API   => ... );

=head2 AWS Request / Response Structures

These are all taken from 

    http://docs.aws.amazon.com/amazonglacier/latest/dev/amazon-glacier-api.html

=head3 Vault Requests

=over 4

=item Describe Vault

Calling:

    $vault->describe;
    $api->describe_vault( $vault_name );

Returns a structure like:

    {
      "CreationDate" : String,
      "LastInventoryDate" : String,
      "NumberOfArchives" : Number,
      "SizeInBytes" : Number,
      "VaultARN" : String,
      "VaultName" : String
    }

=item

=back

=head2 Job Listing

Extended attributes are described at:

    http://docs.aws.amazon.com/amazonglacier/latest/dev/api-jobs-get.html

Of these "completed" and "statuscode" (e.g., success/fail) are available
for job queries.

Note: The "Marker" described in AWS doc's is consumed in generating the
list, leaving the caller with a single (describe_job) or array[ref]
(list_*_jobs) of strucures:

    {     
      "Action": String,
      "ArchiveId": String,
      "ArchiveSizeInBytes": Number,
      "ArchiveSHA256TreeHash": String,
      "Completed": Boolean,
      "CompletionDate": String,
      "CreationDate": String,
      "InventorySizeInBytes": String,
      "JobDescription": String,
      "JobId": String,
      "RetrievalByteRange": String,
      "SHA256TreeHash": String,
      "SNSTopic": String,
      "StatusCode": String,
      "StatusMessage": String,
      "VaultARN": String,
      "InventoryRetrievalParameters": { 
          "Format": String,
          "StartDate": String,
          "EndDate": String,
          "Limit": String,
          "Marker": String
      }     
    },

Notes:

=over 4

=item Action 

Either "ArchiveRetrieval" or "InventoryRetrieval".

=item Completed

Is an object returned by JSON::XS

=item EndDate

The end of the date range in UTC for vault inventory retrieval that 
includes archives created before this date. 

=back

=head1 TODO

=over4

=item Support AWS/AIM 

This is the Access Management component of AWS and can be helpful in 
restricting access to portions of the Glacier space. This requires 
several extentions to the Vault handlers, but could be done if someone
actually needs it.

Documentation:

<http://docs.aws.amazon.com/amazonglacier/latest/dev/using-iam-with-amazon-glacier.html>

=back

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
