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

sub test_client_login {
    if (check_var('SECUREDROP_USE_APP', '1')) {

        x11_start_program('xterm');
        send_key('alt-f10');  # maximize xterm to ease troubleshooting

        assert_script_run('qvm-run --service sd-app qubes.StartApp+press.freedom.SecureDropApp', target_match => "securedrop-app-login", timeout => 60);
        assert_script_run('sleep 60', timeout => 65);

        # DEBUG: if failed try starting directly and see what failed
        assert_script_run('qvm-run -p sd-app "securedrop-app"', timeout => 60);
        assert_script_run('sleep 60', timeout => 65); # Leave screen up some time to see in video
    } else {
        x11_start_program('qvm-run --service sd-app qubes.StartApp+press.freedom.SecureDropClient', target_match => "securedrop-client-login");
    }

    # TODO: type remaining credentials
}

sub run {
    my ($self) = @_;

    $self->select_gui_console;

    test_client_login;

};

1;
