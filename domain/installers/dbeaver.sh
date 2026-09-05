#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: DBeaver CE — proot 내부 설치
# JDK 패키지명 차이(openjdk-21-jdk vs jdk-openjdk)는 adapter가 흡수

# 버전 핀 + sha256 — 버전을 올릴 때 sha256sum으로 상수를 갱신할 것.
_DBEAVER_VER="26.2.0"
_DBEAVER_URL="https://github.com/dbeaver/dbeaver/releases/download/${_DBEAVER_VER}/dbeaver-ce-${_DBEAVER_VER}-linux-aarch64.tar.gz"
_DBEAVER_SHA256="6ada803a39c072fc8f1c7770669298e92a3501744a6e1ff919794a0dedf95963"

app_install_dbeaver() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1
    proot_pkg_install_jdk || return 1

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

    desktop_register "dbeaver" "DBeaver" \
        'bash -c "prun dbeaver --no-sandbox </dev/null >/dev/null 2>&1 &"' \
        "dbeaver" "Development;Database;" || return 1
}

app_remove_dbeaver() {
    proot_exec sudo rm -f /usr/bin/dbeaver 2>/dev/null || true
    proot_exec sudo rm -rf /opt/dbeaver 2>/dev/null || true
    proot_pkg_autoremove
    desktop_remove "dbeaver"
}

app_is_installed_dbeaver() {
    desktop_is_registered "dbeaver"
}
