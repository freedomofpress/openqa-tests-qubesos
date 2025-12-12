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

our @EXPORT = qw(download_repo);

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
