#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Audacity — Termux native (x11-repo)

app_install_audacity() {
    termux_pkg_install audacity
    desktop_register "audacity" "Audacity" "audacity %U" "audacity" \
        "AudioVideo;Audio;AudioVideoEditing;" \
        "MimeType=audio/x-wav;audio/x-aiff;audio/x-flac;application/x-audacity-project;"
}

app_remove_audacity() {
    termux_pkg_remove audacity
    desktop_remove "audacity"
}

app_is_installed_audacity() {
    desktop_is_registered "audacity"
}
