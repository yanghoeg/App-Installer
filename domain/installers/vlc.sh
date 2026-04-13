#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: VLC — Termux native

app_install_vlc() {
    termux_pkg_install vlc
    desktop_register "vlc" "VLC media player" "vlc --no-cli" "vlc" \
        "AudioVideo;Player;Recorder;" \
        "MimeType=video/mpeg;video/x-avi;audio/mpeg;"
}

app_remove_vlc() {
    termux_pkg_remove vlc
    desktop_remove "vlc"
}

app_is_installed_vlc() {
    desktop_is_registered "vlc"
}
