use base "installedtest";
use strict;
use testapi;
use lockapi;
use mmapi;
use networking;
use serial_terminal;

# Parallel parent job: serve a file over HTTP from sys-net for the child jobs.
# The port is exposed on the worker host via NICTYPE_USER_OPTIONS=hostfwd=...

sub run {
    my ($self) = @_;

    select_root_console();
    assert_script_run('qvm-run --no-gui -p -u root sys-net "mkdir -p /tmp/www && echo support-server-ok > /tmp/www/index.html && nft add rule ip qubes custom-input tcp dport 8000 accept" </dev/null');
    background_script_run('qvm-run --no-gui -p -u root sys-net "cd /tmp/www && python3 -m http.server 8000" </dev/null >/dev/null 2>&1');

    curl_via_netvm;
    assert_script_run('curl -f --retry 5 --retry-connrefused http://localhost:8000/ | grep support-server-ok');

    mutex_create('support_server_ready');
    wait_for_children;
}

sub test_flags {
    return { fatal => 1 };
}

1;

# vim: set sw=4 et:
