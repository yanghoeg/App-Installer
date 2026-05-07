#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Claude Code — Termux native + glibc-runner
# v2.1.114+의 native ELF binary는 glibc/musl dynamic linker(/lib/ld-linux-aarch64.so.1)를 요구하는데
# Termux Bionic libc에는 없음 → glibc-runner(grun)가 dynamic linker + glibc 제공해서 실행 가능.
# npm 설치를 우회하고 native binary tarball만 직접 받아서 wrapper로 실행 (self-update 우회).

CLAUDE_CODE_PREFIX="${PREFIX}/share/claude-code"
CLAUDE_CODE_BIN_PATH="${PREFIX}/bin/claude"
CLAUDE_CODE_NPM_PKG="@anthropic-ai/claude-code-linux-arm64"

_claude_code_fetch_latest_version() {
    curl -sL "https://registry.npmjs.org/${CLAUDE_CODE_NPM_PKG}/latest" \
        | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4
}

_claude_code_download_native() {
    local version="$1"
    local url="https://registry.npmjs.org/${CLAUDE_CODE_NPM_PKG}/-/claude-code-linux-arm64-${version}.tgz"
    mkdir -p "${CLAUDE_CODE_PREFIX}"
    local tarball="${CLAUDE_CODE_PREFIX}/native.tgz"
    curl -sL "$url" -o "$tarball" || return 1
    tar xzf "$tarball" -C "${CLAUDE_CODE_PREFIX}" --strip-components=1
    rm -f "$tarball"
    chmod +x "${CLAUDE_CODE_PREFIX}/claude"
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

app_remove_claude_code() {
    rm -f "${CLAUDE_CODE_BIN_PATH}"
    rm -rf "${CLAUDE_CODE_PREFIX}"
}

app_is_installed_claude_code() {
    [ -x "${CLAUDE_CODE_BIN_PATH}" ] && [ -x "${CLAUDE_CODE_PREFIX}/claude" ]
}
