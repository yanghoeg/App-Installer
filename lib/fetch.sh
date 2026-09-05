#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# LIB: fetch.sh — 다운로드 무결성 공통 헬퍼
# =============================================================================
# 세 실행 문맥에서 같은 검증 로직을 쓴다:
#   (a) Termux native 함수 안에서 직접 호출
#   (b) proot_exec bash -c '<snippet>' 안 (별도 셸)
#   (c) wine_exec_shell "<snippet>" 안 (proot 또는 Termux native)
# (b)(c)는 별도 셸이므로 fetch_verified_src()로 함수 정의를 텍스트 주입한다.

# fetch_verified <url> <dest> [sha256]
#   wget -q → curl -fsSL 폴백으로 다운로드.
#   sha256이 주어지면 검증하고, 불일치 시 dest를 지우고 rc 1.
#   sha256이 빈 문자열이면 검증을 생략한다(경고 1줄).
#   다운로드 실패(또는 빈 파일)도 dest를 지우고 rc 1.
fetch_verified() {
    local url="$1" dest="$2" sha="${3:-}" got
    if ! { wget -q -O "$dest" "$url" 2>/dev/null || curl -fsSL -o "$dest" "$url"; } || [ ! -s "$dest" ]; then
        rm -f "$dest"; echo "[ERROR] 다운로드 실패: $url" >&2; return 1
    fi
    if [ -z "$sha" ]; then echo "[WARN] sha256 미등록 — 검증 생략: ${dest##*/}" >&2; return 0; fi
    got=$(sha256sum "$dest" | cut -d' ' -f1)
    if [ "$got" != "$sha" ]; then
        rm -f "$dest"; echo "[ERROR] sha256 불일치: ${dest##*/} (기대 $sha, 실제 $got)" >&2; return 1
    fi
    return 0
}

# fetch_verified 정의를 텍스트로 출력 — 별도 셸(bash -c) 스니펫 선두에 주입한다.
fetch_verified_src() { declare -f fetch_verified; }
