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
use OpenQA::Test::RunArgs;

sub enable_disposable_preload() {
    my $self = shift;

    # Enables disp. qubes preloading (Assumed any machine is >= 15G RAM)
    # This is likely necessary because the Qubes OpenQA installation is usually
    # less than 15G of RAM, which means that disposable preloading is disabled
    assert_script_run("sudo qubesctl top.enable qvm.disposable-preload pillar=True");
    assert_script_run("sudo qubesctl state.apply qvm.disposable-preload", timeout => 300);
}

sub make_clone {
    my $self = shift;
    # Assumes terminal window is open

    # Obtain debian-minimal template on which to base sd-dev
    my $debian_minimal = "debian-13-minimal";
    assert_script_run("qvm-check $debian_minimal || qvm-template install $debian_minimal", timeout => 900);

    # Create 'sd-dev' template
    assert_script_run("qvm-check sd-dev || qvm-clone $debian_minimal sd-dev-tpl", timeout => 500);

    # Building SecureDrop Workstation RPM and installing it in dom0
    assert_script_run('qvm-run -p -u root sd-dev-tpl "apt-get update"', timeout => 120);
    assert_script_run('qvm-run -p -u root sd-dev-tpl "apt-get install -y make git jq qubes-core-agent-networking qubes-core-agent-passwordless-root"', timeout => 120);

    # SecureDrop dev. env. according to https://developers.securedrop.org/en/latest/setup_development.html
    # DOCKER INSTALL according to https://docs.docker.com/engine/install/debian/
    assert_script_run('qvm-run -p -u root sd-dev-tpl "apt-get install -y ca-certificates curl"');
    assert_script_run('qvm-run -p -u root sd-dev-tpl "install -m 0755 -d /etc/apt/keyrings"');
    assert_script_run('qvm-run -p -u root sd-dev-tpl "curl --proxy 127.0.0.1:8082 -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc"');
    assert_script_run('qvm-run -p -u root sd-dev-tpl "chmod a+r /etc/apt/keyrings/docker.asc"');
    assert_script_run('qvm-run -p -u root sd-dev-tpl ". /etc/os-release && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \$VERSION_CODENAME stable\" | tee /etc/apt/sources.list.d/docker.list \> /dev/null"');
    assert_script_run('qvm-run -p -u root sd-dev-tpl "apt-get update"');
    assert_script_run('qvm-run -p -u root sd-dev-tpl "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"', timeout => 120);
    assert_script_run('qvm-run -p -u root sd-dev-tpl "groupadd docker || true"');
    assert_script_run('qvm-run -p -u root sd-dev-tpl "usermod -aG docker user"');


    assert_script_run('qvm-shutdown --wait sd-dev-tpl');

    assert_script_run('qvm-create sd-dev --template sd-dev-tpl --label gray');
    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop-workstation"');
    assert_script_run('qvm-run -p sd-dev "git -C securedrop-workstation checkout ' . get_var('GIT_REF') . '"');

    # First repo cloning (does not build RPM)
    assert_script_run("qvm-run --pass-io sd-dev 'tar -c -C /home/user/ securedrop-workstation' | tar xvf -", timeout=>300);

    # Re-clone, this time with RPM being built and copied to dom0 in the process
    assert_script_run('(cd securedrop-workstation && make clone)', timeout => 1000);
};


sub download_repo {
    my $self = shift;

    # Assumes terminal window is open
    # Assumes "curl_via_netvm"

    # Fetch the repo without the need of "sd-dev" and "make clone"
    assert_script_run('rpm -q make unzip || sudo qubes-dom0-update -y make unzip');

    # Download source from git commit reference
    my $repo_archive_url = "https://github.com/freedomofpress/securedrop-workstation/archive/";
    assert_script_run("curl -f -L -o - $repo_archive_url" . get_var('GIT_REF') . '.zip > sdw.zip');
    assert_script_run('unzip sdw.zip');
    assert_script_run('mv securedrop-workstation-* securedrop-workstation');
};


sub run {
    my ($self, $args) = @_;

    $self->select_gui_console;
    assert_screen "desktop";

    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting

    # Enable dispvm preloading to test opening documents faster
    enable_disposable_preload;

    assert_script_run('set -o pipefail'); # Ensure pipes fail

    # Pick whether we'll need build local RPMs or just need access to tooling
    if ($self->{environment} eq "dev") {
        # Create a dev environment and sync to dom0 (allows building local RPMs)
        make_clone();
    } else {
        # Fetch repository to access Makefile, etc. (but no need to build RPMs)
        download_repo();
    }

    send_key('alt-f4');  # close terminal
};


1;

# vim: set sw=4 et:
