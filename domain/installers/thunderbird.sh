#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Thunderbird — Termux native

app_install_thunderbird() {
    termux_pkg_install thunderbird
    desktop_register "thunderbird" "Thunderbird" "thunderbird %u" "thunderbird" \
        "Network;Email;News;" \
        "MimeType=message/rfc822;x-scheme-handler/mailto;"
}

app_remove_thunderbird() {
    termux_pkg_remove thunderbird
    desktop_remove "thunderbird"
}

app_is_installed_thunderbird() {
    termux_pkg_is_installed thunderbird && desktop_is_registered "thunderbird"
}
