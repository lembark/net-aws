########################################################################
# housekeeping
########################################################################

package Net::AWS::Glacier::Vault::LocalInventory;
use v5.20;

use Carp    qw( carp croak );

########################################################################
# package varaibles
########################################################################

our $VERSION    = '0.01';
eval $VERSION;

use Exporter::Proxy
qw
(
    read_inventory
    has_current_inventory
    has_pending_inventory
    download_current_inventory
);

########################################################################
# methods
########################################################################

# keep require happy
1
__END__

=head1 NAME

Net::AWS::Glacier::Vault::LocalInventory -- Parse & filter local 
inventory files.

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
