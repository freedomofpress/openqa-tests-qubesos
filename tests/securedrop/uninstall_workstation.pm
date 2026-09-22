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

my $uninstall_log_path = "/tmp/sdw-admin-uninstall.log";

sub run {
    my ($self) = @_;

    $self->select_root_console;

    # Enable networking for log uploading to work
    enable_dom0_network_netvm() unless $self->{network_up};

    assert_script_run('set -o pipefail');  # Ensure pipes fail

    # '--force' skips the interactive confirmation prompt.
    # assert_script_run fails the test unless sdw-admin exits with code 0.
    assert_script_run(
        "su user -c 'sdw-admin --uninstall --force' 2>&1 | tee $uninstall_log_path",
        timeout => 3000);
}

sub post_run_hook {
    my $self = shift;

    select_root_console();

    upload_logs($uninstall_log_path, failok => 1);

    # NOTE: Run at the end because some may fail and just abort execution
    $self->SUPER::post_run_hook();
}

sub post_fail_hook {
    my $self = shift;

    select_root_console();

    script_run("cat /var/log/salt/minion");

    upload_logs($uninstall_log_path, failok => 1);

    # NOTE: Run at the end because some may fail and just abort execution
    $self->SUPER::post_fail_hook();
};

1;

# vim: set sw=4 et:
