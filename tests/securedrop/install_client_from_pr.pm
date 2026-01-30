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


sub run {
    my ($self) = @_;

    $self->select_gui_console;
    assert_screen "desktop";

    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting

    # Building SecureDrop Client and installing it
    assert_script_run('qvm-run -p sd-dev "sudo apt-get install -y make git git-lfs jq"', timeout => 120);
    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop-builder"', timeout => 300);
    assert_script_run('qvm-run -p sd-dev "cd securedrop-builder && make install-deps"', timeout => 600);
    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop-client"', timeout => 300);

    assert_script_run('cd securedrop-workstation');
    assert_script_run('./scripts/try-client-pr.py ' . get_var('SECUREDROP_CLIENT_PR'), valid => 0, timeout => 900);

    send_key('alt-f4');  # close terminal
}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook();

};

1;

# vim: set sw=4 et:
