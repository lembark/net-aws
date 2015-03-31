use v5.20;
use autodie;
use FindBin::libs;

use Test::More;
use Test::GlacierAPI;

my @opz
= qw
(
    create_vault
    delete_vault
    describe_vault
    get_vault_notifications
    delete_vault_notifications
    delete_vault_notifications
    list_vaults
    set_vault_notifications
);

for my $method ( @opz )
{
    can_ok $api, $method;
}

done_testing;

0
__END__
