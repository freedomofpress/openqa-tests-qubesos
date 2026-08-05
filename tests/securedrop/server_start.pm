# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use base "installedtest";
use strict;
use testapi;
use networking;
use serial_terminal qw(select_root_console);
use securedrop qw(prep_dev_env);

sub run {
    my ($self) = @_;

    $self->select_root_console;

    prep_dev_env;

    # WORKAROUND: qubes qrexec does not support "> /dev/stdout" (it's a socket)
    assert_script_run('qvm-run -p sd-dev "sed -i \'s| > \$out| >/dev/null|g\' securedrop/securedrop/bin/dev-shell"');

    # Run server in background (redirections needed to keep it alive according to openqa docs)
    $self->{sd_server_pid} = background_script_run("script -e -c \"qvm-run -p sd-dev -- bash -c 'make -C securedrop dev-tor'; echo local-sd-server-finished-\$?-\" /dev/$testapi::serialdev </dev/null");

    sleep(60); # wait some time for the server to start

    # NOTE: Very slow server build. We may want to build it elsewhere.
    my $server_ready = testapi::wait_serial("=> Source Interface <=", no_regex => 1, timeout=>1600);
    diag "Server startup timed out" unless $server_ready;

    sleep(60); # wait for onion address to propagate

    # Politely shutdown server at the end of test
    script_run("kill -2 " . $self->{sd_server_pid});  # Shut down server with "Ctrl-C"
    my $res = testapi::wait_serial(qr/local-sd-server-finished-\d+-/, timeout => 15);
    diag "script could not be shut down" unless $res;
    die "script could not be shut down" unless $res;

    # Update onion address
    # x11_start_program('xterm');
    # send_key('alt-f10');  # maximize xterm to ease troubleshooting
    # assert_script_run('set -o pipefail'); # Ensure pipes fail\
    # assert_script_run('export JOURNALIST_ONION=$(qvm-run -p sd-dev "sudo cat /var/lib/docker/volumes/sd-onion-services/_data/journalist/hostname")');
    # assert_script_run('export JOURNALIST_KEY=$(qvm-run -p sd-dev "sudo cat /var/lib/docker/volumes/sd-onion-services/_data/journalist/authorized_clients/client.auth"| cut -d: -f3)');
    # assert_script_run('sudo mkdir -p /usr/share/securedrop-workstation-dom0-config/');
    # assert_script_run('echo {\"submission_key_fpr\": \"65A1B5FF195B56353CC63DFFCC40EF1228271441\", \"hidserv\": {\"hostname\": \"$JOURNALIST_ONION\", \"key\": \"$JOURNALIST_KEY\"}, \"environment\": \"prod\", \"vmsizes\": {\"sd_app\": 10, \"sd_log\": 5}} | sudo tee /usr/share/securedrop-workstation-dom0-config/config.json');
    # type_string("cd /usr/bin && python3 -i sdw-admin --validate\n");
    # type_string("copy_config()\n");
    # sleep(1);
    # send_key('ctrl-d');
    # assert_script_run("sudo qubesctl --targets dom0 state.highstate || true", timeout => 1000);  # Reapply due to secrets change
}
1;
