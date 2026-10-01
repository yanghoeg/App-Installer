#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: DBeaver CE — proot 내부 설치
# The official Linux archive contains its own Java runtime.
_DBEAVER_VER="26.2.1"
_DBEAVER_URL="https://github.com/dbeaver/dbeaver/releases/download/${_DBEAVER_VER}/dbeaver-ce-${_DBEAVER_VER}-linux-aarch64.tar.gz"
_DBEAVER_SHA256="76fad1d9064d0edadadf7ac811b33b675eca797a108dc46a8e382da22399cc8e"

app_install_dbeaver() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1

    proot_exec bash -c "$(fetch_verified_src)"$'\n''
        set -e
        fetch_verified "$1" /tmp/dbeaver.tar.gz "$2"
        tar -xzf /tmp/dbeaver.tar.gz -C /tmp
        sudo rm -rf /opt/dbeaver
        sudo mv /tmp/dbeaver /opt/
        sudo ln -sf /opt/dbeaver/dbeaver /usr/bin/dbeaver
        rm -f /tmp/dbeaver.tar.gz
        test -x /opt/dbeaver/dbeaver
    ' _ "$_DBEAVER_URL" "$_DBEAVER_SHA256" || { echo "[ERROR] DBeaver 다운로드/설치 실패" >&2; return 1; }

    desktop_register_proot "dbeaver" "DBeaver" "/usr/bin/dbeaver" \
        "dbeaver" "Development;Database;" || return 1
}

app_remove_dbeaver() {
    proot_exec sudo rm -f /usr/bin/dbeaver || return 1
    proot_exec sudo rm -rf /opt/dbeaver || return 1
    proot_pkg_autoremove || return 1
    desktop_remove "dbeaver"
}

app_is_installed_dbeaver() {
    desktop_is_registered "dbeaver"
}
