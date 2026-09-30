use base "installedtest";
use strict;
use testapi;
use lockapi;
use networking;
use serial_terminal;

# Parallel child job: fetch a file from the support server job, reachable on
# the worker host (10.0.2.2) at the port forwarded by the server job.

sub run {
    my ($self) = @_;
    my $port = get_var('SECUREDROP_SUPPORT_SERVER_PORT', 18080);

    select_root_console();
    mutex_wait('support_server_ready');

    curl_via_netvm;
    assert_script_run("curl -f http://10.0.2.2:$port/ | grep support-server-ok");
}

1;

# vim: set sw=4 et:
