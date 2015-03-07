########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier;
use v5.20;
use autodie;

use Scalar::Util    qw( blessed );
use Symbol          qw( qualify );

our $VERSION='1.00';
eval $VERSION;

use Net::AWS::Glacier::Vault;
use Net::AWS::Glacier::API;

sub glacier
{
    my ( $proto, $type ) = splice @_, 0, 2;

    my $class   = qualify $type;

    my $const   = $class->can( 'new' )
    or croak "Botched new: '$type' lacks 'new' ($class)";

    $proto->$const( @_ )
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

This is the documentation for the higher-level Net::AWS::Glacier::Vault
and lower-level Net::AWS::Glacier::API modules. The "Vault" class
supports operations on single vaults (e.g., "acquire the most recent
inventory", "download the contents of all completed jobs"); the API
class mimics AWS' low-level where that is useful.

Incuded here are basic usage examples of the Vault class and a 
description of the data structures returned from both Vault and API
methods. Details of using each class, including its methods and 
sanity checks, are in the respective modules.

This module provides a single constructor of the form:

    my $vault   = Net::AWS::Glacier->new( Vault => ... );
    my $api     = Net::AWS::Glacier->new( API   => ... );

which can simplify life for derived classes.



=head2 AWS Request / Response Structures

These are all taken from 

    http://docs.aws.amazon.com/amazonglacier/latest/dev/amazon-glacier-api.html

=head3 Vault Requests

=over 4

=item Describe Vault

This uses only the standard request headers, returning a strucure of:

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

########################################################################
# notes: these need to get removed, eventually.
########################################################################

    my $path2arch = $glacier->upload_paths
    (
        $path,              # use path for description
        [ $path, $desc ],   # explicit description
        ...
    );

    my $path2arch = $glacier->upload_paths
    (
        {
            path => '',     # use path for description
            path => desc,   # use explicit description
            ...
        }
    );

    # download and record any completed jobs,
    # loop w/ 1-hour wait while any pending jobs.

    my @local   = $glacier->download_all_jobs
    (
        $vault_name,    # required
        $dest_dir       # optional, defaults to '.'
    );

    # iterate write_archive for all completed jobs.
    # returns local paths.

    my @local   = $glacier->download_completed_job
    (
        $vault_name,    # required
        $dest_dir       # optional, defaults to '.'
    );

    # write the completed archive job's output to a local path.
    # basename defaults to archive_id, dir defaults to '.'.
    # returns false if content not written.

    my $path    = $glacier->write_archive
    (
        $vault_name,
        $completed_job_id,
        $path
    );

    # write completed inventory job to a local path.
    # basename is one of
    #   "$vault_id-$inventory_date.json.gz"
    #   "$vault_id-$inventory_date.xml.gz"
    #

    my $path    = $glacier->write_inventory
    (
        $vault_name,
        $completed_job_id,
        $directory
    );

    # return counts of completed or pending incomplete jobs.

    $glacier->has_completedjobs( $vault_name );
    $glacier->has_pending_jobs( $vault_name );

    # return array[ref] of completed or pending incomplete jobs.

    $glacier->list_completed_jobs( $vault_name );
    $glacier->list_pending_jobs( $vault_name );

=head1 DESCRIPTION

None of these are necessary for accessing the AWS::Glacier API.

These provide some higher-level looping utilities for moving data in
and out of AWS' Glacier service.

Either of the modules can be used alone, the only utility in this
module is pulling them both in at once and providing the documentation.

=head2 Arguments

User key & secret, vault name, description are passed to Glacier::API.

The key & secret are provided by Amazon, Vault name is UTF8, 
description is printable ASCII with a length < 1025 chars. 

See Glacier::API for detailed information.

=head2 Constructor & Class Methods

=over 4

=item new

Inherited from Net::AWS::Glacier::API. This takes a facility,
user key, and user secret, returning the object.

=item verbose

    # new value is stored via "!! $value" to avoid lifecycle
    # issues with objects.

    my $curr_value  = $prototype->verbose;
    my $curr_value  = $prototype->verbose( $new_value );

=back

=head2 Pending & Completed Jobs

These return the list if complete/incomplete jobs for a vault
or a boolean (i.e., scalar @jobs_found).

These all take a vault name and maximum number of jobs to download.
The maximum job limit is 1000.

    # the first call returns an unlimited list,
    # the second call returns at most 10 jobs.

    $glacier->list_completed_jobs( $vault_name      );
    $glacier->list_completed_jobs( $vault_name, 10  );

=over 4

=item list_completed_jobs list_pending_jobs

Returns an array[ref] of Job structs.
See Net::AWS::Glacier::API under "list_jobs" for details of the
job structure.

=item has_completedjobs has_pending_jobs

These call list_*_jobs with a limit of 1, returning true or false if
any jobs are found.

=back

=head2 Download

Both write_inventory & write_archive avoid overwriting exising files.
download_completed_job tracks job_id values and will avoid acquiring 
content multiple times within the same session (e.g., if called
repeatedly from download_all_jobs).

These all take a vault name simplify calling them
from external subroutines.

=item write_inventory( $vault_name, $job_id, $local_directory );

Download & write gzip-ed output (these can get large) with a 
basename of the vault name & inventory generation timesetamp.
The optional local directory defaults to the current working
directory via './'.

=item write_archive( $vault_name, $job_id, $local_path );

Download and write the archive output as-is, the local path defaults
to the archive_id.

=item download_completed_job( $vault_name, $local_directory );

Iterates completed jobs through write_archive or write_inventory,
returning the list of downloaded paths.

=item download_all_jobs( $vault_name, $local_directory );

This has an outer loop that iterates while there are any 
incomplete jobs pending for the vault, downloading any completed
jobs each time. Each iteration includes a 1-hour sleep.
This returns the accumulated paths from all calls to download_completed.

I<Note that this call can easily take hours to complete given
the 5-hour nominal turnaround for retrieving archive content.>

=head2 Upload


TODO


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
