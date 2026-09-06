#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Audacity — Termux native (x11-repo)

app_install_audacity() {
    termux_pkg_enable_repo x11-repo || return 1
    termux_pkg_install audacity || return 1
    desktop_register "audacity" "Audacity" "audacity %U" "audacity" \
        "AudioVideo;Audio;AudioVideoEditing;" \
        "MimeType=audio/x-wav;audio/x-aiff;audio/x-flac;application/x-audacity-project;"
}

app_remove_audacity() {
    termux_pkg_remove audacity
    desktop_remove "audacity"
}

app_is_installed_audacity() {
    termux_pkg_is_installed audacity && desktop_is_registered "audacity"
}
