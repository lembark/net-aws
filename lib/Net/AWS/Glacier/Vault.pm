########################################################################
# housekeeping
########################################################################

package Net::AWS::Glacier::Vault;
use v5.20;
use autodie;
use overload 
    q{"}    => sub { my $vault = shift; $$vault }
    q{bool} => sub { my $vault = shift; !! $$vault }
;

use Carp;
use NEXT;

use Scalar::Util    qw( blessed refaddr         );
use Symbol          qw( qualify_to_ref          );

use Net::AWS::Glacier::API;
use Net::AWS::Glacier::Const;

# break methods up into usable chunks.

use Net::AWS::Glacier::Vault::Download;
use Net::AWS::Glacier::Vault::Inventory;
use Net::AWS::Glacier::Vault::Jobs;
use Net::AWS::Glacier::Vault::Upload.pm;

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
$VERSION        = eval $VERSION;

our @CARP_NOT   = ();

my $verbose         = '';
my @arg_fieldz      = qw( api region key secret );
my %vault_argz      = ();

sub MiB() { 2 ** 20 );

########################################################################
# this module contains code for:
#   manufactured methods.
#   object construct/destroy.
#   call low-level API
# anything else is in one of the Net::AWS::Glacier::Vault::* modules.
########################################################################

########################################################################
# manufactured methods

while( my ($i, $name ) = each @arg_fieldz )
{
    # setting these is mainly useful for the factory object.

    *{ qualify_to_ref $name }
    = sub
    {
        my $vault   = shift;
        my $argz    = $vault_argz{ refaddr $vault }
        or croak "Bogus $name: uninitialized object '$vault'";

        @_
        ? ( $argz->[ $i ] = shift )
        :   $argz->[ $i ]
    };
}

# The names look like:
#
# {has|list}_{pending|completed}_{download|inventory}_jobs.
#
# e.g., 
#
#   "has_completed_inventory_jobs"
#   "list_pending_download_jobs".

for
(
    [ has   => 1 ],
    [ list  => 0 ],
)
{
    my ( $output, $onepass ) = @$_;

    for
    (
        [ qw( pending   false   ) ],
        [ qw( completed true    ) ],
    )
    {
        my ( $status, $complete ) = @_;

        for
        (
            [ qw( inventory Inventory   ) ],
            [ qw( download  Download    ) ],
        )
        {
$DB::single = 1;

            state $filterz  = {};

            my ( $type, $action ) = @$_;

            my $name    = join '_' => $output, $status, $type, 'jobs';

            my $filter  = $filterz{ $action }
            ||= sub
            {
                my $job_statz   = shift;

                $action eq $job_statz->{ JobType } 
            };

            my @argz = 
            (
                complete    => $complete,
                onepass     => $onepass,
                filter      => $filter,
            );

            *{ qualify_to_ref $name }
            = sub
            {
                # difference betwene "has_*" and "list_*" is that 
                # former use $onepass to get a single job & quit.

                local @CARP_NOT = ( __PACKAGE__ );

                my $vault   = shift;
                my @found   = $vault->call_api( filter_jobs => @argz );

                $onepass 
                and return !! @found;

                wantarray
                ?  @found
                : \@found
            };
        }
    }
}

for
(
    [ qw( describe  describe_vault  ) ]
)
{
    # downside to AUTOLOAD is that the names with "vault" are
    # repetative with objects named "$vault".

    my ( $install, $dispatch ) = splice @_, 0, 2;

    *{ qualify_to_ref $install }
    = sub
    {
        my $vault   = shift;

        $vault->call_api( $dispatch => @_ )
    };
}

########################################################################
# manage general metadata

sub verbose
{
    shift;  # ignore the invocant

    @_
    ? ( $verbose = !! shift )
    : $verbose
}

########################################################################
# object manglement

sub construct
{
    my $proto   = shift;
    my $class   = blessed $proto;

    my $vault   = bless \( my $a = '' ), $class || $proto;

    $vault_argz{ refaddr $vault } 
    = $class
    ? $vault_argz{ refaddr $proto }
    : {}
    ;

    $vault
}

sub initialize
{
    my $vault   = shift;
    $$vault     = shift;
    
    # note that the name might be false for a factory object.

    if( @_ )
    {
        my %initz   = @_;

        for( @arg_fieldz )
        {
            my $value   = $initz{ $_ } // next;

            $vault->$_( $value );
        }
    }

    $vault
}

sub new
{
    my $vault   = &construct;

    $vault->EVERY::LAST::intialize( @_ );

    # after this point the vault is immutable.
    # not so its inside-out data, but accessing a new vault
    # requires creating a new object.

    const $vault
}

sub cleanup
{
    my $vault = shift;

    delete $vault_argz{ refaddr $vault }

    return
}

DESTROY
{
    my $vault = shift;

    $vault->EVERY::cleanup;

    return
}

########################################################################
# interface to low-level calls.
# Vault::* methods all pass through here eventually. 
########################################################################

sub call_api
{
    my $vault   = shift;
    my $name    = $$vault
    || croak "Botched call_api: vault must have a name";

    my $op  = shift
    or croak "Bogus call_api: missing operation ($name)";

    my $argz    = $vault_argz{ refaddr $vault }
    or croak "Un-initialized vault: '$vault'";

    my $api     = $argz->[0]
    ||= do
    {
        state $proto    = 'Net::AWS::Glacier::API';

        $proto->new( @{ $argz }[ 1 .. $#arg_fieldz ]
    };

    $api->glacier_api( $op, $name, @_ )
}

# keep require happy 
1
__END__

=head1 NAME

Net::AWS::Glacier::Util - higher-level utilities using 
AWS::Glacier::API

=head1 SYNOPSIS

ASIDE: This code is still alpha, so is this documentation. Until 
the code is a bit more stable, please reference the method names
for specific of how they are used.

    # Note: these all croak on errors.
    # package or object, same results.

    my $vebose  = Net::AWS::Glacier::Util->verbose;
    my $vebose  = Net::AWS::Glacier::Util->verbose( 1 );
    my $vebose  = Net::AWS::Glacier::Util->verbose( '' );

    # vault name is 'user-data'.
    # object is an immutable refernce to 'user-data'.

    my $vault = Net::AWS::Glacier::Vault->new
    (
        'user-data',
        region  => $region,
        key     => $user_key,
        secret  => $user_secret,
    );

    # vaults inherit from an object used to dispatch new.
    # this simplifies managing multiple vaults.
    #
    # name for factory is optional;
    # name for specific vaults is required with the region, key,
    # secret inherited if they are available.

    my $factory = Net::AWS::Glacier::Vault->new
    (
        ''
        region  => $region,
        key     => $user_key,
        secret  => $user_secret,
    );

    for my $name ( @vault_namz )
    {
        my $vault   = $factory->new( $name );
        $vault->...
    }

    # or to, say, download all of the completed jobs for all of
    # the vaults on a list use. 

    $factory->new( $_ )->download_all_jobs
    for @vault_namz;

    # push a list of files into glacier. default description is 
    # the path. returns a hash[ref] of path => archive_id.
    # false explicit descriptions are set to the path (i.e., this
    # won't let you upload with a false description).
    #
    # my %path2arch = ... works also.

    my $path2arch = $vault->upload_paths
    (
        $path,              # use path for description
        [ $path, $desc ],   # explicit description
        ...
    );

    # download and record any completed jobs,
    # loop w/ 1-hour wait while any pending jobs.

    my @local   = $vault->download_all_jobs
    (
        $dest_dir       # optional, defaults to '.'
    );

    # iterate write_archive for all completed jobs.
    # returns local paths.

    my @local   = $vault->download_completed_job
    (
        $vault_name,    # required
        $dest_dir       # optional, defaults to '.'
    );

    # write the completed archive job's output to a local path.
    # basename defaults to archive_id, dir defaults to '.'.
    # returns false if content not written.

    my $path    = $vault->write_archive
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

    my $path    = $vault->write_inventory
    (
        $vault_name,
        $completed_job_id,
        $directory
    );

    # return counts of completed or pending incomplete jobs.

    $vault->has_completedjobs( $vault_name );
    $vault->has_pending_jobs( $vault_name );

    # return array[ref] of completed or pending incomplete jobs.

    $vault->list_completed_jobs( $vault_name );
    $vault->list_pending_jobs( $vault_name );

=head1 DESCRIPTION

None of these are necessary for accessing the AWS::Glacier API.

These provide some higher-level looping utilities for moving data in
and out of AWS' Glacier service.

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
