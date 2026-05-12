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

my $sdw_path = "/home/user/securedrop-workstation";

sub upload_test_logs {
    my (%args) = @_;

    # Upload test logs
    upload_logs("$sdw_path/test-data.xml", timeout => 120); # Upload original (in case conversion fails)

    # HACK: work around "extra-files" failing to be obtained via the usual route (via CASEDIR b64)
    assert_script_run("curl https://raw.githubusercontent.com/QubesOS/openqa-tests-qubesos/refs/heads/main/extra-files/convert_junit.py 2>/dev/null > /home/user/convert_junit.py");

    # Upload external results
    script_run("iconv -f utf8 -t ascii//translit $sdw_path/test-data.xml > $sdw_path/test-data-tmp.xml");
    script_run("python3 /home/user/convert_junit.py $sdw_path/test-data-tmp.xml $sdw_path/test-data-converted.xml");
    parse_junit_log("$sdw_path/test-data-converted.xml");
}

sub run {
    my ($self) = @_;

    $self->select_root_console;

    # Enable networking for log uploading to work
    enable_dom0_network_netvm() unless $self->{network_up};

    # Setup testing requirements and run tests
    assert_script_run("make -C $sdw_path install-dom0-test-prereqs", timeout => 300);

    # Run tests
    assert_script_run("su user -c \"env XAUTHORITY=/run/lightdm/user/xauthority DISPLAY=:0.0 CI=true make -C $sdw_path test\"", timeout => 2400);
}

sub post_run_hook {
    my $self = shift;

    # Extra debugging info to be able to compare against failed jobs
    emergency_logging();

    # Upload loads in case of successful run
    upload_test_logs();

    # NOTE: Run at the end because some may fail and just abort execution
    $self->SUPER::post_run_hook();
}

sub emergency_logging {
    # Emergency logs in case uploading logs fails (qubes-issues#9581)
    # (section copied from lib/installedtest.pm)
    script_run "lspci";
    script_run "xl info";
    script_run "xl list";
    script_run "xl dmesg";
    script_run "journalctl -b|tail -n 10000", timeout => 120;
    script_run "cat /var/log/salt/minion";
    script_run "cat /var/log/libvirt/libxl/libxl-driver.log";
    script_run "tail /var/log/xen/console/guest*-dm.log";
    script_run "grep -B 100 'Kernel panic' /var/log/xen/console/guest*.log";
    script_run "tail -200 /var/log/xen/console/guest-sys-net.log";
    script_run "tail -200 /var/log/xen/console/guest-sys-usb.log";

    # Extra logs requested by Marek:
    script_run "cat /var/log/xen/xen-hotplug.log";
    script_run "lsof -n /run/lock/qubes-script.lock";

    # Emergency logs for SD qubes
    script_run "tail -n 200 /var/log/xen/console/guest-sd-*.log ";
}


sub post_fail_hook {
    my $self = shift;

    select_root_console();

    emergency_logging();
    upload_test_logs();

    # NOTE: Run at the end because some may fail and just abort execution
    $self->SUPER::post_fail_hook();
};


1;
