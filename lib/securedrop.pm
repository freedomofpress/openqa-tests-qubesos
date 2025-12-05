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
#
package securedrop;
use testapi;
use base Exporter;
use Exporter;

our @EXPORT = qw(
  prep_dev_env
);

sub prep_dev_env {

    if (script_run('qvm-check sd-dev-tpl sd-dev') != 0) {
        # Obtain debian-minimal template on which to base sd-dev
        my $debian_minimal = "debian-13-minimal";
        assert_script_run("qvm-check $debian_minimal || qvm-template install $debian_minimal", timeout => 900);

        # Create 'sd-dev' template
        assert_script_run("qvm-check sd-dev || qvm-clone $debian_minimal sd-dev-tpl", timeout => 500);

        # Building SecureDrop Workstation RPM and installing it in dom0
        assert_script_run('qvm-run -p -u root sd-dev-tpl "apt-get update"', timeout => 120);
        assert_script_run('qvm-run -p -u root sd-dev-tpl "apt-get install -y make git jq qubes-core-agent-networking"', timeout => 120);

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

        # Enable passwordless root for dev scripts that assume it, can run fine
        assert_script_run('qvm-run -p -u root sd-dev-tpl "apt-get install -y qubes-core-agent-passwordless-root"');

        assert_script_run('qvm-shutdown --wait sd-dev-tpl');

        assert_script_run('qvm-create sd-dev --template sd-dev-tpl --label gray');
    }

    # Make sure time is the same. Otherwise TOTP won't work
    assert_script_run("date -s @" . time());
    assert_script_run("qvm-run -u root --no-shell sd-dev /usr/bin/qvm-sync-clock");
}

1;
# vim: sw=4 et ts=4:
