use base "installedtest";
use strict;
use testapi;
use lockapi;
use mmapi;
use networking;
use serial_terminal;

# Parallel child job: fetch a file from the support server job, reachable on
# the worker host (10.0.2.2) at the port forwarded by the server job, which
# is 180 followed by the server's worker instance number.

sub run {
    my ($self) = @_;

    select_root_console();
    mutex_wait('support_server_ready');
    my $port = '180' . get_job_autoinst_vars(get_parents()->[0])->{WORKER_INSTANCE};

    curl_via_netvm;
    assert_script_run("curl -f http://10.0.2.2:$port/ | grep support-server-ok");
}

1;

# vim: set sw=4 et:
