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

our @EXPORT = qw(download_repo configure_environment);

my $DEV_DIR = "/home/user/securedrop-workstation";  # In dom0


=head2 download_repo

    download_repo();

Fetches the SecureDrop Workstation git repository (without '.git') onto dom0
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
    assert_script_run("mv securedrop-workstation-* $DEV_DIR");
    assert_script_run("sudo chown user:user -R $DEV_DIR");
};


sub configure_environment {
    my ($environment) = @_;

    # Place configuration in development directory
    assert_script_run('echo "{\"submission_key_fpr\": \"65A1B5FF195B56353CC63DFFCC40EF1228271441\", \"hidserv\": {\"hostname\": \"bnbo6ryxq24fz27chs5fidscyqhw2hlyweelg4nmvq76tpxvofpyn4qd.onion\", \"key\": \"FDF476DUDSB5M27BIGEVIFCFGHQJ46XS3STAP7VG6Z2OWXLHWZPA\"}, \"environment\": \"env-placeholder\", \"vmsizes\": {\"sd_app\": 10, \"sd_log\": 5}}" | ' . 'tee ' . $DEV_DIR . '/config.json');
    assert_script_run("curl https://raw.githubusercontent.com/freedomofpress/securedrop/d91dc67/securedrop/tests/files/test_journalist_key.sec.no_passphrase | tee $DEV_DIR/sd-journalist.sec");

    # Call make target that places config in appropriate locations
    assert_script_run("make -C $DEV_DIR configure-env-$environment");
};
