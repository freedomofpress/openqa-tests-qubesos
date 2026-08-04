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

sub run {
    my ($self) = @_;
    $self->select_gui_console;

    if (check_var('SECUREDROP_INSTALL', '1')) {
        # Updater tests must be ran after a manadatory restart post-instllation.
        # However, if this is ran in the same job as SECUREDROP_INSTALL, then
        # it won't be shut down by the time this runs, thus a restart is needed.
        x11_start_program('xterm');
        script_run('sudo reboot', timeout => 0);
        $self->handle_system_startup;
    }

    select_root_console;

    # Install dependencies (assuming minimal sd-dev template)
    assert_script_run("qvm-run -p sd-dev 'sudo apt-get install -y rpm gpg git createrepo-c'", timeout=> 120);

    # Enable sd-dev to act as an update VM
    assert_script_run("qvm-run -p sd-dev 'sudo apt-get install -y qubes-core-agent-dom0-updates'", timeout=> 120);

    # TODO: switch environment to the one set during installation
    $self->{rpm_server_pid} = background_script_run("sudo -u user script -e -c \"bash -c 'cd securedrop-workstation && ./scripts/local-rpm-server.sh'; echo local-rpm-server-finished-\$?- >/dev/$testapi::serialdev\" securedrop-yum-server.log </dev/null");

    $self->select_gui_console;

    # Go through launcher
    assert_and_click("securedrop-launcher-intro");
    assert_screen("securedrop-launcher-updates-in-progress", timeout => 10);

    # 100% has of progress has been hit (note this is also the case when failed)
    assert_screen("securedrop-launcher-updates-finished", timeout => 1500);
    die "Updates failed" if check_screen("securedrop-launcher-updates-failed");

    assert_screen("securedrop-launcher-updates-complete");
    if (check_screen("securedrop-launcher-updates-complete-reboot")) {
        assert_and_click("securedrop-launcher-updates-complete-reboot");
        $self->handle_system_startup;
    } else {
        assert_and_click("securedrop-launcher-updates-complete-continue");
    }

    # Ensure Inbox autostarts
    assert_screen('securedrop-inbox-login-screen', timeout => 120);

    select_root_console;

    # Cleanly shut down yum server (otherwise updatevm not set back to orignal)
    script_run("kill -2 " . $self->{sd_server_pid});  # Shut down server with "Ctrl-C"
    my $res = testapi::wait_serial(qr/local-sd-server-finished-\d+-/, timeout => 15);
    diag "script could not be shut down" unless $res;

    # TODO sanity-checking updater logs
}

sub post_run_hook {
    my $self = shift;
    select_root_console();

    # Upload packages after successful run
    $self->upload_packages_versions(failok=>1);

    # NOTE: Run at the end because some may fail and just abort execution
    $self->SUPER::post_run_hook();
}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook();
    upload_logs('/home/user/.securedrop_updater/logs/updater.log', failok => 1);
    upload_logs('/home/user/.securedrop_updater/logs/updater-detail.log', failok => 1);

    $self->upload_packages_versions(failok=>1);

};

1;

# vim: set sw=4 et:
