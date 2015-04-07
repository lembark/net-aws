use v5.20;
use autodie;
use FindBin::libs;

use Test::More;
use Test::Glacier::Vault;

my @opz
= qw
(
    verbose
    construct
    initialize
    new
    cleanup
    call_api

    write_archive
    write_inventory
    process_jobs
    download_avilable_job
    download_all_jobs
    last_inventory
    has_current_inventory
    has_pending_inventory
    download_current_inventory
    list_jobs
    filter_jobs
    job_status
    decode_inventory
    read_local
    write_local
    maximum_partition_size
    default_partition_size
    minimum_partition_size
    current_partition_size
    calculate_multipart_upload_partsize
    upload_multipart
    upload_singlepart
    upload_paths
);

for my $method ( @opz )
{
    can_ok $vault, $method;
}

done_testing;

0
__END__
