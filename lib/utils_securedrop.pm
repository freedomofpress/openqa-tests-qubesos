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

package utils_securedrop;

use strict;
use testapi;
use networking;
use serial_terminal;

use base 'Exporter';
use Exporter;

our @EXPORT = qw(download_repo copy_config);

=head2 download_repo

    download_repo();

Fetches the SecureDrop Workstation git repository (without '.git') onto dom0's
'/home/user/securedrop-workstation'.
=cut
sub download_repo {
    # Assumes terminal window is open
    # Assumes "curl_via_netvm"

    # Building SecureDrop Workstation RPM and installing it in dom0
    assert_script_run('rpm -q make || sudo qubes-dom0-update -y make');
    assert_script_run('rpm -q unzip || sudo qubes-dom0-update -y unzip');

    # Download source from git commit reference
    my $repo_archive_url = "https://github.com/freedomofpress/securedrop-workstation/archive/";
    assert_script_run("curl -f -L -o - $repo_archive_url" . get_var('GIT_REF') . '.zip > sdw.zip');
    assert_script_run('unzip sdw.zip');

    # Explicitly copy to /home/user, since this may be called under "root_console"
    assert_script_run('mv securedrop-workstation-* /home/user/securedrop-workstation');
    assert_script_run('sudo chown user:user -R /home/user/securedrop-workstation');
};


sub copy_config {
    my ($environment) = @_;
    my $target_dir;
    my $sudo_modifier;

    if ($environment eq "prod") {
        # Place configuration files directly in final directory
        $target_dir = "/usr/share/securedrop-workstation-dom0-config";
        assert_script_run("sudo mkdir -p $target_dir");
        $sudo_modifier = "sudo "; # Tee command used later needs to run as root
    } else {
        # Place files in cloned repo (make targets will deal with the rest)
        $target_dir = "/home/user/securedrop-workstation";
        $sudo_modifier = "";  # no need for "sudo"
    }

    assert_script_run('echo "{\"submission_key_fpr\": \"65A1B5FF195B56353CC63DFFCC40EF1228271441\", \"hidserv\": {\"hostname\": \"bnbo6ryxq24fz27chs5fidscyqhw2hlyweelg4nmvq76tpxvofpyn4qd.onion\", \"key\": \"FDF476DUDSB5M27BIGEVIFCFGHQJ46XS3STAP7VG6Z2OWXLHWZPA\"}, \"environment\": \"' . $environment . '\", \"vmsizes\": {\"sd_app\": 10, \"sd_log\": 5}}" | ' . $sudo_modifier . 'tee ' . $target_dir . '/config.json');
    assert_script_run("curl https://raw.githubusercontent.com/freedomofpress/securedrop/d91dc67/securedrop/tests/files/test_journalist_key.sec.no_passphrase | $sudo_modifier tee $target_dir/sd-journalist.sec");

};
