use base "basetest";
use strict;
use testapi;
use lockapi;
use mmapi;
use serial_terminal;

# Parallel parent job on an Ubuntu focal cloud image: serve a file over HTTP
# for the child jobs. The image is configured on first boot by cloud-init,
# from support_server_focal/ (see QEMU_APPEND in the job settings).

sub run {
    my ($self) = @_;

    # root password is set by cloud-init, wait for it before logging in
    wait_serial('support-server-cloud-init-done', 600) or die "cloud-init did not finish";
    select_root_console();

    assert_script_run('mkdir -p /tmp/www && echo support-server-ok > /tmp/www/index.html');
    background_script_run('cd /tmp/www && python3 -m http.server 8000 >/dev/null 2>&1');
    assert_script_run('curl -f --retry 5 --retry-connrefused http://localhost:8000/ | grep support-server-ok');

    mutex_create('support_server_ready');
    wait_for_children;
}

sub test_flags {
    return { fatal => 1 };
}

1;

# vim: set sw=4 et:
