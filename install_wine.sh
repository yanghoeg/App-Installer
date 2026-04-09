#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
# =============================================================================
# install_wine.sh — Box64 + Wine-Staging 설치
# -----------------------------------------------------------------------------
# 감지 로직:
#   proot 있음 → proot 내부 Box64 + Wine-Staging tarball (안정적)
#   proot 없음 → glibc-runner + box64-glibc + Wine-Staging tarball
#
# Wine 소스: Kron4ek/Wine-Builds (wine-staging, x86_64)
# Box64 소스: ptitSeb/box64 (ARM64 네이티브)
# =============================================================================

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"

PROOT_DISTRO="${PROOT_DISTRO:-}"
PROOT_USER="${PROOT_USER:-}"
ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}"

WINE_DESKTOP="${PREFIX}/share/applications/wine64.desktop"
WINECFG_DESKTOP="${PREFIX}/share/applications/winecfg.desktop"
WINE_BIN="${PREFIX}/bin/wine"
WINE_NATIVE_DIR="$HOME/.wine-staging"   # no-proot 경로

_prun() {
    proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- \
        env DISPLAY=:1.0 \
            MESA_LOADER_DRIVER_OVERRIDE=zink \
            TU_DEBUG=noconform \
            ZINK_DESCRIPTORS=lazy \
            MESA_NO_ERROR=1 \
        "$@"
}

# -----------------------------------------------------------------------------
# 공통: Wine-Staging 최신 tarball URL (Kron4ek/Wine-Builds)
# -----------------------------------------------------------------------------
_wine_tarball_url() {
    local ver
    ver=$(curl -sf "https://api.github.com/repos/Kron4ek/Wine-Builds/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "9.22")
    echo "https://github.com/Kron4ek/Wine-Builds/releases/download/${ver}/wine-${ver}-staging-amd64.tar.xz"
}

# -----------------------------------------------------------------------------
# proot Ubuntu: Box64 + Wine-Staging
# -----------------------------------------------------------------------------
_install_proot_ubuntu() {
    echo "[Wine] proot Ubuntu: Box64 + Wine-Staging 설치"

    # 이미 설치된 경우 건너뜀
    if _prun which wine &>/dev/null 2>&1; then
        echo "[Wine] 이미 설치되어 있습니다. 건너뜁니다."
        return 0
    fi

    # Ubuntu 코드명 감지 (jammy / noble 등)
    local codename
    codename=$(grep "^VERSION_CODENAME=" "${ROOTFS}/etc/os-release" 2>/dev/null \
        | cut -d= -f2 | tr -d '"' || echo "jammy")

    # Box64 ARM64 deb 설치
    local box64_tag
    box64_tag=$(curl -sf "https://api.github.com/repos/ptitSeb/box64/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "")

    if [ -n "$box64_tag" ]; then
        local box64_url="https://github.com/ptitSeb/box64/releases/download/${box64_tag}/box64_Ubuntu_${codename}_arm64.deb"
        _prun sudo bash -c "
            wget -q '${box64_url}' -O /tmp/box64.deb 2>/dev/null && \
            dpkg -i /tmp/box64.deb && rm -f /tmp/box64.deb && \
            echo '[Box64] 설치 완료'
        " || _prun sudo apt install -y box64 2>/dev/null || \
            echo "[WARN] Box64 설치 실패 — 진행 계속"
    else
        _prun sudo apt install -y box64 2>/dev/null || \
            echo "[WARN] Box64 설치 실패 — 진행 계속"
    fi

    # Wine-Staging tarball → /opt/wine-staging
    local wine_url
    wine_url=$(_wine_tarball_url)
    echo "[Wine] wine-staging 다운로드 중... (수분 소요)"
    _prun sudo bash -c "
        mkdir -p /opt/wine-staging
        wget -q '${wine_url}' -O /tmp/wine-staging.tar.xz
        tar -xJf /tmp/wine-staging.tar.xz -C /opt/wine-staging --strip-components=1
        rm -f /tmp/wine-staging.tar.xz
        for bin in wine wine64 wineboot winecfg wineserver msiexec regedit; do
            [ -f /opt/wine-staging/bin/\$bin ] && \
                ln -sf /opt/wine-staging/bin/\$bin /usr/local/bin/\$bin || true
        done
        echo '[Wine] wine-staging 설치 완료'
    "

    # winetricks
    _prun sudo bash -c "
        apt install -y winetricks 2>/dev/null || \
        { wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
              -O /usr/local/bin/winetricks && chmod +x /usr/local/bin/winetricks
          echo '[winetricks] 설치 완료'; }
    " 2>/dev/null || true

    # WINEPREFIX 초기화
    echo "[Wine] WINEPREFIX 초기화 중..."
    _prun bash -c "WINEPREFIX=\$HOME/.wine WINEDEBUG=-all wine wineboot --init 2>/dev/null || true" || true
}

# -----------------------------------------------------------------------------
# proot Arch: Box64 (Chaotic-AUR) + Wine-Staging tarball
# -----------------------------------------------------------------------------
_install_proot_arch() {
    echo "[Wine] proot Arch: Box64 + Wine-Staging 설치"

    # 이미 설치된 경우 건너뜀
    if _prun which wine &>/dev/null 2>&1; then
        echo "[Wine] 이미 설치되어 있습니다. 건너뜁니다."
        return 0
    fi

    # Box64 — Chaotic-AUR 우선, 없으면 GitHub 바이너리
    _prun sudo bash -c "
        pacman -S --noconfirm box64 2>/dev/null && echo '[Box64] pacman 설치 완료' && exit 0

        # Chaotic-AUR 추가
        pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null || true
        pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
        pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' 2>/dev/null || true
        grep -q '\[chaotic-aur\]' /etc/pacman.conf 2>/dev/null || \
            printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> /etc/pacman.conf
        pacman -Sy --noconfirm box64 2>/dev/null && echo '[Box64] Chaotic-AUR 설치 완료' || \
            echo '[WARN] Box64 설치 실패 — 진행 계속'
    " 2>/dev/null || true

    # Arch는 multilib가 x86_64 전용 → Wine-Staging tarball 사용
    local wine_url
    wine_url=$(_wine_tarball_url)
    echo "[Wine] wine-staging 다운로드 중... (수분 소요)"
    _prun sudo bash -c "
        mkdir -p /opt/wine-staging
        wget -q '${wine_url}' -O /tmp/wine-staging.tar.xz
        tar -xJf /tmp/wine-staging.tar.xz -C /opt/wine-staging --strip-components=1
        rm -f /tmp/wine-staging.tar.xz
        for bin in wine wine64 wineboot winecfg wineserver msiexec regedit; do
            [ -f /opt/wine-staging/bin/\$bin ] && \
                ln -sf /opt/wine-staging/bin/\$bin /usr/local/bin/\$bin || true
        done
        echo '[Wine] wine-staging 설치 완료'
    "

    # winetricks
    _prun sudo bash -c "
        pacman -S --noconfirm winetricks 2>/dev/null || \
        { wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
              -O /usr/local/bin/winetricks && chmod +x /usr/local/bin/winetricks
          echo '[winetricks] 설치 완료'; }
    " 2>/dev/null || true

    # WINEPREFIX 초기화
    echo "[Wine] WINEPREFIX 초기화 중..."
    _prun bash -c "WINEPREFIX=\$HOME/.wine WINEDEBUG=-all wine wineboot --init 2>/dev/null || true" || true
}

# -----------------------------------------------------------------------------
# no-proot: glibc-runner + box64-glibc + Wine-Staging
# -----------------------------------------------------------------------------
_install_wine_native() {
    echo "[Wine] Termux native: glibc-runner + box64-glibc + Wine-Staging"

    # 이미 설치된 경우 건너뜀
    if [ -d "$WINE_NATIVE_DIR" ] && [ -f "$WINE_BIN" ]; then
        echo "[Wine] 이미 설치되어 있습니다. 건너뜁니다."
        return 0
    fi

    # glibc-repo + 핵심 패키지
    pkg install -y glibc-repo
    pkg install -y glibc-runner box64-glibc

    # GPU/X11/audio (glibc 빌드)
    for p in \
        mesa-zink-glibc vulkan-volk-glibc mesa-vulkan-icd-freedreno-glibc \
        pulseaudio-glibc \
        libxcb-glibc libxext-glibc libxrender-glibc libxfixes-glibc \
        libxcursor-glibc libxinerama-glibc libice-glibc libsm-glibc \
        libgcrypt-glibc libgpg-error-glibc
    do
        pkg install -y "$p" 2>/dev/null || true
    done

    # Wine-Staging tarball → ~/.wine-staging
    local wine_url
    wine_url=$(_wine_tarball_url)
    echo "[Wine] wine-staging 다운로드 중... (수분 소요)"
    mkdir -p "$WINE_NATIVE_DIR"
    wget -q "$wine_url" -O /tmp/wine-staging.tar.xz
    tar -xJf /tmp/wine-staging.tar.xz -C "$WINE_NATIVE_DIR" --strip-components=1
    rm -f /tmp/wine-staging.tar.xz
    echo "[Wine] wine-staging 설치 완료"

    # grun 래퍼 스크립트
    cat > "$WINE_BIN" << WRAPEOF
#!/data/data/com.termux/files/usr/bin/bash
export DISPLAY="\${DISPLAY:-:1.0}"
export MESA_LOADER_DRIVER_OVERRIDE="\${MESA_LOADER_DRIVER_OVERRIDE:-zink}"
export TU_DEBUG=noconform
export ZINK_DESCRIPTORS=lazy
export MESA_NO_ERROR=1
export WINEDEBUG="\${WINEDEBUG:--all}"
exec grun "\$HOME/.wine-staging/bin/wine64" "\$@"
WRAPEOF
    chmod +x "$WINE_BIN"

    # WINEPREFIX 초기화
    DISPLAY=:1.0 wine wineboot --init 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Termux 래퍼 + .desktop 파일 생성
# -----------------------------------------------------------------------------
_create_launchers() {
    if [ -n "$PROOT_DISTRO" ] && [ -d "$ROOTFS" ]; then
        # proot 방식: Termux wine 명령 → proot 내부 wine 실행
        cat > "$WINE_BIN" << WRAPEOF
#!/data/data/com.termux/files/usr/bin/bash
# Wine proot 래퍼 — XFCE에서 .exe 파일을 열 때 사용
proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- \\
    env DISPLAY=:1.0 \\
        MESA_LOADER_DRIVER_OVERRIDE=zink \\
        TU_DEBUG=noconform \\
        ZINK_DESCRIPTORS=lazy \\
        MESA_NO_ERROR=1 \\
        WINEDEBUG=-all \\
    wine "\$@"
WRAPEOF
        chmod +x "$WINE_BIN"
    fi

    # XFCE 메뉴: Wine (파일 연결)
    cat > "$WINE_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine
GenericName=Windows 호환 레이어
Comment=Windows 프로그램 실행 (Box64 + Wine-Staging)
Exec=wine %f
Icon=wine
Categories=System;Emulator;
MimeType=application/x-ms-dos-executable;application/x-msi;
StartupNotify=true
NoDisplay=false
EOF

    # XFCE 메뉴: Wine 설정
    cat > "$WINECFG_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine 설정
Comment=Wine 환경 구성 (winecfg)
Exec=wine winecfg
Icon=wine-winecfg
Categories=System;Emulator;
StartupNotify=true
EOF

    echo "[Wine] 실행기 및 메뉴 항목 생성 완료"
}

# -----------------------------------------------------------------------------
# 메인
# -----------------------------------------------------------------------------
main() {
    if [ -n "$PROOT_DISTRO" ] && [ -d "$ROOTFS" ]; then
        echo "[Wine] proot 감지: ${PROOT_DISTRO} (user: ${PROOT_USER})"
        case "$PROOT_DISTRO" in
            ubuntu)    _install_proot_ubuntu ;;
            archlinux) _install_proot_arch ;;
            *)
                echo "[ERROR] 지원되지 않는 distro: ${PROOT_DISTRO}"
                exit 1 ;;
        esac
    else
        echo "[Wine] proot 없음: Termux native (glibc-runner) 방식"
        _install_wine_native
    fi

    _create_launchers

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Wine 설치 완료"
    echo "  wine program.exe     — Windows 앱 실행"
    echo "  wine winecfg         — Wine 설정"
    echo "  winetricks           — DLL·런타임 설치 도구"
    echo "  GALLIUM_HUD=fps wine — FPS 오버레이"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
