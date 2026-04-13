#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Burp Suite Community — proot 내부 설치 (arm64 바이너리, distro-agnostic)

app_install_burpsuite() {
    proot_pkg_update
    proot_exec curl -L -o burpsuite_community_linux_arm64.sh \
        'https://portswigger.net/burp/releases/startdownload?product=community&version=2024.11.2&type=linuxarm64'
    proot_exec chmod +x burpsuite_community_linux_arm64.sh
    proot_exec sudo ./burpsuite_community_linux_arm64.sh
    proot_exec rm -f ./burpsuite_community_linux_arm64.sh

    desktop_register "burpsuite" "Burp Suite Community" \
        'bash -c "prun BurpSuiteCommunity </dev/null >/dev/null 2>&1 &"' \
        "burpsuite" "Security;Network;"
}

app_remove_burpsuite() {
    proot_exec sudo /opt/BurpSuiteCommunity/uninstall 2>/dev/null || true
    desktop_remove "burpsuite"
}

app_is_installed_burpsuite() {
    desktop_is_registered "burpsuite"
}
