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


sub prepare_test {
    # Any preparations needed for the test

    assert_script_run('sudo mkdir -p /usr/share/securedrop-workstation-dom0-config/');
    assert_script_run('echo {\"submission_key_fpr\": \"65A1B5FF195B56353CC63DFFCC40EF1228271441\", \"hidserv\": {\"hostname\": \"tcema7oxk52gmxm2yjs5hbc2ird54f7wid3i3tec7fojcvbtalctkkqd.onion\", \"key\": \"QBZV7Y3MWXCOLEZOLMQEJYICYQBGTPNERRIMANKSA2T6F3SATRZA\"}, \"environment\": \"prod\", \"vmsizes\": {\"sd_app\": 10, \"sd_log\": 5}} | sudo tee /usr/share/securedrop-workstation-dom0-config/config.json');
    assert_script_run("echo 'copy_config()' | (cd /usr/bin/ && python3 -i sdw-admin --validate)");

    # Shut down sd-proxy for its credentials to be applied on boot
    assert_script_run('qvm-kill sd-proxy');

    # Reapply due to secrets change
    assert_script_run("sudo qubesctl --targets dom0 state.highstate || true", timeout => 1000);

    assert_script_run("qvm-start sd-proxy");
    assert_script_run("qvm-start sd-app");  # HACK pre-start sd-app for run-client timings to work

    # make sure time is the same or TOTP won't work out (borrowed from aem.pm)
    assert_script_run("date -s @" . time());

    # DEBUG COMMANDS
    script_run('echo debug-curl-onion && qvm-run -p sd-proxy "curl --proxy socks5h://localhost:9150 \$(qubesdb-read /vm-config/SD_PROXY_ORIGIN)"', timeout => 20);
    script_run('qvm-run -p sd-proxy "sudo journalctl -u tor"');

}

sub test_login {
    x11_start_program('qvm-run --service sd-app qubes.StartApp+press.freedom.SecureDropClient', target_match => "securedrop-client-login");

    # Username
    assert_and_click("securedrop-client-type-username");
    type_string("journalist");
    send_key('tab');

    # Password
    type_string("correct horse battery staple profanity oil chewy");
    send_key('tab'); # switches to "[ ] show passphrase"
    send_key('tab'); # switches to TOTP field


    # TOTP code
    my $totp = generate_totp("JHCOGO7VCER3EJ4L");
    type_string("$totp");
    send_key('ret');
};


sub test_sources {
    ##
    # AFTER VALID LOGIN
    ##

    # When the client receives messages from the server but they are encrypted
    assert_and_click("securedrop-client-encrypted-source-messages", timeout => 30);
    # TODO add OCR

    # User is prompted for GPG key access
    # assert_and_click("securedrop-sd-gpg-prompt");

    # Source messages are decrypted
    assert_screen("securedrop-client-decrypted-source-messages", timeout => 30);
    # TODO add OCR

    # The source list is displayed but no sources are selected by default and
    # the conversation view is not populated.
    assert_screen("securedrop-client-no-source-selected");


    ##
    # WHEN A SOURCE IS SELECTED IN THE SOURCE LIST
    ##

    # conversation view is populated with source conversation
    assert_and_click("securedrop-client-source-open");

    # a source message containing HTML is displayed as unformatted text
    assert_screen("securedrop-client-source-conversation");


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
    assert_and_click("securedrop-client-source-menu-open");
    assert_and_click("securedrop-client-source-menu-delete-source");
    assert_and_click("securedrop-client-source-menu-delete-source-confirm");
    assert_screen("securedrop-client-no-source-selected"); # after deletion selection is empty

    # 2. the source is deleted from the server and not restored on next sync
    # TODO
    # 3. source submissions and messages are removed from the client's data directory
    # TODO

    ###
    ## STARRING A SOURCE
    ###
    # the client is closed and reopened in Online mode:
    # TODO
    # - the source is still starred in the source list
    # TODO
};

sub test_replies {
    # When a source is selected in the source list:
    assert_and_click("securedrop-client-source-open");

    # 1. the reply panel is available for use and there is no message asking the
    #    user to sign in
    assert_and_click("securedrop-client-online-mode-source-reply-box");

    # 2. a reply can be added to the conversation
    type_string("Some reply text <b>this is not bold</b>");
    assert_and_click("securedrop-client-online-mode-source-reply-send");

    # 3. a pending reply can be added to the conversation (ie., by disconnecting
    #    the network or shutting down sd-whonix just before sending a reply)
    # TODO

    # 4. a reply containing HTML is displayed as unformatted text
    assert_screen("securedrop-client-online-mode-source-reply-is-unformatted");

    # 5. a reply with a single string of characters longer than 100 chars is
    #    displayed, but truncated
    assert_and_click("securedrop-client-online-mode-source-reply-box");
    type_string("verylongstringofcharacterswithoutanyspacesinitwillactuallybetruncatedotherwiseitisabugisitnot?");
    assert_and_click("securedrop-client-online-mode-source-reply-send");

    # 6. a reply with a line longer than 100 chars is displayed correctly
    # TODO

    # 7. two replies added immediately after each other are ordered correctly
    # TODO
};

sub test_submissions {
    assert_and_click("securedrop-client-source-open");

    # when Download is clicked on a submission:
    # 1. the submission is downloaded and decrypted
    assert_and_click("securedrop-client-attachment-download");
    # 2. the Download button is replaced with Print and Export options
    assert_screen("securedrop-client-attachment-print");
    assert_screen("securedrop-client-attachment-export");
    # 3. the submission filename is displayed.
    assert_screen("securedrop-client-attachment-filename");

    # text submission (NOTE: not in original test plan)
    # 1. when the submission filename is clicked, a disposable VM (dispVM) is started.
    assert_and_click("securedrop-client-attachment-filename");
    # 2. after the dispVM starts, the submission is displayed in text editor
    assert_and_click("securedrop-client-attachment-disposable-opens");
    # 3. text editor is closed, the dispVM shuts down
    assert_and_click("securedrop-client-attachment-disposable-close-window");
    assert_and_click("securedrop-client-attachment-filename"); # back to the conversation view

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


sub run {
    my ($self) = @_;

    $self->select_root_console;  # Use root console to speed things along

    prepare_test;

    $self->select_gui_console; # Switch back to GUI for GUI operations

    test_login;
    test_sources;
    test_replies;
    test_submissions;

};

1;
