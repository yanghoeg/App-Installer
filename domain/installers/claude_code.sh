#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Claude Code — Termux native + glibc-runner
# v2.1.114+의 native ELF binary는 glibc/musl dynamic linker(/lib/ld-linux-aarch64.so.1)를 요구하는데
# Termux Bionic libc에는 없음 → glibc-runner(grun)가 dynamic linker + glibc 제공해서 실행 가능.
# npm 설치를 우회하고 native binary tarball만 직접 받아서 wrapper로 실행 (self-update 우회).

CLAUDE_CODE_PREFIX="${PREFIX}/share/claude-code"
CLAUDE_CODE_BIN_PATH="${PREFIX}/bin/claude"
CLAUDE_CODE_NPM_PKG="@anthropic-ai/claude-code-linux-arm64"
# 설치된 버전 기록 — self-update를 끈 상태라 업그레이드 판단 근거로 사용
CLAUDE_CODE_VERSION_FILE="${CLAUDE_CODE_PREFIX}/VERSION"

_claude_code_fetch_latest_version() {
    curl -sSLf "https://registry.npmjs.org/${CLAUDE_CODE_NPM_PKG}/latest" \
        | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4
}

# 설치된 버전 조회 — 미설치/버전 파일 없으면 빈 문자열
_claude_code_installed_version() {
    [ -f "${CLAUDE_CODE_VERSION_FILE}" ] || return 0
    cat "${CLAUDE_CODE_VERSION_FILE}"
}

_claude_code_download_native() {
    local version="$1"
    local url="https://registry.npmjs.org/${CLAUDE_CODE_NPM_PKG}/-/claude-code-linux-arm64-${version}.tgz"
    mkdir -p "${CLAUDE_CODE_PREFIX}"
    local tarball="${CLAUDE_CODE_PREFIX}/native.tgz"
    curl -sSLf "$url" -o "$tarball" || return 1
    tar xzf "$tarball" -C "${CLAUDE_CODE_PREFIX}" --strip-components=1
    rm -f "$tarball"
    chmod +x "${CLAUDE_CODE_PREFIX}/claude"
    printf '%s\n' "$version" > "${CLAUDE_CODE_VERSION_FILE}"
}

_claude_code_remove_npm_wrapper() {
    command -v npm >/dev/null 2>&1 || return 0
    npm ls -g --depth=0 2>/dev/null | grep -q "@anthropic-ai/claude-code" || return 0
    npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
}

_claude_code_install_wrapper() {
    cat > "${CLAUDE_CODE_BIN_PATH}" << EOF
#!${PREFIX}/bin/bash
exec grun "${CLAUDE_CODE_PREFIX}/claude" "\$@"
EOF
    chmod +x "${CLAUDE_CODE_BIN_PATH}"
}

# settings.json에 self-updater 차단 env var 주입.
# 기존 파일이 있으면 보존 — 사용자 설정 덮어쓰지 않음.
_claude_code_configure_settings() {
    local settings_dir="${HOME}/.claude"
    local settings_file="${settings_dir}/settings.json"
    mkdir -p "${settings_dir}"
    [ -f "${settings_file}" ] && return 0
    cat > "${settings_file}" << 'EOF'
{
  "env": {
    "DISABLE_AUTOUPDATER": "1"
  }
}
EOF
}

app_install_claude_code() {
    termux_pkg_install glibc-repo
    termux_pkg_install glibc-runner
    _claude_code_remove_npm_wrapper
    local version
    version=$(_claude_code_fetch_latest_version)
    [ -z "$version" ] && { echo "[ERROR] claude-code 버전 조회 실패" >&2; return 1; }
    _claude_code_download_native "$version" || return 1
    _claude_code_install_wrapper
    _claude_code_configure_settings
}

# 현재 native binary를 이전 버전 이름으로 백업 — 롤백 자료.
# 이미 같은 이름의 백업이 있으면 유지(가장 오래된 알려진-정상 버전을 지키기 위해).
_claude_code_backup_current() {
    local ver="$1"
    [ -n "$ver" ] || return 0
    [ -f "${CLAUDE_CODE_PREFIX}/claude" ] || return 0
    local bak_bin="${CLAUDE_CODE_PREFIX}/claude.bak.v${ver}"
    [ -e "$bak_bin" ] && return 0
    cp -f "${CLAUDE_CODE_PREFIX}/claude"       "$bak_bin"
    [ -f "${CLAUDE_CODE_PREFIX}/package.json" ] && \
        cp -f "${CLAUDE_CODE_PREFIX}/package.json" "${CLAUDE_CODE_PREFIX}/package.json.bak.v${ver}"
}

# 새 binary가 최소한 실행되는지만 확인 — 로그인/기능 회귀는 여기서 못 잡음.
# 부팅 자체가 깨진 회귀(예: 잘못된 dynamic linker 요구)만 감지.
_claude_code_smoke_check() {
    grun "${CLAUDE_CODE_PREFIX}/claude" --version >/dev/null 2>&1
}

# 백업된 이전 버전으로 되돌림 — 로그인 회귀 등 수동 롤백에 사용.
# 사용: app_rollback_claude_code            → 사용 가능한 최신 백업으로
#      app_rollback_claude_code 2.1.132    → 특정 버전으로
app_rollback_claude_code() {
    local target="${1:-}" bak_bin bak_pkg
    if [ -n "$target" ]; then
        bak_bin="${CLAUDE_CODE_PREFIX}/claude.bak.v${target}"
        [ -f "$bak_bin" ] || { echo "[ERROR] 백업 없음: v${target}" >&2; return 1; }
    else
        # pipefail 아래에서 매치 없을 때 ls 실패 → || true로 흡수하고 빈 문자열 판정으로 넘김
        bak_bin=$(ls -1t "${CLAUDE_CODE_PREFIX}"/claude.bak.v* 2>/dev/null | head -1 || true)
        [ -n "$bak_bin" ] || { echo "[ERROR] 사용 가능한 백업이 없습니다" >&2; return 1; }
        target=${bak_bin##*/claude.bak.v}
    fi
    bak_pkg="${CLAUDE_CODE_PREFIX}/package.json.bak.v${target}"
    cp -f "$bak_bin" "${CLAUDE_CODE_PREFIX}/claude"
    chmod +x "${CLAUDE_CODE_PREFIX}/claude"
    [ -f "$bak_pkg" ] && cp -f "$bak_pkg" "${CLAUDE_CODE_PREFIX}/package.json"
    printf '%s\n' "$target" > "${CLAUDE_CODE_VERSION_FILE}"
    _claude_code_install_wrapper
    echo "[INFO] v${target}으로 롤백 완료"
}

# 최신 native binary로 업그레이드.
# self-update가 꺼져 있으므로 tarball을 다시 받아 교체 (settings.json은 건드리지 않음).
# 백업 → 다운로드 → 스모크 → 실패 시 자동 롤백.
#   반환값: 0=업그레이드 완료, 2=이미 최신, 1=오류(롤백됨)
app_upgrade_claude_code() {
    if ! app_is_installed_claude_code; then
        echo "[ERROR] claude-code가 설치되어 있지 않습니다" >&2
        return 1
    fi
    local latest current
    latest=$(_claude_code_fetch_latest_version)
    [ -z "$latest" ] && { echo "[ERROR] claude-code 버전 조회 실패" >&2; return 1; }
    current=$(_claude_code_installed_version)
    if [ "$current" = "$latest" ]; then
        echo "[INFO] 이미 최신 버전입니다 (${latest})"
        return 2
    fi
    _claude_code_backup_current "$current"
    _claude_code_download_native "$latest" || {
        [ -n "$current" ] && app_rollback_claude_code "$current" >/dev/null 2>&1
        return 1
    }
    _claude_code_install_wrapper
    if ! _claude_code_smoke_check; then
        echo "[ERROR] v${latest} 스모크 실패 — v${current}으로 롤백" >&2
        [ -n "$current" ] && app_rollback_claude_code "$current" >/dev/null 2>&1
        return 1
    fi
}

app_remove_claude_code() {
    rm -f "${CLAUDE_CODE_BIN_PATH}"
    rm -rf "${CLAUDE_CODE_PREFIX}"
    # npm 글로벌 패키지가 남아 있으면 bin/claude 심볼릭이 재생성돼 되살아남 → 함께 제거
    _claude_code_remove_npm_wrapper
}

app_is_installed_claude_code() {
    [ -x "${CLAUDE_CODE_BIN_PATH}" ] && [ -x "${CLAUDE_CODE_PREFIX}/claude" ]
}
