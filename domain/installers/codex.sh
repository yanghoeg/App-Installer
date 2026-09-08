#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Codex CLI — Termux native (업스트림 정적 musl 바이너리 + proot 네트워크 shim)
# OpenAI 코딩 에이전트 CLI. API 키/로그인은 사용자가 별도 설정.
# CLI 전용이라 .desktop 런처는 생성하지 않는다.
#
# TUR(tur-repo) 패키지는 0.122.0에서 멈춰 있어 업스트림 릴리스 tarball을 직접 받는다.
# upstream이 linux-arm64로 내놓는 빌드는 musl 정적 링크뿐이라(npm 배포판도 동일)
# glibc-runner 경로가 없고, 대신 Bionic을 안 거치는 데서 오는 문제 둘을 wrapper가 흡수한다:
#   1) DNS — musl 자체 리졸버가 /etc/resolv.conf만 읽는데 Android엔 그 경로가 없다.
#            proot로 $PREFIX/etc/resolv.conf를 /etc/resolv.conf에 bind해서 해결.
#   2) TLS — CA 번들 기본 경로(/etc/ssl/certs)가 없다. SSL_CERT_FILE로 Termux 번들 지정.
# 검증: 위 둘을 적용하면 `codex doctor`가 19 ok / 0 fail (미적용 시 DNS·reachability 실패).
#
# bubblewrap 샌드박스는 Android에서 동작 불가다(/proc/sys/kernel/overflowuid 읽기가
# SELinux에 막힘 — proot 안에서도 동일). 그래서 번들 bwrap을 함께 깔지 않는다.

CODEX_PREFIX="${PREFIX}/share/codex"
CODEX_REAL_BIN="${CODEX_PREFIX}/codex"
CODEX_BIN_PATH="${PREFIX}/bin/codex"
CODEX_TARBALL_MEMBER="codex-aarch64-unknown-linux-musl"

# 핀 버전 — 올릴 때 아래 sha256도 함께 갱신할 것
# (sha256sum codex-aarch64-unknown-linux-musl.tar.gz)
CODEX_PIN_VERSION="0.153.4"

declare -gA CODEX_TARBALL_SHA256=(
    ["0.153.4"]="5cda6182bd94c3a30f2eb63a495489ebf7f691fddb14d70f48c6c1a5071b6cde"
)

# 설치된 버전 조회 — 미설치면 빈 문자열 ("codex-cli 0.153.4" → "0.153.4")
# 래퍼가 아니라 실제 바이너리를 직접 호출한다(proot 오버헤드 회피).
_codex_installed_version() {
    [ -x "${CODEX_REAL_BIN}" ] || return 0
    "${CODEX_REAL_BIN}" --version 2>/dev/null | awk '{print $NF}'
}

# 핀 버전 tarball을 받아 바이너리를 교체한다.
# 실행 중이어도 안전하도록 임시 파일에 풀고 mv로 갈아끼운다.
_codex_download() {
    local ver="$1"
    local url="https://github.com/openai/codex/releases/download/rust-v${ver}/${CODEX_TARBALL_MEMBER}.tar.gz"
    local tmp_tgz="${TMPDIR:-/tmp}/codex-${ver}.tar.gz"
    local tmp_bin="${CODEX_REAL_BIN}.new"
    mkdir -p "${CODEX_PREFIX}"
    fetch_verified "$url" "$tmp_tgz" "${CODEX_TARBALL_SHA256[$ver]:-}" || return 1
    if ! tar xzf "$tmp_tgz" -O "${CODEX_TARBALL_MEMBER}" > "$tmp_bin"; then
        rm -f "$tmp_tgz" "$tmp_bin"; return 1
    fi
    rm -f "$tmp_tgz"
    chmod +x "$tmp_bin"
    mv -f "$tmp_bin" "${CODEX_REAL_BIN}"
}

_codex_install_wrapper() {
    cat > "${CODEX_BIN_PATH}" << EOF
#!${PREFIX}/bin/bash
# codex는 musl 정적 바이너리 — Bionic 리졸버/CA 경로를 못 쓴다. 상세는 app-installer
# domain/installers/codex.sh 주석 참조.
export SSL_CERT_FILE="\${SSL_CERT_FILE:-${PREFIX}/etc/tls/cert.pem}"
exec proot -b "${PREFIX}/etc/resolv.conf:/etc/resolv.conf" "${CODEX_REAL_BIN}" "\$@"
EOF
    chmod +x "${CODEX_BIN_PATH}"
}

# TUR dpkg 패키지가 남아 있으면 $PREFIX/bin/codex 소유권이 겹친다 → 먼저 제거
_codex_remove_tur_pkg() {
    if termux_pkg_is_installed codex; then
        termux_pkg_remove codex
    fi
    return 0
}

app_install_codex() {
    termux_pkg_install proot || return 1
    _codex_remove_tur_pkg
    if [ "$(_codex_installed_version)" != "${CODEX_PIN_VERSION}" ]; then
        _codex_download "${CODEX_PIN_VERSION}" || return 1
    fi
    _codex_install_wrapper || return 1
    echo "[Codex] 'codex' 실행 전 OPENAI_API_KEY 설정 또는 'codex login'이 필요합니다."
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
    _codex_download "${CODEX_PIN_VERSION}" || return 1
    _codex_install_wrapper
}

app_remove_codex() {
    rm -f "${CODEX_BIN_PATH}"
    rm -rf "${CODEX_PREFIX}"
    _codex_remove_tur_pkg
}

app_is_installed_codex() {
    [ -x "${CODEX_BIN_PATH}" ] && [ -x "${CODEX_REAL_BIN}" ]
}
