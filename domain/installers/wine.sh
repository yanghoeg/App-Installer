#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: Wine — Box64 + Wine-Staging (백엔드 id: box64)
# =============================================================================
# proot 있음 → proot 내부 Box64 + Wine-Staging (adapter가 distro 차이 흡수)
# proot 없음 → Termux native (glibc-runner + box64-glibc)
#
# 이 설치기는 $PREFIX/bin/wine-box64 래퍼만 만든다. PATH 상의 `wine`은
# lib/wine_backend.sh가 만드는 디스패처이며 활성 백엔드로 위임한다.
# WINEPREFIX는 $HOME/.wine (hangover 백엔드와 분리 — lib/wine_backend.sh 참조)

_WINE_BIN="${PREFIX}/bin/wine-box64"
_WINE_DESKTOP="${PREFIX}/share/applications/wine64.desktop"
_WINECFG_DESKTOP="${PREFIX}/share/applications/winecfg.desktop"
_WINE_APPS_DESKTOP="${PREFIX}/share/applications/wine-apps.desktop"
_WINE_NATIVE_DIR="${HOME}/.wine-staging"

# Wine-Staging WoW64 — 버전 핀 + sha256 (GitHub API latest 조회 없음)
# wow64 빌드: 64-bit wine만으로 32-bit PE 실행 (Box64 환경 필수)
# 버전을 올릴 때: Kron4ek 릴리스의 sha256sums.txt와 대조해 아래 상수를 갱신할 것.
_WINE_STAGING_VER="11.16"
_WINE_STAGING_SHA256="746d3d571e474a7a603e084a0d35649699c3d5c98e5ea3e9994e1e5fa693af92"

# winetricks — master 대신 커밋 핀 (raw 콘텐츠가 조용히 바뀌지 않도록)
_WINETRICKS_COMMIT="f3890f670867b5ffbc3938726db45c0f7d16c8ba"
_WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/${_WINETRICKS_COMMIT}/src/winetricks"
_WINETRICKS_SHA256="672a1ff4442e8691a3ffc0e6860137e201a1d1227e9b3044245f1731e9e9837e"

_wine_tarball_url() {
    echo "https://github.com/Kron4ek/Wine-Builds/releases/download/${_WINE_STAGING_VER}/wine-${_WINE_STAGING_VER}-staging-amd64-wow64.tar.xz"
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
    proot_exec_wine sudo bash -c "$(fetch_verified_src)"$'\n'"
        set -e
        command -v file >/dev/null 2>&1 || { echo '[ERROR] Wine ELF 판별에 file 명령이 필요합니다.' >&2; exit 1; }
        mkdir -p /opt/wine-staging
        fetch_verified '${wine_url}' /tmp/wine-staging.tar.xz '${_WINE_STAGING_SHA256}'
        tar -xJf /tmp/wine-staging.tar.xz -C /opt/wine-staging --strip-components=1
        rm -f /tmp/wine-staging.tar.xz

        # x86-64 ELF를 .elf/ 서브디렉토리로 이동 후 box64 wrapper 생성
        # argv[0] 보존: box64가 wine 경로의 basename을 argv[0]으로 전달
        cd /opt/wine-staging/bin
        mkdir -p .elf
        wrapped_required=0
        for f in wine wineserver wineboot winedbg; do
            if [ -f \"\$f\" ] && file \"\$f\" 2>/dev/null | grep -q 'x86-64'; then
                mv \"\$f\" \".elf/\$f\"
                printf '#!/bin/bash\nexec box64 /opt/wine-staging/bin/.elf/%s \"\$@\"\n' \"\$f\" > \"\$f\"
                chmod +x \"\$f\"
                case \"\$f\" in wine|wineserver) wrapped_required=\$((wrapped_required + 1)) ;; esac
            fi
        done
        [ \"\$wrapped_required\" -eq 2 ] && test -x .elf/wine && test -x .elf/wineserver || {
            echo '[ERROR] Wine x86-64 ELF 래퍼 생성 실패' >&2; exit 1;
        }
        # ELF의 상대경로 ../lib, ../share 가 올바른 위치를 가리키도록 symlink
        ln -sf ../lib /opt/wine-staging/bin/lib
        ln -sf ../share /opt/wine-staging/bin/share

        # /usr/local/bin 심링크 (symlink 방식 대신 직접 복사 — cat으로 덮어써지는 문제 방지)
        for bin in wine wineboot winecfg wineserver msiexec regedit winetricks; do
            [ -f /opt/wine-staging/bin/\$bin ] && \
                ln -sf /opt/wine-staging/bin/\$bin /usr/local/bin/\$bin || true
        done
    "
}

# proot 내부: winetricks 설치
# 검증 실패한 파일이 /usr/local/bin에 남지 않도록 임시경로에 받은 뒤 mv 한다.
# (winetricks는 비임계 — 실패해도 Wine 설치 자체는 계속 진행)
_wine_install_winetricks_proot() {
    proot_exec sudo bash -c "$(fetch_verified_src)"$'\n'"
        command -v winetricks >/dev/null 2>&1 && exit 0
        _wt=\$(mktemp) || exit 1
        fetch_verified '${_WINETRICKS_URL}' \"\$_wt\" '${_WINETRICKS_SHA256}' || { rm -f \"\$_wt\"; exit 1; }
        chmod +x \"\$_wt\"
        mv \"\$_wt\" /usr/local/bin/winetricks
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

    termux_pkg_enable_repo glibc-repo || return 1
    termux_pkg_install glibc-runner box64-glibc || return 1

    # 래퍼가 아니라 wine 트리 자체로 판정한다.
    # (래퍼 경로가 wine → wine-box64로 바뀐 기존 설치도 재다운로드하지 않도록)
    if [ -x "$_WINE_NATIVE_DIR/bin/wine" ]; then
        echo "[Wine] 이미 설치되어 있습니다. 래퍼만 갱신합니다."
        _wine_write_box64_native_wrapper
        return $?
    fi

    for p in \
        mesa-glibc vulkan-volk-glibc mesa-vulkan-icd-freedreno-glibc \
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
    local _tmp_tar="${TMPDIR:-/tmp}/wine-staging.tar.xz"
    fetch_verified "$wine_url" "$_tmp_tar" "$_WINE_STAGING_SHA256" || {
        echo "[ERROR] Wine 다운로드 실패" >&2
        return 1
    }
    if ! tar -xJf "$_tmp_tar" -C "$_WINE_NATIVE_DIR" --strip-components=1; then
        rm -f "$_tmp_tar"
        echo "[ERROR] Wine 압축 해제 실패" >&2
        return 1
    fi
    rm -f "$_tmp_tar"
    [ -x "$_WINE_NATIVE_DIR/bin/wine" ] || {
        echo "[ERROR] Wine 실행 파일을 찾을 수 없습니다." >&2
        return 1
    }

    _wine_write_box64_native_wrapper || return 1

    "$_WINE_BIN" wineboot --init 2>/dev/null || true
}

# $PREFIX/bin/wine-box64 — Termux native (glibc-runner) 래퍼
# Mesa/Vulkan/Wine 공통 env는 wine_emit_env_block()(lib/wine_backend.sh)에서 온다.
_wine_write_box64_native_wrapper() {
    {
        cat << 'WRAP_HEAD'
#!/data/data/com.termux/files/usr/bin/bash
# Wine wrapper — Termux native (glibc-runner), 백엔드 id: box64
# WINE_DPI=240 wine explorer   ← DPI 오버라이드 예시

WINE_DPI="${WINE_DPI:-240}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"

# Android CPU 쓰로틀링 방지
termux-wake-lock 2>/dev/null

# Wine 레지스트리 DPI 동기화
_reg="${WINEPREFIX}/user.reg"
if [ -f "$_reg" ]; then
    _hex=$(printf '%08x' "$WINE_DPI")
    grep -q "\"LogPixels\"=dword:${_hex}" "$_reg" 2>/dev/null || \
        sed -i "s/\"LogPixels\"=dword:[0-9a-f]\{8\}/\"LogPixels\"=dword:${_hex}/" "$_reg"
fi

WRAP_HEAD
        wine_emit_env_block
        cat << 'WRAP_TAIL'
# Box64
export BOX64_MMAP32=1
export BOX64_X11THREADS=1
export BOX64_DYNAREC_SAFEFLAGS=2
# DXVK
export DXVK_ASYNC="${DXVK_ASYNC:-1}"
export DXVK_STATE_CACHE="${DXVK_STATE_CACHE:-reset}"
# grun's unquoted argv handling loses Windows paths containing spaces. Invoke
# its ARM64 glibc loader directly, with Box64 handling the x86-64 Wine programs.
unset LD_PRELOAD
export PATH="$PREFIX/glibc/bin:$PATH"
_loader="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
_box64="$PREFIX/glibc/bin/box64"
if [ ! -x "$_loader" ] || [ ! -x "$_box64" ]; then
    echo "[ERROR] glibc 또는 Box64가 없습니다. Wine을 다시 설치하세요." >&2
    exit 1
fi
if [ -x "$HOME/.wine-staging/bin/wineserver" ]; then
    "$_loader" --library-path "$PREFIX/glibc/lib" "$_box64" "$HOME/.wine-staging/bin/wineserver" -p 2>/dev/null &
fi
exec "$_loader" --library-path "$PREFIX/glibc/lib" "$_box64" "$HOME/.wine-staging/bin/wine" "$@"
WRAP_TAIL
    } > "$_WINE_BIN"
    chmod +x "$_WINE_BIN"
}

# .desktop + proot 래퍼 스크립트 생성
_wine_create_launchers() {
    if has_proot_distro; then
        cat > "$_WINE_BIN" << 'WRAPEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Wine wrapper — prun을 통해 proot 내 wine-staging 실행, 백엔드 id: box64
# WINE_DPI=240 wine explorer   ← DPI 오버라이드 예시

WINE_DPI="${WINE_DPI:-240}"

# Android CPU 쓰로틀링 방지
termux-wake-lock 2>/dev/null

# Load the configured proot distro; native-only configurations must not pick one.
_conf="$HOME/.config/termux-xfce/config"
[ -f "$_conf" ] && . "$_conf"
if [ -z "${PROOT_DISTRO:-}" ]; then
    echo "[ERROR] Wine Box64 requires PROOT_DISTRO in ~/.config/termux-xfce/config." >&2
    exit 1
fi
exec prun env WINE_DPI="$WINE_DPI" bash -c '
    export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}" WINEESYNC=1 WINEDEBUG="${WINEDEBUG:--all}"
    case "$WINE_DPI" in *[!0-9]*|"") echo "[ERROR] WINE_DPI must be a positive integer" >&2; exit 2 ;; esac
    _reg="$WINEPREFIX/user.reg"
    if [ -f "$_reg" ]; then
        _hex=$(printf "%08x" "$((10#$WINE_DPI))")
        sed -i "s/\"LogPixels\"=dword:[0-9a-f]\{8\}/\"LogPixels\"=dword:${_hex}/" "$_reg"
    fi
    exec /opt/wine-staging/bin/wine "$@"
' wine-box64 "$@"
WRAPEOF
        chmod +x "$_WINE_BIN"
    fi

    mkdir -p "${PREFIX}/share/applications"

    cat > "$_WINE_DESKTOP" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine (Box64)
Comment=Windows 프로그램 실행 (Box64 + Wine-Staging)
Exec=wine-box64 explorer
Icon=wine
Categories=System;Emulator;
MimeType=application/x-ms-dos-executable;application/x-msi;
StartupNotify=false
Terminal=false
EOF

    cat > "$_WINECFG_DESKTOP" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine 설정 (Box64)
Comment=Wine 환경 구성 (winecfg)
Exec=wine-box64 winecfg
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
Exec=bash $(_desktop_exec_quote "${SCRIPT_DIR}/install.sh") wine
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

    # PATH 상의 `wine` 디스패처 + wine-backend CLI 배선
    wine_wire_frontend || return 1
    wine_backend_set_default box64
}

app_install_wine() {
    if has_proot_distro; then
        echo "[Wine] proot 감지: ${PROOT_DISTRO} (user: ${PROOT_USER})"

        # 이미 설치된 경우 건너뜀
        if proot_exec env PATH=/usr/local/bin:/usr/bin:/bin bash -c \
            'test -x /opt/wine-staging/bin/wine && test -x /opt/wine-staging/bin/wineserver &&
             test -x /opt/wine-staging/bin/.elf/wine && test -x /opt/wine-staging/bin/.elf/wineserver &&
             grep -Fqx "exec box64 /opt/wine-staging/bin/.elf/wine \"\$@\"" /opt/wine-staging/bin/wine &&
             grep -Fqx "exec box64 /opt/wine-staging/bin/.elf/wineserver \"\$@\"" /opt/wine-staging/bin/wineserver &&
             command -v box64 >/dev/null' &>/dev/null; then
            echo "[Wine] 이미 설치되어 있습니다. 건너뜁니다."
        else
            proot_pkg_update || return 1
            proot_pkg_install_box64 || return 1
            if ! proot_exec env PATH=/usr/local/bin:/usr/bin:/bin bash -c 'command -v box64' &>/dev/null; then
                echo "[ERROR] Box64 설치 실패 — Wine을 설치할 수 없습니다." >&2
                return 1
            fi
            _wine_install_tarball_proot || { echo "[ERROR] Wine 다운로드/설치 실패" >&2; return 1; }
            proot_pkg_install_wine_mesa || return 1
            _wine_install_winetricks_proot
            _wine_init_prefix_proot
        fi
    else
        echo "[Wine] proot 없음: Termux native (glibc-runner) 방식"
        _wine_install_native || return 1
    fi

    _wine_create_launchers || return 1

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Wine (Box64 + Wine-Staging) 설치 완료"
    echo "  wine program.exe  — Windows 앱 실행 (활성 백엔드)"
    echo "  wine winecfg      — Wine 설정"
    echo "  wine-backend      — 활성 백엔드 확인 / 전환"
    echo "  WINEPREFIX        — \$HOME/.wine"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

app_remove_wine() {
    if has_proot_distro; then
        if proot_pkg_is_installed box64; then proot_pkg_remove box64 || return 1; fi
        proot_exec sudo bash -c "
            set -e
            # Source builds are not registered in the package database.
            rm -f /usr/local/bin/box64
            rm -rf /opt/wine-staging
            for bin in wine wineboot winecfg wineserver msiexec regedit winetricks; do
                rm -f /usr/local/bin/\$bin
            done
        " || return 1
    else
        rm -rf "$_WINE_NATIVE_DIR" || return 1
    fi

    rm -f "$_WINE_BIN" "$_WINE_DESKTOP" "$_WINECFG_DESKTOP" "$_WINE_APPS_DESKTOP" || return 1
    rm -f "${HOME}/Desktop/wine64.desktop" "${HOME}/Desktop/winecfg.desktop" \
        "${HOME}/Desktop/wine-apps.desktop" || return 1

    # 디스패처: 다른 백엔드가 남아 있으면 그쪽으로 넘기고, 없으면 함께 제거
    if [ -x "$_WINE_HANGOVER_BIN" ]; then
        wine_backend_set hangover
    else
        rm -f "$_WINE_DISPATCHER" "$_WINE_BACKEND_CLI" "$_WINE_BACKEND_CONF"
    fi
}

app_is_installed_wine() {
    [ -e "$_WINE_DESKTOP" ]
}
