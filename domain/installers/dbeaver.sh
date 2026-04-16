#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: DBeaver CE — proot 내부 설치
# JDK 패키지명 차이(openjdk-21-jdk vs jdk-openjdk)는 adapter가 흡수

app_install_dbeaver() {
    proot_pkg_update
    proot_dep "jdk"

    proot_exec bash -c "
        wget 'https://github.com/dbeaver/dbeaver/releases/download/24.3.1/dbeaver-ce-24.3.1-linux.gtk.aarch64-nojdk.tar.gz' \
            -O dbeaver.tar.gz
        tar -xzf dbeaver.tar.gz
        sudo mv dbeaver /opt/
        sudo ln -sf /opt/dbeaver/dbeaver /usr/bin/dbeaver
        rm -f dbeaver.tar.gz
    "

    desktop_register "dbeaver" "DBeaver" \
        "prun dbeaver --no-sandbox" \
        "dbeaver" "Development;Database;"
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
