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
# 검증: 위 둘을 적용하면 `codex doctor`가 20 ok / 0 fail (미적용 시 DNS·reachability 실패).
#
# bubblewrap 샌드박스는 Android에서 동작 불가다(/proc/sys/kernel/overflowuid 읽기가
# SELinux에 막힘 — proot 안에서도 동일). 그래서 번들 bwrap을 함께 깔지 않는다.
#
# 단일 바이너리 설치라서 추가로 두 가지를 더 흡수한다:
#   3) 백그라운드 서버 — 0.157.0부터 `daemon_auto_start`가 기본 on이고, 그 데몬은
#      "완전한 CLI 패키지"(codex-package.json + bin/ + codex-path/rg + codex-resources/bwrap)를
#      요구한다. 단일 바이너리에는 그 레이아웃이 없어 TUI 기동이
#      "this CLI has no complete local package"로 즉사한다(0.159.3 실측).
#      래퍼가 `-c features.daemon_auto_start=false`를 주입해 임베디드 모드로 고정한다.
#      대가: 공유 서버가 필요한 `codex agents` / `/daemon`은 쓸 수 없다.
#      패키지 tarball(codex-package-*)로 바꾸면 데몬이 살아나지만, 그 데몬의 updater가
#      스스로 최신 버전을 내려받아 이 파일의 핀/sha256 정책을 우회한다 — 그래서 안 쓴다.
#   4) Code Mode — 헬퍼 바이너리를 "codex 실행 파일과 같은 디렉터리의
#      codex-code-mode-host"에서 찾는다(upstream install-context). 없으면 Code Mode가
#      fail-closed 되며 경고가 뜬다. 같은 핀 버전의 헬퍼를 나란히 설치한다.

CODEX_PREFIX="${PREFIX}/share/codex"
CODEX_REAL_BIN="${CODEX_PREFIX}/codex"
CODEX_BIN_PATH="${PREFIX}/bin/codex"
# 헬퍼 파일명은 upstream이 고정 — 바꾸면 Code Mode가 못 찾는다.
CODEX_CMH_BIN="${CODEX_PREFIX}/codex-code-mode-host"
CODEX_TARBALL_MEMBER="codex-aarch64-unknown-linux-musl"
CODEX_CMH_TARBALL_MEMBER="codex-code-mode-host-aarch64-unknown-linux-musl"

# 핀 버전 — 올릴 때 아래 sha256 둘도 함께 갱신할 것
# (sha256sum codex-aarch64-unknown-linux-musl.tar.gz
#            codex-code-mode-host-aarch64-unknown-linux-musl.tar.gz)
CODEX_PIN_VERSION="0.159.3"

declare -gA CODEX_TARBALL_SHA256=(
    ["0.153.4"]="5cda6182bd94c3a30f2eb63a495489ebf7f691fddb14d70f48c6c1a5071b6cde"
    ["0.159.3"]="cd5f307b3fcd6080773e684b86c3114a67d4f1c61dc447be09876b552eb4bea7"
)

# code-mode 헬퍼 tarball sha256 — codex 본체와 같은 릴리스 태그에서 받는다.
declare -gA CODEX_CMH_SHA256=(
    ["0.159.3"]="7cbb47c472c2dc115abfeebf52ff11bf66eb364bf8f5d14659742615919b8e6f"
)

# 설치된 버전 조회 — 미설치면 빈 문자열 ("codex-cli 0.153.4" → "0.153.4")
# 래퍼가 아니라 실제 바이너리를 직접 호출한다(proot 오버헤드 회피).
_codex_installed_version() {
    [ -x "${CODEX_REAL_BIN}" ] || return 0
    "${CODEX_REAL_BIN}" --version 2>/dev/null | awk '{print $NF}'
}

# 핀 버전 tarball에서 바이너리 하나를 받아 교체한다.
# 실행 중이어도 안전하도록 임시 파일에 풀고 mv로 갈아끼운다.
# _codex_fetch_binary <ver> <tarball-member> <dest> <sha256>
_codex_fetch_binary() {
    local ver="$1" member="$2" dest="$3" sha="$4"
    local url="https://github.com/openai/codex/releases/download/rust-v${ver}/${member}.tar.gz"
    local tmp_tgz="${TMPDIR:-/tmp}/${member}-${ver}.tar.gz"
    local tmp_bin="${dest}.new"
    mkdir -p "${CODEX_PREFIX}"
    fetch_verified "$url" "$tmp_tgz" "$sha" || return 1
    if ! tar xzf "$tmp_tgz" -O "${member}" > "$tmp_bin"; then
        rm -f "$tmp_tgz" "$tmp_bin"; return 1
    fi
    rm -f "$tmp_tgz"
    chmod +x "$tmp_bin"
    mv -f "$tmp_bin" "$dest"
}

_codex_download() {
    local ver="$1"
    _codex_fetch_binary "$ver" "${CODEX_TARBALL_MEMBER}" "${CODEX_REAL_BIN}" \
        "${CODEX_TARBALL_SHA256[$ver]:-}" || return 1
    _codex_fetch_binary "$ver" "${CODEX_CMH_TARBALL_MEMBER}" "${CODEX_CMH_BIN}" \
        "${CODEX_CMH_SHA256[$ver]:-}"
}

_codex_install_wrapper() {
    cat > "${CODEX_BIN_PATH}" << EOF
#!${PREFIX}/bin/bash
# codex는 musl 정적 바이너리 — Bionic 리졸버/CA 경로를 못 쓴다. 단일 바이너리라
# 백그라운드 서버(데몬)도 쓸 수 없다. 상세는 app-installer
# domain/installers/codex.sh 주석 참조.
export SSL_CERT_FILE="\${SSL_CERT_FILE:-${PREFIX}/etc/tls/cert.pem}"
exec proot -b "${PREFIX}/etc/resolv.conf:/etc/resolv.conf" "${CODEX_REAL_BIN}" \\
    -c features.daemon_auto_start=false "\$@"
EOF
    chmod +x "${CODEX_BIN_PATH}"
}

# TUR dpkg 패키지가 남아 있으면 $PREFIX/bin/codex 소유권이 겹친다 → 먼저 제거
_codex_remove_tur_pkg() {
    if termux_pkg_is_installed codex; then
        termux_pkg_remove codex || return 1
    fi
    return 0
}

app_install_codex() {
    termux_pkg_install proot || return 1
    _codex_remove_tur_pkg || return 1
    # 헬퍼가 빠진 과거 설치도 여기서 메꿔진다.
    if [ "$(_codex_installed_version)" != "${CODEX_PIN_VERSION}" ] || [ ! -x "${CODEX_CMH_BIN}" ]; then
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
    if [ "$(_codex_installed_version)" = "${CODEX_PIN_VERSION}" ] && [ -x "${CODEX_CMH_BIN}" ]; then
        echo "[INFO] 이미 최신 버전입니다 (${CODEX_PIN_VERSION})"
        return 2
    fi
    _codex_download "${CODEX_PIN_VERSION}" || return 1
    _codex_install_wrapper
}

app_remove_codex() {
    _codex_remove_tur_pkg || return 1
    rm -f "${CODEX_BIN_PATH}" || return 1
    rm -rf "${CODEX_PREFIX}"
}

app_is_installed_codex() {
    [ -x "${CODEX_BIN_PATH}" ] && [ -x "${CODEX_REAL_BIN}" ]
}
