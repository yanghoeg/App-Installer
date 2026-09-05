#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: lib/fetch.sh — 다운로드 무결성 (M10)
# PATH stub 실행파일로 wget/curl을 대체해 실제 다운로드→sha256 경로를 그대로 태운다.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
source "${SCRIPT_DIR}/framework.sh"

_FETCH_PAYLOAD='FETCH-PAYLOAD'

# $1 = 샌드박스, $2 = "ok"(wget 성공) | "fail"(wget/curl 모두 실패)
_fetch_make_stubs() {
    local sb="$1" mode="${2:-ok}"
    mkdir -p "${sb}/bin"
    if [ "$mode" = "ok" ]; then
        cat > "${sb}/bin/wget" << 'STUB'
#!/bin/bash
out=""; prev=""
for a in "$@"; do [ "$prev" = "-O" ] && out="$a"; prev="$a"; done
[ -n "$out" ] || exit 1
printf 'FETCH-PAYLOAD\n' > "$out"
STUB
    else
        printf '#!/bin/bash\nexit 1\n' > "${sb}/bin/wget"
    fi
    # curl 폴백은 항상 실패 — wget 경로/실패 전파를 명확히 갈라 보기 위함
    printf '#!/bin/bash\nexit 1\n' > "${sb}/bin/curl"
    chmod +x "${sb}/bin/"*
}

_fetch_expected_sha() { printf 'FETCH-PAYLOAD\n' | sha256sum | cut -d' ' -f1; }

describe "lib/fetch.sh — fetch_verified 실동작"

_test_fetch_sha_match() {
    local sb; sb=$(make_sandbox); _fetch_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        source "${APP_DIR}/lib/fetch.sh"
        local dest="${sb}/out.bin" sha; sha=$(_fetch_expected_sha)
        fetch_verified "https://example.invalid/x" "$dest" "$sha" || {
            echo "[ASSERT] sha 일치인데 rc!=0" >&2; exit 1; }
        assert_file_exists "$dest"
    )
    local rc=$?; cleanup_sandbox "$sb"; return "$rc"
}
it "sha256 일치 → rc 0 + 파일 존재" _test_fetch_sha_match

_test_fetch_sha_mismatch() {
    local sb; sb=$(make_sandbox); _fetch_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        source "${APP_DIR}/lib/fetch.sh"
        local dest="${sb}/out.bin" rc=0
        fetch_verified "https://example.invalid/x" "$dest" \
            "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" 2>/dev/null || rc=$?
        assert_nonzero "$rc" "sha256 불일치인데 rc 0" || exit 1
        if [ -e "$dest" ]; then
            echo "[ASSERT] sha256 불일치인데 받은 파일이 남아 있음" >&2; exit 1
        fi
    )
    local rc=$?; cleanup_sandbox "$sb"; return "$rc"
}
it "sha256 불일치 → rc!=0 + 파일 삭제" _test_fetch_sha_mismatch

_test_fetch_sha_omitted_warns() {
    local sb; sb=$(make_sandbox); _fetch_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        source "${APP_DIR}/lib/fetch.sh"
        local dest="${sb}/out.bin" err
        err=$(fetch_verified "https://example.invalid/x" "$dest" 2>&1 >/dev/null) || {
            echo "[ASSERT] sha 미지정인데 rc!=0" >&2; exit 1; }
        assert_file_exists "$dest" || exit 1
        assert_output_contains "$err" "WARN"
    )
    local rc=$?; cleanup_sandbox "$sb"; return "$rc"
}
it "sha256 생략 → rc 0 + stderr WARN" _test_fetch_sha_omitted_warns

_test_fetch_download_failure() {
    local sb; sb=$(make_sandbox); _fetch_make_stubs "$sb" fail
    (
        export PATH="${sb}/bin:${PATH}"
        source "${APP_DIR}/lib/fetch.sh"
        local dest="${sb}/out.bin" rc=0
        fetch_verified "https://example.invalid/x" "$dest" "" 2>/dev/null || rc=$?
        assert_nonzero "$rc" "wget/curl 모두 실패인데 rc 0" || exit 1
        if [ -e "$dest" ]; then
            echo "[ASSERT] 다운로드 실패인데 파일이 남아 있음" >&2; exit 1
        fi
    )
    local rc=$?; cleanup_sandbox "$sb"; return "$rc"
}
it "wget·curl 모두 실패 → rc!=0 + 파일 없음" _test_fetch_download_failure

describe "lib/fetch.sh — fetch_verified_src 텍스트 주입"

_test_fetch_src_loads_in_subshell() {
    (
        source "${APP_DIR}/lib/fetch.sh"
        local out
        out=$(bash -c "$(fetch_verified_src)
declare -F fetch_verified")
        assert_output_contains "$out" "fetch_verified"
    )
}
it "fetch_verified_src 출력이 bash -c에서 함수로 로드된다" _test_fetch_src_loads_in_subshell

_test_fetch_src_runs_in_subshell() {
    local sb; sb=$(make_sandbox); _fetch_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        source "${APP_DIR}/lib/fetch.sh"
        local sha; sha=$(_fetch_expected_sha)
        bash -c "$(fetch_verified_src)"$'\n''
            set -e
            fetch_verified "$1" "$2" "$3"
        ' _ "https://example.invalid/x" "${sb}/sub.bin" "$sha" || {
            echo "[ASSERT] 주입된 fetch_verified가 서브셸에서 실패" >&2; exit 1; }
        assert_file_exists "${sb}/sub.bin"
    )
    local rc=$?; cleanup_sandbox "$sb"; return "$rc"
}
it "주입된 fetch_verified가 bash -c 스니펫 안에서 위치인자로 동작한다" _test_fetch_src_runs_in_subshell

describe "다운로드 무결성 — GitHub API latest 조회 제거 (M10)"

# releases/latest·api.github.com은 재현 불가능한 설치(핀 없음) + sha256 검증 불가로 이어진다.
# llama_cpp.sh는 사용자 선택 모델 데이터라 범위 밖. 주석 줄(핀 근거 기록)도 제외한다.
_test_no_github_api_latest() {
    local hits
    hits=$(command grep -rn 'api\.github\.com\|releases/latest' \
        "${APP_DIR}/domain" "${APP_DIR}/adapters" "${APP_DIR}/lib" 2>/dev/null \
        | command grep -v '/llama_cpp\.sh:' \
        | command grep -vE ':[0-9]+:[[:space:]]*#' || true)
    if [ -n "$hits" ]; then
        echo "[ASSERT] GitHub API latest 조회가 남아 있음:" >&2
        printf '%s\n' "$hits" >&2
        return 1
    fi
}
it "domain/adapters/lib에 api.github.com·releases/latest 없음 (llama_cpp 제외)" _test_no_github_api_latest

print_results
