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
    if (check_var('SECUREDROP_USE_APP')) {
        x11_start_program('qvm-run --service sd-app qubes.StartApp+press.freedom.SecureDropClient', target_match => "securedrop-client-login");
    } else {
        x11_start_program('qvm-run --service sd-app qubes.StartApp+press.freedom.SecureDropApp', target_match => "securedrop-app-login");
    }

    # TODO: type remaining credentials
}

sub run {
    my ($self) = @_;

    $self->select_gui_console;

    test_client_login;

};

1;
