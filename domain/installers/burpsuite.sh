#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Burp Suite Community — proot 내부 설치 (arm64 바이너리, distro-agnostic)

# 버전 핀 + sha256 — 버전을 올릴 때 sha256sum으로 상수를 갱신할 것.
_BURP_VER="2024.11.2"
_BURP_URL="https://portswigger.net/burp/releases/startdownload?product=community&version=${_BURP_VER}&type=linuxarm64"
_BURP_SHA256="74598bce250d58ccaedac2e81c9dc88a7f235f3c637f8e40c92652605f9442ab"

app_install_burpsuite() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1
    proot_exec bash -c "$(fetch_verified_src)"$'\n''
        set -e
        fetch_verified "$1" /tmp/burpsuite.sh "$2"
        chmod +x /tmp/burpsuite.sh
        /tmp/burpsuite.sh -q
        rm -f /tmp/burpsuite.sh
    ' _ "$_BURP_URL" "$_BURP_SHA256" || { echo "[ERROR] Burp Suite 설치 실패" >&2; return 1; }

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
