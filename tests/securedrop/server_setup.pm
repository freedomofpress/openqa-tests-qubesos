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


=head2

  setup_securedrop_server()

Sets up a SecureDrop server in a development qube

=cut

sub setup_securedrop_server {

    # Server Setup
    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting

    # WIP - debugging https://openqa.qubes-os.org/tests/128656#step/installing_SecureDrop/32
    assert_script_run('sudo qubes-dom0-update -y', timeout => 600);
    assert_script_run('sudo qubes-dom0-update -y python3.11 python3-qt5');

    assert_script_run('qvm-check sd-dev || qvm-create --label gray sd-dev --class StandaloneVM --template debian-13-xfce');
    assert_script_run('qvm-volume resize sd-dev:private 50G', timeout=> 120);

    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop"');
    assert_script_run('qvm-run -p sd-dev "sudo apt install -y podman make"');
    send_key('alt-f4');

    # NOTE: These are done via qvm-run instead of gnome-terminal so that we
    # can know in case they failed.

    x11_start_program('qvm-run sd-dev xfce4-terminal', target_match => 'securedrop-dev');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting
    sleep(1); # Wait for terminal to come up
    type_string("cd securedrop\n");
    type_string("USE_PODMAN=1 make dev\n");
    assert_screen('securedrop-server-running', timeout=>1200);
    send_key('ctrl-c');  # stop server, now that intial setup has succeeded
    sleep(5);
    send_key('alt-f4');

}


sub run {
    my ($self) = @_;

    $self->select_gui_console;
    assert_screen "desktop";
    setup_securedrop_server;
}

1;
