########################################################################
# housekeeping
########################################################################
package Net::AWS::Glacier::Vault::LocalInventory;
use v5.20;
use autodie;

use Data::Dumper;
use File::Spec::Functions   qw( catfile );

use Carp            qw( carp croak  );
use JSON::XS        qw( decode_json );
use XML::Simple     qw( xml_in      );

use Exporter::Proxy
qw
(
    decode_inventory
    read_local
    write_local
);

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';
our @CARP_NOT   = ( __PACKAGE__ );

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

my $read_path
= sub
{
    my $path    = shift;

    open my $fh, '<', $path;

    local $/;

    readline $fh
};

########################################################################
# methods
########################################################################

########################################################################
# local files

sub decode_inventory
{
    my $vault   = shift;
    my $path    = shift;

    my $content
    = @_
    ? shift
    : $read_path->( $path )
    ;

    0 < index $path, '.json.'
    ? decode_json $content
    : 0 < index $path, '.xml.'
    ? xml_in      $content
    : 0 < index $path, '.dump.'
    ? eval "$content"
    : croak "Unknown file type: '$path'"
    ;
}

sub read_local
{
    my $vault   = shift;
    my $path    
    = @_
    ? shift 
    : do
    {
        my $glob    = "./inventory_$vault*gz";

        my @found   = glob $glob
        or croak "No available inventory ($glob)";

        $found[-1]
    };

    my $content = $vault->decode_inventory( $path );

    ( $path => $content )
}

sub write_local
{
    local @CARP_NOT = ( __PACKAGE__ );

    my $vault   = shift;
    my $job_id  = shift or croak 'false job_id';
    my $dest    = shift || './';

#    my $path    = catfile $dest, $base;
#
#    -s $path
#    and die "Existing: '$path'\n";
#
#    say "Writing inventory: '$path'"
#    if $verbose;
#
#    my ( $expect, $format )
#    = do
#    {
#        # this croaks on a bogus job_id.
#
#        my $statz   = $glacier->describe_job( $vault, $job_id );
#
#        $statz->{ Completed }
#        or die "Incomplete: '$job_id'\n";
#
#        (
#            $statz->{ InventorySizeInBytes },
#            lc $statz->{ InventoryRetrievalParameters }{ Format }
#        )
#    };
#
#    my $content = $glacier->get_job_output( $vault, $job_id );
#
#    eval
#    {
#        my $found   = length $content;
#
#        $found != $expect
#        and die "Mis-sized content: $found ($expect)\n";
#
#        open my $fh, '|-', "gzip -9 > $path";
#        print $fh $content;
#        close $fh
#    }
#    or do
#    {
#        -e $path && unlink $path;
#
#        die "Failed write: $@\n"
#    };
#
#    $path

}


# keep require happy
1
__END__

