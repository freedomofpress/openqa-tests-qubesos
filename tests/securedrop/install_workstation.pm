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
use utils_securedrop qw(download_repo configure_environment);

# Following instructions at https://github.com/freedomofpress/securedrop-workstation-docs/blob/aa89494/docs/admin/install/install.rst#download-securedrop-workstation-packages
sub qubes_contrib_keyring_bootstrap {
    my ($environment) = @_;

    assert_script_run('sudo qubes-dom0-update -y qubes-repo-contrib', timeout => 120);
    assert_script_run('sudo qubes-dom0-update --clean -y securedrop-workstation-keyring', timeout => 120);

    sleep(15); # sleep for securedrop-workstation-keyring key to be imported,

    assert_script_run('sudo dnf -y remove qubes-repo-contrib');

    # QA: just replace the repo URL to keep it as close as possible to prod
    if (check_var("SECUREDROP_USE_PROD_QA_SERVER", "1")) {
        assert_script_run("sudo sed -i -e 's|yum.|yum-qa.|g' /etc/yum.repos.d/securedrop-workstation-dom0.repo");
    }
};

sub install {
    my ($environment) = @_;


    if ($environment eq "dev") {
        # Create a dev environment and sync to dom0 (allows building local RPMs)
        make_clone();
    } elsif ($environment eq "staging") {
        # Fetch repository to access Makefile, etc. (but no need to build RPMs)
        download_repo();
    }

    my $installation_cmd;
    if ($environment eq "prod") {
        qubes_contrib_keyring_bootstrap("$environment");
        assert_script_run("sudo qubes-dom0-update --clean -y securedrop-workstation-dom0-config");
        $installation_cmd = "sdw-admin --apply";
    } else {
        $installation_cmd = "cd securedrop-workstation && make $environment";
    }

    configure_environment($environment);

    # disable screen blanking during long command
    assert_script_run('env xset -dpms; env xset s off', valid => 0, timeout => 10);

    assert_script_run("$installation_cmd | tee /tmp/sdw-admin-apply.log",  timeout => 6000);
    upload_logs('/tmp/sdw-admin-apply.log', failok => 1);
};

sub make_clone {

    # Assumes terminal window is open

    assert_script_run('qvm-check sd-dev || qvm-create --label gray sd-dev --class StandaloneVM --template debian-12-xfce');

    # Building SecureDrop Workstation RPM and installing it in dom0
    assert_script_run('qvm-run -p sd-dev "sudo apt-get install -y make git jq"');
    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop-workstation"');
    assert_script_run('qvm-run -p sd-dev "git -C securedrop-workstation checkout ' . get_var('GIT_REF') . '"');

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
    assert_script_run('qvm-shutdown --wait sd-dev && qvm-start sd-dev');  # Restart for groupadd to take effect

    # First repo cloning (does not build RPM)
    assert_script_run("qvm-run --pass-io sd-dev 'tar -c -C /home/user/ securedrop-workstation' | tar xvf -", timeout=>300);

    # Re-clone, this time with RPM being built and copied to dom0 in the process
    assert_script_run('(cd securedrop-workstation && make clone)', timeout => 1000);
};


sub run {
    my ($self) = @_;

    $self->select_gui_console;
    assert_screen "desktop";

    # Validate environment
    my $environment = get_var('SECUREDROP_ENV');
    my @valid_environments = qw(dev staging prod prod-qa);
    if (not grep { $_ eq $environment } @valid_environments) {
        die "Invalid environment: '$environment'. It must be one of: " . join(", ", @valid_environments) . ".\n";
    }
    if ($environment eq "prod-qa") {
        # "prod-qa" doesn't carry any meaning in the workstation context. It's
        # just a way in OpenQA to know we should also replace the repos to point
        # to the QA ones.
        $environment = "prod";
        set_var("SECUREDROP_USE_PROD_QA_SERVER", "1");
    }

    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting

    curl_via_netvm;  # necessary for curling script and uploading logs

    assert_script_run('set -o pipefail'); # Ensure pipes fail

    install($environment);

    send_key('alt-f4');  # close terminal
}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook();

    upload_logs('/tmp/sdw-admin-apply.log', failok => 1);
};

1;

# vim: set sw=4 et:
