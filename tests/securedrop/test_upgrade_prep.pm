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


sub run {
    my ($self) = @_;

    $self->select_root_console;

    # Enable networking for log uploading to work
    enable_dom0_network_netvm() unless $self->{network_up};

    # Fetch latest version and run upgrade prep script
    assert_script_run("curl -O https://raw.githubusercontent.com/freedomofpress/securedrop-workstation/refs/heads/release/1.6.2/files/sdw-upgrade.py");
    assert_script_run("mv sdw-upgrade.py /tmp/sdw-upgrade.py && chmod 777 /tmp/sdw-upgrade.py");

    assert_script_run("yes | sudo -u user /tmp/sdw-upgrade.py --debug 2>&1 | tee /tmp/sdw-upgrade.log");

    # Set up some default qubes to see the impact
    assert_script_run("qubesctl state.apply qvm.anon-whonix", timeout=>3600);

    assert_script_run("yes | sudo -u user /tmp/sdw-upgrade.py --debug 2>&1 | tee /tmp/sdw-upgrade2.log");

    # Reset the state
    my @states = (
        'qvm.sys-net',
        'qvm.sys-firewall',
        'qvm.default-dispvm',
        'qvm.personal',
        'qvm.work',
        'qvm.untrusted',
        'qvm.vault',
        'qvm.updates-via-whonix'
    );
    foreach my $state (@states) {
        assert_script_run("sudo qubesctl top.enable $state");
    }

    # Rename Fedora 43->41: simulate outdated system (default qubes set to it)
    $self->select_gui_console;
    x11_start_program('qubes-vm-settings fedora-43-xfce', valid => 0);
    assert_and_click('vm-settings-rename');
    assert_screen('vm-settings-do-rename');
    type_string('fedora-41-xfce');
    assert_and_click('vm-settings-do-rename');
    $self->select_root_console;

    # Re-apply dom0-configuration, so SDW qubes switch to dummy fedora-43-xfce
    script_run("sudo qubesctl state.highstate", timeout => 1000);

    # Pretend like there are
    script_run("qvm-create --class TemplateVM --label black fedora-42-xfce");
    script_run("qvm-create --class TemplateVM --label black fedora-43-xfce");

    # Rename fedora 43
    script_run("qvm-shutdown --all");
    script_run("yes | qvm-template purge fedora-43-xfce", timeout=>3600);

    script_run("qubes-prefs default_template fedora-42-xfce");
    assert_script_run("yes | sudo -u user /tmp/sdw-upgrade.py --debug 2>&1 | tee /tmp/sdw-upgrade3.log");


    upload_logs('/tmp/sdw-upgrade.log', failok => 1);
    upload_logs('/tmp/sdw-upgrade2.log', failok => 1);
    upload_logs('/tmp/sdw-upgrade3.log', failok => 1);

}

1;

# vim: set sw=4 et:
