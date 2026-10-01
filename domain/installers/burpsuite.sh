#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Burp Suite Community — proot 내부 설치 (arm64 바이너리, distro-agnostic)

# PortSwigger 2026.8 stable Linux ARM64 installer. Since 2026.4 one official
# installer serves Community and Professional; Community remains selectable at launch.
_BURP_VER="2026.8"
_BURP_URL="https://portswigger.net/burp/releases/startdownload?product=desktop&type=linuxarm64&version=${_BURP_VER}"
_BURP_SHA256="be178ca87781760c02b091af2c5ef3af5079c312f289d0049a9082e0938a5d7f"

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

    desktop_register_proot "burpsuite" "Burp Suite Community" "BurpSuite" \
        "burpsuite" "Security;Network;"
}

app_remove_burpsuite() {
    # installer puts it in user's home dir, uninstall script there
    if has_proot_distro; then
        proot_exec bash -c '
        set -e
        for dir in ~/BurpSuite ~/BurpSuiteCommunity; do
            [ -f "$dir/uninstall" ] && "$dir/uninstall" -q
            rm -rf "$dir"
        done
        sudo rm -f /usr/local/bin/BurpSuite /usr/local/bin/BurpSuiteCommunity
        ' || return 1
    fi
    desktop_remove "burpsuite"
}

app_is_installed_burpsuite() {
    desktop_is_registered "burpsuite"
}
