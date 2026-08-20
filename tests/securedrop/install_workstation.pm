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
use OpenQA::Test::RunArgs;


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    $self->{environment} = "invalid";
    return $self;
}

sub enable_disposable_preload() {
    my $self = shift;

    # Enables disp. qubes preloading (Assumed any machine is >= 15G RAM)
    # This is likely necessary because the Qubes OpenQA installation is usually
    # less than 15G of RAM, which means that disposable preloading is disabled
    assert_script_run("sudo qubesctl top.enable qvm.disposable-preload pillar=True");
    assert_script_run("sudo qubesctl state.apply qvm.disposable-preload", timeout => 300);
}

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

# Following instructions at https://github.com/freedomofpress/securedrop-workstation-docs/blob/aa89494/docs/admin/install/install.rst#download-securedrop-workstation-packages
sub qubes_contrib_keyring_bootstrap {
    my $self = shift;

    assert_script_run('sudo qubes-dom0-update -y qubes-repo-contrib', timeout => 120);
    assert_script_run('sudo qubes-dom0-update --clean -y securedrop-workstation-keyring', timeout => 120);

    sleep(15); # sleep for securedrop-workstation-keyring key to be imported,

    assert_script_run('sudo dnf -y remove qubes-repo-contrib');

    # QA: just replace the repo URL to keep it as close as possible to prod
    if ($self->{environment} eq "prod-qa") {
        assert_script_run("sudo sed -i -e 's|yum.|yum-qa.|g' /etc/yum.repos.d/securedrop-workstation-keyring-dev.repo");
    }
};

sub install {
    my $self = shift;

    # Pick whether we'll need build local RPMs or just need access to tooling
    if ($self->{environment} eq "dev" || get_var("SECUREDROP_UPGRADE")) {
        # Create a dev environment and sync to dom0 (allows building local RPMs)
        make_clone();
    } else {
        # Fetch repository to access Makefile, etc. (but no need to build RPMs)
        download_repo();
    }

    my $installation_cmd;
    if ($self->{environment} eq "prod" || $self->{environment} eq "prod-qa") {
        $self->qubes_contrib_keyring_bootstrap();
        assert_script_run("sudo qubes-dom0-update --clean -y securedrop-workstation-dom0-config");
        $installation_cmd = "sdw-admin --apply";
    } else {
        $installation_cmd = "cd securedrop-workstation && make $self->{environment}";
    }

    $self->copy_config();

    # disable screen blanking during long command
    assert_script_run('env xset -dpms; env xset s off', valid => 0, timeout => 10);

    assert_script_run("$installation_cmd | tee " . $self->{sdw_log_path},  timeout => 6000);
    upload_logs($self->{sdw_log_path}, failok => 1);
};

sub copy_config {
    my $self = shift;
    my $target_dir;
    my $sudo_modifier;

    if ($self->{environment} eq "prod" || $self->{environment} eq "prod-qa") {
        # Place configuration files directly in final directory
        $target_dir = "/usr/share/securedrop-workstation-dom0-config";
        assert_script_run("sudo mkdir -p $target_dir");
        $sudo_modifier = "sudo "; # Tee command used later needs to run as root
    } else {
        # Place files in cloned repo (make targets will deal with the rest)
        $target_dir = "/home/user/securedrop-workstation";
        $sudo_modifier = "";  # no need for "sudo"
    }

    assert_script_run('echo "{\"submission_key_fpr\": \"65A1B5FF195B56353CC63DFFCC40EF1228271441\", \"hidserv\": {\"hostname\": \"bnbo6ryxq24fz27chs5fidscyqhw2hlyweelg4nmvq76tpxvofpyn4qd.onion\", \"key\": \"FDF476DUDSB5M27BIGEVIFCFGHQJ46XS3STAP7VG6Z2OWXLHWZPA\"}, \"environment\": \"' . $self->{environment} . '\", \"vmsizes\": {\"sd_app\": 10, \"sd_log\": 5}}" | ' . $sudo_modifier . 'tee ' . $target_dir . '/config.json');
    assert_script_run("curl https://raw.githubusercontent.com/freedomofpress/securedrop/d91dc67/securedrop/tests/files/test_journalist_key.sec.no_passphrase | $sudo_modifier tee $target_dir/sd-journalist.sec");


};

sub make_clone {
    my $self = shift;
    # Assumes terminal window is open
    prep_dev_env;

    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop-workstation"');
    assert_script_run('qvm-run -p sd-dev "git -C securedrop-workstation checkout ' . get_var('GIT_REF') . '"');

    # First repo cloning (does not build RPM)
    assert_script_run("qvm-run --pass-io sd-dev 'tar -c -C /home/user/ securedrop-workstation' | tar xvf -", timeout=>300);

    # Re-clone, this time with RPM being built and copied to dom0 in the process
    assert_script_run('(cd securedrop-workstation && make clone)', timeout => 1000);
};

sub run {
    my ($self, $args) = @_;

    $self->select_gui_console;
    assert_screen "desktop";

    # Validate environment
    $self->{environment} = get_var('SECUREDROP_ENV');
    if (exists $args->{env}) {
        # Env is overridable via 'env' argument
        $self->{environment} = $args->{env};
    }
    my @valid_environments = qw(dev staging prod prod-qa);
    if (not grep { $_ eq $self->{environment} } @valid_environments) {
        die "Invalid environment: " . $self->{environment} . ". It must be one of: " . join(", ", @valid_environments) . ".\n";
    }
    $self->{sdw_log_path} = "/tmp/sdw-admin-apply_" . $self->{environment} . ".log";

    diag("Starting installation:");
    diag("\tEnvironment:\t " . $self->{environment});
    diag("\tScenario:\t " . (check_var('SECUREDROP_UPGRADE', '1') ? "upgrade" : "clean install"));
    diag("\tLogs:\t " . $self->{sdw_log_path});

    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting

    curl_via_netvm;  # necessary for curling script and uploading logs

    # Enable dispvm preloading to test opening documents faster
    enable_disposable_preload;

    assert_script_run('set -o pipefail'); # Ensure pipes fail

    $self->install();

    send_key('alt-f4');  # close terminal
}

sub upload_install_logs {
    my $self = shift;
    upload_logs($self->{sdw_log_path}, failok => 1);
}


sub post_run_hook {
    my $self = shift;

    select_root_console();

    # Upload logs in case of successful run
    $self->upload_install_logs();

    # NOTE: Run at the end because some may fail and just abort execution
    $self->SUPER::post_run_hook();
}

sub post_fail_hook {
    my $self = shift;

    select_root_console();

    # Emergency logs printing (so we have something, in case uploading them fails)
    script_run("cat /var/log/salt/minion");
    script_run("zcat /var/log/salt/*.gz");

    $self->upload_install_logs();

    # NOTE: Run at the end because some may fail and just abort execution
    $self->SUPER::post_fail_hook();
};

1;

# vim: set sw=4 et:
