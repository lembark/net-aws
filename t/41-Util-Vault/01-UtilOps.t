use v5.20;
use autodie;
use FindBin::libs;

use Test::More;
use Test::GlacierUtil;

my @opz
= qw
(
    initialize
    new 
    verbose
    write_archive
    write_inventory
    download_completed_job
    download_all_jobs
    upload_paths
);

for my $method ( @opz )
{
    can_ok $::glacier, $method;
}

done_testing;

0
__END__
