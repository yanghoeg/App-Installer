#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: DBeaver CE — proot 내부 설치
# JDK 패키지명 차이(openjdk-21-jdk vs jdk-openjdk)는 adapter가 흡수

app_install_dbeaver() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1
    proot_pkg_install_jdk || return 1

    proot_exec bash -c "
        set -e
        wget 'https://github.com/dbeaver/dbeaver/releases/download/26.2.0/dbeaver-ce-26.2.0-linux-aarch64.tar.gz' \
            -O /tmp/dbeaver.tar.gz
        tar -xzf /tmp/dbeaver.tar.gz -C /tmp
        sudo rm -rf /opt/dbeaver
        sudo mv /tmp/dbeaver /opt/
        sudo ln -sf /opt/dbeaver/dbeaver /usr/bin/dbeaver
        rm -f /tmp/dbeaver.tar.gz
        test -x /opt/dbeaver/dbeaver
    " || { echo "[ERROR] DBeaver 다운로드/설치 실패" >&2; return 1; }

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
