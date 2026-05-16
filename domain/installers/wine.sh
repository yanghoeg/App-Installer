#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: Wine — Box64 + Wine-Staging
# =============================================================================
# proot 있음 → proot 내부 Box64 + Wine-Staging (adapter가 distro 차이 흡수)
# proot 없음 → Termux native (glibc-runner + box64-glibc)

_WINE_BIN="${PREFIX}/bin/wine"
_WINE_DESKTOP="${PREFIX}/share/applications/wine64.desktop"
_WINECFG_DESKTOP="${PREFIX}/share/applications/winecfg.desktop"
_WINE_APPS_DESKTOP="${PREFIX}/share/applications/wine-apps.desktop"
_WINE_NATIVE_DIR="${HOME}/.wine-staging"

# GitHub Releases에서 최신 Wine-Staging URL 조회
_wine_tarball_url() {
    local ver
    ver=$(curl -sf "https://api.github.com/repos/Kron4ek/Wine-Builds/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "9.22")
    echo "https://github.com/Kron4ek/Wine-Builds/releases/download/${ver}/wine-${ver}-staging-amd64.tar.xz"
}

# proot 내부: Wine-Staging tarball 설치
# binfmt_misc 없는 proot 환경 대응:
#   1. wine ELF를 wine.elf로 저장
#   2. wine 스크립트가 box64를 통해 wine.elf 실행
#   3. wineserver.elf도 동일하게 처리
_wine_install_tarball_proot() {
    local wine_url
    wine_url=$(_wine_tarball_url)
    echo "[Wine] wine-staging 다운로드 중... (수분 소요)"
    proot_exec_wine sudo bash -c "
        mkdir -p /opt/wine-staging
        wget -q '${wine_url}' -O /tmp/wine-staging.tar.xz
        tar -xJf /tmp/wine-staging.tar.xz -C /opt/wine-staging --strip-components=1
        rm -f /tmp/wine-staging.tar.xz

        # x86-64 ELF를 .elf/ 서브디렉토리로 이동 후 box64 wrapper 생성
        # argv[0] 보존: box64가 basename(경로)="wine"을 argv[0]으로 전달
        cd /opt/wine-staging/bin
        mkdir -p .elf
        for f in wine wine64 wineserver wineboot winedbg; do
            if [ -f \"\$f\" ] && file \"\$f\" 2>/dev/null | grep -q 'x86-64'; then
                mv \"\$f\" \".elf/\$f\"
                printf '#!/bin/bash\nexec box64 /opt/wine-staging/bin/.elf/%s \"\$@\"\n' \"\$f\" > \"\$f\"
                chmod +x \"\$f\"
            fi
        done
        # ELF의 상대경로 ../lib, ../share 가 올바른 위치를 가리키도록 symlink
        ln -sf ../lib /opt/wine-staging/bin/lib
        ln -sf ../share /opt/wine-staging/bin/share

        # /usr/local/bin 심링크 (symlink 방식 대신 직접 복사 — cat으로 덮어써지는 문제 방지)
        for bin in wine wine64 wineboot winecfg wineserver msiexec regedit winetricks; do
            [ -f /opt/wine-staging/bin/\$bin ] && \
                ln -sf /opt/wine-staging/bin/\$bin /usr/local/bin/\$bin || true
        done
    "
}

# proot 내부: winetricks 설치
_wine_install_winetricks_proot() {
    proot_exec sudo bash -c "
        command -v winetricks &>/dev/null && exit 0
        wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
            -O /usr/local/bin/winetricks
        chmod +x /usr/local/bin/winetricks
    " 2>/dev/null || true
}

# proot 내부: WINEPREFIX 초기화
_wine_init_prefix_proot() {
    echo "[Wine] WINEPREFIX 초기화 중..."
    proot_exec_wine bash -c \
        "WINEPREFIX=\$HOME/.wine WINEDEBUG=-all wine wineboot --init 2>/dev/null || true" || true
}

# Termux native: glibc-runner + box64-glibc + Wine-Staging tarball
_wine_install_native() {
    echo "[Wine] Termux native: glibc-runner + box64-glibc + Wine-Staging"

    if [ -d "$_WINE_NATIVE_DIR" ] && [ -f "$_WINE_BIN" ]; then
        echo "[Wine] 이미 설치되어 있습니다. 건너뜁니다."
        return 0
    fi

    termux_pkg_install glibc-repo
    termux_pkg_install glibc-runner box64-glibc

    for p in \
        mesa-zink-glibc vulkan-volk-glibc mesa-vulkan-icd-freedreno-glibc \
        pulseaudio-glibc \
        libxcb-glibc libxext-glibc libxrender-glibc libxfixes-glibc \
        libxcursor-glibc libxinerama-glibc libice-glibc libsm-glibc \
        libgcrypt-glibc libgpg-error-glibc
    do
        termux_pkg_install "$p" 2>/dev/null || true
    done

    local wine_url
    wine_url=$(_wine_tarball_url)
    echo "[Wine] wine-staging 다운로드 중... (수분 소요)"
    mkdir -p "$_WINE_NATIVE_DIR"
    wget -q "$wine_url" -O /tmp/wine-staging.tar.xz
    tar -xJf /tmp/wine-staging.tar.xz -C "$_WINE_NATIVE_DIR" --strip-components=1
    rm -f /tmp/wine-staging.tar.xz

    cat > "$_WINE_BIN" << 'WRAPEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Wine wrapper — Termux native (glibc-runner)
# WINE_DPI=240 wine explorer   ← DPI 오버라이드 예시

WINE_DPI="${WINE_DPI:-240}"

# Wine 레지스트리 DPI 동기화
_reg="${WINEPREFIX:-$HOME/.wine}/user.reg"
if [ -f "$_reg" ]; then
    _hex=$(printf '%08x' "$WINE_DPI")
    grep -q "\"LogPixels\"=dword:${_hex}" "$_reg" 2>/dev/null || \
        sed -i "s/\"LogPixels\"=dword:[0-9a-f]\{8\}/\"LogPixels\"=dword:${_hex}/" "$_reg"
fi

export DISPLAY="${DISPLAY:-:0.0}"
# Mesa / Vulkan
export MESA_LOADER_DRIVER_OVERRIDE="${MESA_LOADER_DRIVER_OVERRIDE:-zink}"
export TU_DEBUG=noconform
export ZINK_DESCRIPTORS=lazy
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE="${MESA_GL_VERSION_OVERRIDE:-4.6COMPAT}"
export MESA_GLSL_VERSION_OVERRIDE="${MESA_GLSL_VERSION_OVERRIDE:-460}"
export MESA_GLES_VERSION_OVERRIDE="${MESA_GLES_VERSION_OVERRIDE:-3.2}"
# Wine
export WINEESYNC=1
export WINEDEBUG="${WINEDEBUG:--all}"
# Box64
export BOX64_MMAP32=1
export BOX64_X11THREADS=1
export BOX64_DYNAREC_SAFEFLAGS=2
# DXVK
export DXVK_ASYNC="${DXVK_ASYNC:-1}"
export DXVK_STATE_CACHE="${DXVK_STATE_CACHE:-reset}"
exec grun "$HOME/.wine-staging/bin/wine64" "$@"
WRAPEOF
    chmod +x "$_WINE_BIN"

    DISPLAY="${DISPLAY:-:0.0}" wine wineboot --init 2>/dev/null || true
}

# .desktop + proot 래퍼 스크립트 생성
_wine_create_launchers() {
    if has_proot_distro; then
        cat > "$_WINE_BIN" << 'WRAPEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Wine wrapper — prun을 통해 proot 내 wine-staging 실행
# WINE_DPI=240 wine explorer   ← DPI 오버라이드 예시

WINE_DPI="${WINE_DPI:-240}"

# prun 설정에서 rootfs 경로 계산
_conf="$HOME/.config/termux-xfce/config"
[ -f "$_conf" ] && . "$_conf"
_distro="${PROOT_DISTRO:-archlinux}"
_user="${PROOT_USER:-$(ls -1 "$PREFIX/var/lib/proot-distro/installed-rootfs/$_distro/home/" 2>/dev/null | grep -v '^alarm$' | head -1)}"
_reg="$PREFIX/var/lib/proot-distro/installed-rootfs/$_distro/home/$_user/.wine/user.reg"

# Wine 레지스트리 DPI 동기화 (sed — wineserver 불필요, 즉시 반영)
if [ -f "$_reg" ]; then
    _hex=$(printf '%08x' "$WINE_DPI")
    grep -q "\"LogPixels\"=dword:${_hex}" "$_reg" 2>/dev/null || \
        sed -i "s/\"LogPixels\"=dword:[0-9a-f]\{8\}/\"LogPixels\"=dword:${_hex}/" "$_reg"
fi

exec prun env DISPLAY="${DISPLAY:-:0}" \
    WINEDATADIR=/opt/wine-staging/share/wine \
    MESA_LOADER_DRIVER_OVERRIDE=zink \
    TU_DEBUG=noconform \
    ZINK_DESCRIPTORS=lazy \
    MESA_NO_ERROR=1 \
    MESA_GL_VERSION_OVERRIDE=4.6COMPAT \
    MESA_GLSL_VERSION_OVERRIDE=460 \
    MESA_GLES_VERSION_OVERRIDE=3.2 \
    WINELOADERNOEXEC=1 \
    WINEESYNC=1 \
    WINEDEBUG=-all \
    BOX64_MMAP32=1 \
    BOX64_X11THREADS=1 \
    BOX64_DYNAREC_SAFEFLAGS=2 \
    DXVK_ASYNC=1 \
    DXVK_STATE_CACHE=reset \
    wine "$@"
WRAPEOF
        chmod +x "$_WINE_BIN"
    fi

    mkdir -p "${PREFIX}/share/applications"
    cat > "$_WINE_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine
Comment=Windows 프로그램 실행 (Box64 + Wine-Staging)
Exec=bash -c "prun-gui Wine -- env DISPLAY=:0 WINEDATADIR=/opt/wine-staging/share/wine MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform ZINK_DESCRIPTORS=lazy MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.6COMPAT MESA_GLSL_VERSION_OVERRIDE=460 MESA_GLES_VERSION_OVERRIDE=3.2 WINELOADERNOEXEC=1 WINEESYNC=1 WINEDEBUG=-all BOX64_MMAP32=1 BOX64_X11THREADS=1 BOX64_DYNAREC_SAFEFLAGS=2 DXVK_ASYNC=1 DXVK_STATE_CACHE=reset wine explorer </dev/null >/dev/null 2>&1 &"
Icon=wine
Categories=System;Emulator;
MimeType=application/x-ms-dos-executable;application/x-msi;
StartupNotify=false
Terminal=false
EOF

    cat > "$_WINECFG_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine 설정
Comment=Wine 환경 구성 (winecfg)
Exec=bash -c "prun-gui 'Wine 설정' -- env DISPLAY=:0 WINEDATADIR=/opt/wine-staging/share/wine MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform ZINK_DESCRIPTORS=lazy MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.6COMPAT MESA_GLSL_VERSION_OVERRIDE=460 MESA_GLES_VERSION_OVERRIDE=3.2 WINELOADERNOEXEC=1 WINEESYNC=1 WINEDEBUG=-all BOX64_MMAP32=1 BOX64_X11THREADS=1 BOX64_DYNAREC_SAFEFLAGS=2 DXVK_ASYNC=1 DXVK_STATE_CACHE=reset wine winecfg </dev/null >/dev/null 2>&1 &"
Icon=wine-winecfg
Categories=Settings;System;
Terminal=false
StartupNotify=false
EOF

    # Wine 앱 설치 런처 (install.sh wine 모드)
    cat > "$_WINE_APPS_DESKTOP" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine 앱 설치
Comment=Windows 프로그램 설치/제거
Exec=bash ${SCRIPT_DIR}/install.sh wine
Icon=wine
Categories=System;
Terminal=false
StartupNotify=false
EOF

    # Desktop 아이콘 복사
    cp "$_WINE_DESKTOP" "${HOME}/Desktop/wine64.desktop" 2>/dev/null || true
    cp "$_WINECFG_DESKTOP" "${HOME}/Desktop/winecfg.desktop" 2>/dev/null || true
    cp "$_WINE_APPS_DESKTOP" "${HOME}/Desktop/wine-apps.desktop" 2>/dev/null || true
    chmod +x "${HOME}/Desktop/wine64.desktop" "${HOME}/Desktop/winecfg.desktop" \
        "${HOME}/Desktop/wine-apps.desktop" 2>/dev/null || true
    gio set "${HOME}/Desktop/wine64.desktop" metadata::trusted true 2>/dev/null || true
    gio set "${HOME}/Desktop/winecfg.desktop" metadata::trusted true 2>/dev/null || true
}

app_install_wine() {
    if has_proot_distro; then
        echo "[Wine] proot 감지: ${PROOT_DISTRO} (user: ${PROOT_USER})"

        # 이미 설치된 경우 건너뜀
        if proot_exec which wine &>/dev/null 2>&1; then
            echo "[Wine] 이미 설치되어 있습니다. 건너뜁니다."
        else
            proot_pkg_update
            proot_pkg_install_box64
            if ! proot_exec which box64 &>/dev/null; then
                echo "[ERROR] Box64 설치 실패 — Wine을 설치할 수 없습니다." >&2
                return 1
            fi
            _wine_install_tarball_proot
            proot_dep "mesa_vulkan"
            _wine_install_winetricks_proot
            _wine_init_prefix_proot
        fi
    else
        echo "[Wine] proot 없음: Termux native (glibc-runner) 방식"
        _wine_install_native
    fi

    _wine_create_launchers

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Wine 설치 완료"
    echo "  wine program.exe  — Windows 앱 실행"
    echo "  wine winecfg      — Wine 설정"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

app_remove_wine() {
    if has_proot_distro; then
        proot_exec sudo bash -c "
            rm -rf /opt/wine-staging
            for bin in wine wine64 wineboot winecfg wineserver msiexec regedit winetricks; do
                rm -f /usr/local/bin/\$bin
            done
        " 2>/dev/null || true
        proot_pkg_remove box64 2>/dev/null || true
    else
        rm -rf "$_WINE_NATIVE_DIR"
    fi

    rm -f "$_WINE_BIN" "$_WINE_DESKTOP" "$_WINECFG_DESKTOP" "$_WINE_APPS_DESKTOP"
    rm -f "${HOME}/Desktop/wine64.desktop" "${HOME}/Desktop/winecfg.desktop" \
        "${HOME}/Desktop/wine-apps.desktop"
}

app_is_installed_wine() {
    [ -e "$_WINE_DESKTOP" ]
}
