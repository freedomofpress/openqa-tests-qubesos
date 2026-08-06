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
  update_server_config
  prep_dev_env
);


sub update_server_config {
    my $config_path = "/usr/share/securedrop-workstation-dom0-config";
    assert_script_run("sudo mkdir -p $config_path");

    # Write a new 'config.json' based on OpenQA variables
    my $environment = get_var("SECUREDROP_ENV");

    # External server (always overrides local server preference)
    my $sd_journalist_onion = get_var('SECUREDROP_JI_ONION');
    my $sd_journalist_onion_key = get_var('SECUREDROP_JI_ONION_KEY');

    if (!defined $sd_journalist_onion) {
        # Local server
        my $qvm_run_args = "-p -u root --no-color-stderr --no-color-output"; # run as root and prevent output colors
        my $onion_service_dir = "/var/lib/docker/volumes/sd-onion-services/_data/journalist";
        $sd_journalist_onion = script_output("qvm-run $qvm_run_args sd-dev \"cat $onion_service_dir/hostname\"");
        $sd_journalist_onion_key = script_output("qvm-run $qvm_run_args sd-dev \"cat $onion_service_dir/authorized_clients/client.auth\"| cut -d: -f3");
    }

    assert_script_run("echo '{\"submission_key_fpr\": \"65A1B5FF195B56353CC63DFFCC40EF1228271441\", \"hidserv\": {\"hostname\": \"$sd_journalist_onion\", \"key\": \"$sd_journalist_onion_key\"}, \"environment\": \"$environment\", \"vmsizes\": {\"sd_app\": 10, \"sd_log\": 5}}' | sudo tee $config_path/config.json");

    # Move the config file into the right places in dom0
    assert_script_run("su user -c \"echo 'copy_config()' | (cd /usr/bin/ && python3 -i sdw-admin --validate)\"");

    # Re-provision to place config secrets in respective VMs
    assert_script_run('qvm-kill sd-proxy sd-app');
    assert_script_run("sudo qubesctl --targets dom0 state.highstate", timeout => 1000);
    assert_script_run("qvm-start sd-proxy sd-app");
};

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
    assert_script_run("sudo date -s @" . time());
    assert_script_run("qvm-run -u root --no-shell sd-dev /usr/bin/qvm-sync-clock");
}

1;
# vim: sw=4 et ts=4:
