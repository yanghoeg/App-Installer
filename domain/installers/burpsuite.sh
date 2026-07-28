#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Burp Suite Community — proot 내부 설치 (arm64 바이너리, distro-agnostic)

app_install_burpsuite() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1
    proot_exec bash -c "
        set -e
        curl -fL -o /tmp/burpsuite.sh \
            'https://portswigger.net/burp/releases/startdownload?product=community&version=2024.11.2&type=linuxarm64'
        chmod +x /tmp/burpsuite.sh
        /tmp/burpsuite.sh -q
        rm -f /tmp/burpsuite.sh
    " || { echo "[ERROR] Burp Suite 설치 실패" >&2; return 1; }

    desktop_register "burpsuite" "Burp Suite Community" \
        'bash -c "prun BurpSuiteCommunity </dev/null >/dev/null 2>&1 &"' \
        "burpsuite" "Security;Network;"
}

app_remove_burpsuite() {
    # installer puts it in user's home dir, uninstall script there
    proot_exec bash -c "
        if [ -f ~/BurpSuiteCommunity/uninstall ]; then
            ~/BurpSuiteCommunity/uninstall -q 2>/dev/null || true
        fi
        rm -rf ~/BurpSuiteCommunity
        sudo rm -f /usr/local/bin/BurpSuiteCommunity
    " 2>/dev/null || true
    desktop_remove "burpsuite"
}

app_is_installed_burpsuite() {
    desktop_is_registered "burpsuite"
}
