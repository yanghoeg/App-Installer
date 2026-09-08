#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Codex CLI — Termux native (업스트림 정적 musl 바이너리)
# OpenAI 코딩 에이전트 CLI. API 키는 사용자가 별도 설정.
# CLI 전용이라 .desktop 런처는 생성하지 않는다.
#
# TUR(tur-repo) 패키지는 0.122.0에서 멈춰 있어 업스트림 릴리스 tarball을 직접 받는다.
# aarch64-unknown-linux-musl 빌드는 정적 링크라 Bionic libc 위에서 그대로 실행된다
# (claude-code와 달리 glibc-runner 불필요).

CODEX_BIN_PATH="${PREFIX}/bin/codex"
CODEX_TARBALL_MEMBER="codex-aarch64-unknown-linux-musl"

# 핀 버전 — 올릴 때 아래 sha256도 함께 갱신할 것
# (sha256sum codex-aarch64-unknown-linux-musl.tar.gz)
CODEX_PIN_VERSION="0.153.4"

declare -gA CODEX_TARBALL_SHA256=(
    ["0.153.4"]="5cda6182bd94c3a30f2eb63a495489ebf7f691fddb14d70f48c6c1a5071b6cde"
)

# 설치된 버전 조회 — 미설치면 빈 문자열 ("codex-cli 0.153.4" → "0.153.4")
_codex_installed_version() {
    [ -x "${CODEX_BIN_PATH}" ] || return 0
    "${CODEX_BIN_PATH}" --version 2>/dev/null | awk '{print $NF}'
}

# 핀 버전 tarball을 받아 바이너리를 교체한다.
# 실행 중이어도 안전하도록 임시 파일에 풀고 mv로 갈아끼운다.
_codex_download() {
    local ver="$1"
    local url="https://github.com/openai/codex/releases/download/rust-v${ver}/${CODEX_TARBALL_MEMBER}.tar.gz"
    local tmp_tgz="${TMPDIR:-/tmp}/codex-${ver}.tar.gz"
    local tmp_bin="${CODEX_BIN_PATH}.new"
    fetch_verified "$url" "$tmp_tgz" "${CODEX_TARBALL_SHA256[$ver]:-}" || return 1
    if ! tar xzf "$tmp_tgz" -O "${CODEX_TARBALL_MEMBER}" > "$tmp_bin"; then
        rm -f "$tmp_tgz" "$tmp_bin"; return 1
    fi
    rm -f "$tmp_tgz"
    chmod +x "$tmp_bin"
    mv -f "$tmp_bin" "${CODEX_BIN_PATH}"
}

# TUR dpkg 패키지가 남아 있으면 $PREFIX/bin/codex 소유권이 겹친다 → 먼저 제거
_codex_remove_tur_pkg() {
    if termux_pkg_is_installed codex; then
        termux_pkg_remove codex
    fi
    return 0
}

app_install_codex() {
    if [ "$(_codex_installed_version)" = "${CODEX_PIN_VERSION}" ]; then
        return 0
    fi
    _codex_remove_tur_pkg
    _codex_download "${CODEX_PIN_VERSION}" || return 1
    echo "[Codex] 'codex' 실행 전 OPENAI_API_KEY를 설정하세요."
}

# 핀 버전으로 갱신. 반환값: 0=업그레이드 완료, 2=이미 최신, 1=오류
app_upgrade_codex() {
    if ! app_is_installed_codex; then
        echo "[ERROR] codex가 설치되어 있지 않습니다" >&2
        return 1
    fi
    if [ "$(_codex_installed_version)" = "${CODEX_PIN_VERSION}" ]; then
        echo "[INFO] 이미 최신 버전입니다 (${CODEX_PIN_VERSION})"
        return 2
    fi
    _codex_remove_tur_pkg
    _codex_download "${CODEX_PIN_VERSION}" || return 1
}

app_remove_codex() {
    rm -f "${CODEX_BIN_PATH}"
    _codex_remove_tur_pkg
}

app_is_installed_codex() {
    [ -x "${CODEX_BIN_PATH}" ]
}
