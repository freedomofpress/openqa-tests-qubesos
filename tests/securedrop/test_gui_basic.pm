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
use serial_terminal;
use totp qw(generate_totp);
use securedrop;


sub update_config {
    my $config_path = "/usr/share/securedrop-workstation-dom0-config";
    assert_script_run("sudo mkdir -p $config_path");

    # Write a new 'config.json' based on OpenQA variables
    my $environment = get_var("SECUREDROP_ENV");

    # External server (always overrides local server preference)
    my $sd_journalist_onion = get_var('SECUREDROP_JI_ONION');
    my $sd_journalist_onion_key = get_var('SECUREDROP_JI_ONION_KEY');

    if (!defined $sd_journalist_onion) {
        # Local server
        my $qvm_run_args = "-p -u root --no-color-stderr --no-color-output"; # run as root and prevent output colors
        my $onion_service_dir = "/var/lib/docker/volumes/sd-onion-services/_data/journalist";
        $sd_journalist_onion = script_output("qvm-run $qvm_run_args sd-dev \"cat $onion_service_dir/hostname\"");
        $sd_journalist_onion_key = script_output("qvm-run $qvm_run_args sd-dev \"cat $onion_service_dir/authorized_clients/client.auth\"| cut -d: -f3");
    }

    assert_script_run("echo '{\"submission_key_fpr\": \"65A1B5FF195B56353CC63DFFCC40EF1228271441\", \"hidserv\": {\"hostname\": \"$sd_journalist_onion\", \"key\": \"$sd_journalist_onion_key\"}, \"environment\": \"$environment\", \"vmsizes\": {\"sd_app\": 10, \"sd_log\": 5}}' | sudo tee $config_path/config.json");

    # Move the config file into the right places in dom0
    assert_script_run("su user -c \"echo 'copy_config()' | (cd /usr/bin/ && python3 -i sdw-admin --validate)\"");

    # Re-provision to place config secrets in respective VMs
    assert_script_run('qvm-kill sd-proxy sd-app');
    assert_script_run("sudo qubesctl --targets dom0 state.highstate", timeout => 1000);
    assert_script_run("qvm-start sd-proxy sd-app");

};

sub prepare_test {
    # Any preparations needed for the test
    update_config();

    # make sure time is the same or TOTP won't work out (borrowed from aem.pm)
    assert_script_run("date -s @" . time());

    # (debuging) Test server connectivity
    script_run('echo debug-curl-onion && qvm-run -p sd-proxy "curl --proxy socks5h://localhost:9150 \$(qubesdb-read /vm-config/SD_PROXY_ORIGIN)"', timeout => 30);
    script_run('qvm-run -p sd-proxy "sudo journalctl -u tor"');

}

sub test_login {
    x11_start_program('qvm-run --service sd-app qubes.StartApp+press.freedom.SecureDropApp', target_match => "securedrop-inbox-login");

    # Username
    assert_and_click("securedrop-inbox-type-username");
    type_string("journalist");
    send_key('tab');

    # Password
    type_string("correct horse battery staple profanity oil chewy");
    send_key('tab'); # switches to TOTP field

    # TOTP code
    my $totp = generate_totp("JHCOGO7VCER3EJ4L");
    type_string("$totp");
    send_key('ret');

    # TODO also test unreachable server (e.g. pause sys-net)
    # assert_screen("securedrop-inbox-server-unreachable");
};

sub test_close {
    assert_and_click("securedrop-inbox-close-window");
    assert_and_click("securedrop-inbox-close-window-confirm");
}

sub test_sources {
    ##
    # AFTER VALID LOGIN
    ##

    # The source list is displayed but no sources are selected by default and
    # the conversation view is not populated.
    assert_screen("securedrop-inbox-no-source-selected");

    # (optional) The messages in the source list may show as encrypted
    check_screen("securedrop-inbox-source-list-encrypted-messages");

    # Source messages are decrypted
    # assert_screen("securedrop-inbox-decrypted-source-messages", timeout => 30);
    # TODO add OCR


    ##
    # WHEN A SOURCE IS SELECTED IN THE SOURCE LIST
    ##

    # conversation view is populated with source conversation
    assert_and_click("securedrop-inbox-open-1st-source");
    assert_screen("securedrop-inbox-1st-source-opened");
    # TODO check via OCR that selected source name matches openned source name

    # a source message containing HTML is displayed as unformatted text
    assert_screen("securedrop-inbox-source-conversation");
    # TODO add OCR

    # source submissions have an active Download button
    # TODO - This was skipped because it should go on the file attachment section
    # source submission compressed file size is displayed accurately
    # TODO - This was skipped because it should go on the file attachment section

    ##
    # WHEN THE UPPER RIGHT 3-DOT BUTTON IS CLICKED
    ##

    # when delete source account is selected:
    # 1. a menu is displayed with a delete source account option the source is
    # deleted from the source list and the conversation view is blanked
    assert_and_click("securedrop-inbox-select-1st-source");
    assert_screen("securedrop-inbox-select-1st-source-is-selected");
    assert_and_click("securedrop-inbox-select-1st-source-delete");
    assert_and_click("securedrop-inbox-select-1st-source-delete-confirm");
    # after deletion selection is empty
    assert_screen("securedrop-inbox-only-two-sources-no-source-selected");

    # 2. the source is deleted from the server and not restored on next sync
    # TODO
    # 3. source submissions and messages are removed from the client's data directory
    # TODO

    ###
    ## STARRING A SOURCE
    ###
    assert_and_click("securedrop-inbox-star-source");
    # the client is closed and reopened in Online mode:
    test_close;
    test_login;

    # - the source is still starred in the source list
    assert_and_click("securedrop-inbox-2nd-source-is-starred");
    assert_and_click("securedrop-inbox-unstart-2nd-source");
    assert_screen("securedrop-inbox-2nd-source-is-unstarred");

};

sub test_replies {
    # When a source is picked in the source list:
    assert_and_click("securedrop-inbox-open-1st-source");

    # 1. the reply panel is available for use and there is no message asking the
    #    user to sign in
    assert_and_click("securedrop-inbox-online-mode-source-reply-box");

    # 2. a reply can be added to the conversation
    type_string("Some reply text <b>this is not bold</b>");
    assert_and_click("securedrop-inbox-online-mode-source-reply-send");
    assert_screen("securedrop-inbox-online-mode-source-reply-sent");

    # 3. a pending reply can be added to the conversation (ie., by disconnecting
    #    the network or shutting down sd-whonix just before sending a reply)
    # TODO

    # 4. a reply containing HTML is displayed as unformatted text
    assert_screen("securedrop-inbox-online-mode-source-reply-is-unformatted");

    # 5. a reply with a single string of characters longer than 100 chars is
    #    displayed, but truncated
    assert_and_click("securedrop-inbox-online-mode-source-reply-box");
    type_string("verylongstringofcharacterswithoutanyspacesinitwillactuallybetruncatedotherwiseitisabugisitnot?");
    assert_and_click("securedrop-inbox-online-mode-source-reply-send");

    # 6. a reply with a line longer than 100 chars is displayed correctly
    assert_and_click("securedrop-inbox-online-mode-source-long-reply-truncated");

    # 7. two replies added immediately after each other are ordered correctly
    # TODO
};

sub test_submissions {
    # when Download is clicked on a submission:
    # 1. the submission is downloaded and decrypted
    assert_and_click("securedrop-inbox-attachment-download");

    # 2. the submission filename is displayed.
    assert_screen("securedrop-inbox-attachment-filename");

    # 3. the Download button is replaced with "three dot" menu
    assert_screen("securedrop-inbox-attachment-three-dot-click", timeout=>20);
    assert_screen("securedrop-inbox-attachment-three-dot-print", timeout=>20);
    assert_screen("securedrop-inbox-attachment-three-dot-export", timeout=>20);

    # text submission (NOTE: not in original test plan)
    # 1. when the submission filename is clicked, a disposable VM (dispVM) is started.
    assert_and_click("securedrop-inbox-attachment-filename");

    # 2. after the dispVM starts, the submission is displayed in text editor
    assert_and_click("securedrop-inbox-attachment-disposable-opens");

    # 3. text editor is closed, the dispVM shuts down
    assert_and_click("securedrop-inbox-attachment-disposable-close-window");
    assert_screen("securedrop-inbox-source-conversation"); # back to the conversation view

    # For a DOC submission:
    # 1. when the submission filename is clicked, a disposable VM (dispVM) is started.
    # 2. after the dispVM starts, the submission is displayed in LibreOffice
    # 3. when LibreOffice is closed, the dispVM shuts down

    # For a PDF submission:
    # 1. when the submission filename is clicked, a dispVM is started.
    # 2. after the dispVM starts, the submission is displayed in evince
    # 3. when evince is closed, the dispVM shuts down

    # For a JPEG submission:
    # 1. when the submission filename is clicked, a dispVM is started.
    # 2. after the dispVM starts, the submission is displayed in Image Viewer
    # 3. when Image Viewer is closed, the dispVM shuts down

    # For an audio submission:
    # 1. when the submission filename is clicked, a dispVM is started.
    # 2. After the dispVM starts, the submission is played in Audacious
    # 3. Sound is audible
    # 4. when Audacious is closed, the dispVM shuts down

    # For a video submission:
    # 1. when the submission filename is clicked, a dispVM is started.
    # 2. After the dispVM starts, the submission is played in Totem
    # 3. Sound is audible if applicable
    # 4. when Totem is closed, the dispVM shuts down

    # For a compressed (archive) submission:
    # 1. when the submission filename is clicked, a dispVM is started.
    # 2. After the dispVM starts, the submission is opened in FileRoller
    # 3. Individual files can be extracted and previewed
    # 4. when FileRoller is closed, the dispVM shuts down

}

sub test_desktop {
    assert_and_dclick("securedrop-inbox-click-desktop-icon");
    assert_screen("securedrop-inbox-type-username", timeout => 60);
}

sub test_legacy_client {
    assert_and_click('menu');
    assert_and_click("menu-qubes-tools");
    if (match_has_tag("new-menu")) {
        assert_and_click("menu-other-submenu");
    }
    if (assert_screen("legacy-client-listed")) {
        die "legacy-client was found";
    }
    send_key('esc');
}


sub run {
    my ($self) = @_;

    $self->select_root_console;  # Use root console to speed things along
    test_menu_shortcuts;

    prepare_test;

    $self->select_gui_console; # Switch back to GUI for GUI operations

    test_login;
    assert_and_click("securedrop-inbox-welcome-screen");
    test_sources;
    test_replies;
    test_submissions;
    test_close;
    test_desktop;

};

sub post_fail_hook {
    my $self = shift;

    # NOTE: Run at the end because some may fail and just abort execution
    $self->SUPER::post_fail_hook();
};


1;
