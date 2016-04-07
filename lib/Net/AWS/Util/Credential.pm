########################################################################
# housekeeping
########################################################################
package Net::AWS::Util::Credential;

use v5.22;
use autodie;
use FindBin::libs   qw( base=etc export scalar );

use YAML::XS qw( Load );

use Exporter::Proxy qw( read_credential );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.01';

########################################################################
# utility subs
########################################################################

sub read_credential
{
    my $default = $ENV{ NET_AWS_CONFIG } || "$etc/net-aws.config.yaml";

    my $name    = shift
    or die 'Bogus read_credential: false user name';
    my $class   = shift || caller;
    my $path    = shift || $default;

    -e $path  or die "Non-existant: '$path\n";
    -r _      or die "Non-readable: '$path\n";
    -s _      or die "Empty file: '$path\n";

    my $configz
    = eval
    {
        open my $fh, '<', $path;  

        local $/;

        my $yaml  = readline $fh;

        Load $yaml
    }
    or die "Failed read config: '$path', $@";

    my $name2credz  = $configz->{ $class }
    or die "Unknown class: '$class' ($path)\n";

    my $credz       = $name2credz->{ $name }
    or die "Unknown user: '$name' ('$class', '$path')\n";

    wantarray
    ?   @$credz
    : [ @$credz ]
}

# keep require happy
1
__END__
