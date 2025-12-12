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


# These are kept in a separate test file because in case of a dist upgrade test
# the workstation installation needs to happen before the release upgrade and
# this file needs to run after that. Separating into a different file is the
# easiest way to accomplish that.


sub enable_disposable_preload() {
    # Enables disp. qubes preloading (Assumed any machine is >= 15G RAM)
    # This is likely necessary because the Qubes OpenQA installation is usually
    # less than 15G of RAM, which means that disposable preloading is disabled
    assert_script_run("sudo qubesctl top.enable qvm.disposable-preload pillar=True");
    assert_script_run("sudo qubesctl state.apply qvm.disposable-preload", timeout => 300);
}


sub run {
    my ($self) = @_;

    if (check_var("VERSION", "4.2") and not check_var('RELEASE_UPGRADE', '1')) {
        # SKIP: preloaded disposables are only available since Qubes 4.3
        return;
    }

    enable_disposable_preload;
}

1;

# vim: set sw=4 et:
