#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Tor Browser — proot 내부 설치 (arm64 포트)

_TOR_VER="13.0.9"
_TOR_URL="https://sourceforge.net/projects/tor-browser-ports/files/${_TOR_VER}/tor-browser-linux-arm64-${_TOR_VER}.tar.xz/download"

app_install_tor_browser() {
    proot_pkg_update
    proot_pkg_install curl

    proot_exec bash -c "
        curl -L '${_TOR_URL}' -o tor.tar.xz
        tar -xJf tor.tar.xz
        sudo mv tor-browser /opt/tor-browser
        rm -f tor.tar.xz
    "

    desktop_register "tor" "Tor Browser" \
        "prun /opt/tor-browser/Browser/start-tor-browser --no-sandbox" \
        "tor" "Network;WebBrowser;Security;"
}

app_remove_tor_browser() {
    proot_exec sudo rm -rf /opt/tor-browser
    desktop_remove "tor"
}

app_is_installed_tor_browser() {
    desktop_is_registered "tor"
}
