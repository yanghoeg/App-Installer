#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Thorium Browser — proot 내부 설치
# arm64 .deb 직접 추출 방식 (AUR thorium은 x86 only, Ubuntu apt도 충돌)

_THORIUM_DEB_URL="https://github.com/Alex313031/Thorium-Raspi/releases/download/M138.0.7204.303/thorium-browser_138.0.7204.303_arm64.deb"
_THORIUM_DEB_SHA256="c6eba5536cde23659e2a7f60ae003d2cc29ac456fbb804ad18a602f5d0d80035"

app_install_thorium() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    # Extract without registering a package: this avoids Ubuntu dependency conflicts
    # and works with dpkg-deb even when binutils/ar is absent.
    proot_exec sudo bash -c "$(fetch_verified_src)"$'\n''
        set -e
        stage=$(mktemp -d /tmp/thorium.XXXXXX)
        trap '"'"'rm -rf "$stage"'"'"' EXIT
        fetch_verified "$1" "$stage/thorium.deb" "$2"

        if command -v dpkg-deb >/dev/null 2>&1; then
            dpkg-deb -x "$stage/thorium.deb" /
        elif command -v ar >/dev/null 2>&1; then
            mkdir "$stage/extract"
            cd "$stage/extract"
            ar x "$stage/thorium.deb"
            data_tar=$(find . -maxdepth 1 -name "data.tar.*" -print -quit)
            test -n "$data_tar"
            tar -xf "$data_tar" -C /
            cd /
        else
            echo "[ERROR] Thorium 압축 해제에 dpkg-deb 또는 ar이 필요합니다." >&2
            exit 1
        fi
        command -v thorium-browser >/dev/null
    ' _ "$_THORIUM_DEB_URL" "$_THORIUM_DEB_SHA256" || { echo "[ERROR] Thorium 다운로드/설치 실패" >&2; return 1; }

    desktop_register_proot "thorium-browser" "Thorium" \
        'thorium-browser --no-sandbox' \
        "thorium-browser" "Network;" || return 1
}

app_remove_thorium() {
    # Older installers used dpkg -i when ar was absent. Remove that registration
    # before cleaning files from both the registered and extraction-only installs.
    if has_proot_distro; then
        proot_exec sudo bash -c '
        set -e
        if command -v dpkg-query >/dev/null 2>&1; then
            query_rc=0
            state=$(dpkg-query -W -f="\${db:Status-Status}" thorium-browser 2>/dev/null) || query_rc=$?
            case "$query_rc" in
                0) ;;
                1) state= ;; # package absent
                *) echo "[ERROR] Thorium 패키지 상태 조회 실패" >&2; exit "$query_rc" ;;
            esac
            if [ -n "$state" ] && [ "$state" != not-installed ]; then
                dpkg --purge thorium-browser
            fi
        fi
        rm -rf /opt/chromium.org/thorium
        rm -f /usr/bin/thorium-browser /usr/sbin/thorium-browser
        rm -f /usr/share/applications/thorium-browser.desktop
        rm -f /usr/share/icons/hicolor/*/apps/thorium-browser.png
        ' || return 1
    fi
    desktop_remove "thorium-browser"
}

app_is_installed_thorium() {
    desktop_is_registered "thorium-browser"
}
