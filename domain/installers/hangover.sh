#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: Hangover — Wine + FEX/ARM64EC (백엔드 id: hangover)
# =============================================================================
# Termux x11-repo의 `hangover` 메타 패키지가 hangover-wine / -libwow64fex /
# -libarm64ecfex / -wowbox64 를 함께 끌어온다. Wine 자체는 네이티브 arm64로
# 돌고 x86 앱 바이너리만 FEX/ARM64EC로 에뮬하므로 Wine 전체를 box64로 돌리는
# 방식보다 빠르다. proot 불필요 — Termux native 전용.
#
# 패키지가 설치하는 실제 진입점:
#   $PREFIX/bin/hangover-wine        → $PREFIX/opt/hangover-wine/bin/wine
#   $PREFIX/opt/hangover-wine/bin/   winecfg, wineboot, wineserver, ...
#
# WINEPREFIX는 $HOME/.wine-hangover — box64 백엔드($HOME/.wine)와 분리한다.
# 서로 다른 Wine 빌드(wow64 staging vs ARM64EC)라 prefix를 공유하면
# wineboot --update가 왕복하며 깨진다.

_HANGOVER_BIN="${PREFIX}/bin/wine-hangover"
_HANGOVER_UPSTREAM="${PREFIX}/bin/hangover-wine"

# $PREFIX/bin/wine-hangover — env 주입 후 hangover-wine 실행
_hangover_write_wrapper() {
    {
        cat << 'WRAP_HEAD'
#!/data/data/com.termux/files/usr/bin/bash
# Wine wrapper — Hangover (FEX/ARM64EC), 백엔드 id: hangover
# WINE_DPI=240 wine explorer   ← DPI 오버라이드 예시

WINE_DPI="${WINE_DPI:-240}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-hangover}"

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

"$PREFIX/opt/hangover-wine/bin/wineserver" -p 2>/dev/null &
exec "$PREFIX/bin/hangover-wine" "$@"
WRAP_TAIL
    } > "$_HANGOVER_BIN"
    chmod +x "$_HANGOVER_BIN"
}

app_install_hangover() {
    if has_proot_distro; then
        echo "[Hangover] Termux native로 설치합니다 (proot 불필요)."
    fi

    # x11-repo 필요 (hangover 패키지 소스)
    termux_pkg_enable_repo x11-repo || return 1

    echo "[Hangover] hangover 설치 중... (Wine + FEX 런타임, 수백 MB)"
    termux_pkg_install hangover || return 1

    if [ ! -x "$_HANGOVER_UPSTREAM" ]; then
        echo "[ERROR] hangover-wine을 찾을 수 없습니다: ${_HANGOVER_UPSTREAM}" >&2
        return 1
    fi

    _hangover_write_wrapper || return 1

    # PATH 상의 `wine` 디스패처 + wine-backend CLI 배선
    wine_wire_frontend || return 1
    wine_backend_set_default hangover

    echo "[Hangover] WINEPREFIX 초기화 중..."
    DISPLAY="${DISPLAY:-:0.0}" "$_HANGOVER_BIN" wineboot --init 2>/dev/null || true

    desktop_register "hangover" "Wine (Hangover)" \
        "bash -c \"wine-hangover explorer </dev/null >/dev/null 2>&1 &\"" \
        "wine" "System;Emulator;" \
        "MimeType=application/x-ms-dos-executable;application/x-msi;" || return 1

    desktop_register "hangover-winecfg" "Wine 설정 (Hangover)" \
        "bash -c \"wine-hangover winecfg </dev/null >/dev/null 2>&1 &\"" \
        "wine-winecfg" "Settings;System;" || return 1

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Hangover 설치 완료"
    echo "  wine program.exe  — Windows 앱 실행 (활성 백엔드)"
    echo "  wine-backend      — 활성 백엔드 확인 / 전환"
    echo "  WINEPREFIX        — \$HOME/.wine-hangover"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

app_remove_hangover() {
    termux_pkg_is_installed hangover && termux_pkg_remove hangover
    rm -f "$_HANGOVER_BIN"
    desktop_remove "hangover"
    desktop_remove "hangover-winecfg"

    # 디스패처: 다른 백엔드가 남아 있으면 그쪽으로 넘기고, 없으면 함께 제거
    if [ -x "$_WINE_BOX64_BIN" ]; then
        wine_backend_set box64
    else
        rm -f "$_WINE_DISPATCHER" "$_WINE_BACKEND_CLI" "$_WINE_BACKEND_CONF"
    fi
}

app_is_installed_hangover() {
    desktop_is_registered "hangover"
}
