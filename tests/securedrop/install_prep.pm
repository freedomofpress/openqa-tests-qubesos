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


# Prepares "sd-dev" development machine
sub prep_install_dev {
    # Assumes terminal window is open
    assert_script_run('qvm-check sd-dev || qvm-create --label gray sd-dev --class StandaloneVM --template debian-12-xfce', timeout => 120);
    assert_script_run('qvm-volume resize sd-dev:private 20G', timeout => 60); # Plenty of space for container images

    # Install build dependencies
    assert_script_run('qvm-run -p sd-dev "sudo apt-get update && sudo apt-get install -y make git jq"', timeout => 120);

    # Pre-clone workstation repo
    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop-workstation"', timeout => 120);

    # SecureDrop dev. env. according to https://developers.securedrop.org/en/latest/setup_development.html
    # DOCKER INSTALL according to https://docs.docker.com/engine/install/debian/
    assert_script_run('qvm-run -p sd-dev "sudo apt-get update"');
    assert_script_run('qvm-run -p sd-dev "sudo apt-get install -y ca-certificates curl"');
    assert_script_run('qvm-run -p sd-dev "sudo install -m 0755 -d /etc/apt/keyrings"');
    assert_script_run('qvm-run -p sd-dev "sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc"');
    assert_script_run('qvm-run -p sd-dev "sudo chmod a+r /etc/apt/keyrings/docker.asc"');
    assert_script_run('qvm-run -p sd-dev ". /etc/os-release && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \$VERSION_CODENAME stable\" | sudo tee /etc/apt/sources.list.d/docker.list \> /dev/null"');
    assert_script_run('qvm-run -p sd-dev "sudo apt-get update"');
    assert_script_run('qvm-run -p sd-dev "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"');
    assert_script_run('qvm-run -p sd-dev "sudo groupadd docker || true"');
    assert_script_run('qvm-run -p sd-dev "sudo usermod -aG docker \$USER"');
    assert_script_run('qvm-shutdown --wait sd-dev');  # Shut it down for groupadd to take effect
};

sub run {
    my ($self) = @_;

    $self->select_gui_console;
    assert_screen "desktop";

    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting

    prep_install_dev;

    # Pre-download templates generally used in workstation
    assert_script_run('qvm-template install fedora-42-xfce', timeout => 1500);
    assert_script_run('qvm-template install debian-12-minimal', timeout => 1500);
    assert_script_run('qubes-vm-update --force-update --show-output', timeout => 3600);

    send_key('alt-f4');  # close xterm

}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook();

    upload_logs('/tmp/sdw-admin-apply.log', failok => 1);
};

1;

# vim: set sw=4 et:
