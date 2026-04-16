#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Burp Suite Community — Termux native (tur-packages)
# tur-repo가 메인 install.sh의 _setup_termux_repos에서 이미 활성화되어 있음.

app_install_burpsuite() {
    termux_pkg_install burpsuite
    desktop_register "burpsuite" "Burp Suite Community" "burpsuite" "burpsuite" \
        "Network;Security;"
}

app_remove_burpsuite() {
    termux_pkg_remove burpsuite
    desktop_remove "burpsuite"
}

app_is_installed_burpsuite() {
    termux_pkg_is_installed burpsuite && desktop_is_registered "burpsuite"
}
