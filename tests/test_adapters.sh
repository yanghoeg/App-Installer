#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: 어댑터 구현 검증 (실제 명령 실행 없이 선언·구조만 검사)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
source "${SCRIPT_DIR}/framework.sh"

# =============================================================================
# pkg_termux.sh — Termux native
# =============================================================================
describe "pkg_termux.sh — 구현 검증"

_test_termux_install_uses_pkg() {
    (
        source "${APP_DIR}/adapters/output/pkg_termux.sh"
        declare -f termux_pkg_install | grep -q "pkg install"
    )
}
it "termux_pkg_install → 'pkg install -y' 사용" _test_termux_install_uses_pkg

_test_termux_remove_uses_uninstall() {
    (
        source "${APP_DIR}/adapters/output/pkg_termux.sh"
        declare -f termux_pkg_remove | grep -q "pkg uninstall"
    )
}
it "termux_pkg_remove → 'pkg uninstall -y' 사용" _test_termux_remove_uses_uninstall

_test_termux_is_installed_checks_list() {
    (
        source "${APP_DIR}/adapters/output/pkg_termux.sh"
        declare -f termux_pkg_is_installed | grep -q "list-installed"
    )
}
it "termux_pkg_is_installed → 'pkg list-installed' 사용" _test_termux_is_installed_checks_list

# =============================================================================
# pkg_ubuntu.sh — proot Ubuntu
# =============================================================================
describe "pkg_ubuntu.sh — 구현 검증"

_test_ubuntu_exec_uses_proot_distro_login() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        declare -f proot_exec | grep -q "proot-distro login"
    )
}
it "proot_exec → proot-distro login 사용" _test_ubuntu_exec_uses_proot_distro_login

_test_ubuntu_exec_wine_has_mesa_env() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        declare -f proot_exec_wine | grep -q "MESA_LOADER_DRIVER_OVERRIDE"
    )
}
it "proot_exec_wine → MESA_LOADER_DRIVER_OVERRIDE 포함" _test_ubuntu_exec_wine_has_mesa_env

_test_ubuntu_sasm_has_codename_workaround() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        # noble/oracular/plucky를 mantic으로 교체하는 로직이 있어야 함
        declare -f proot_pkg_install_sasm | grep -q "mantic"
    )
}
it "proot_pkg_install_sasm → Ubuntu codename 폴백 포함" _test_ubuntu_sasm_has_codename_workaround

_test_ubuntu_add_repo_uses_gpg() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        declare -f proot_pkg_add_external_repo | grep -q "gpg"
    )
}
it "proot_pkg_add_external_repo → GPG 키 처리 포함" _test_ubuntu_add_repo_uses_gpg

_test_ubuntu_jdk_has_fallback() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        # openjdk-21 실패 시 openjdk-11 폴백
        declare -f proot_pkg_install_jdk | grep -q "11"
    )
}
it "proot_pkg_install_jdk → openjdk-11 폴백 있음" _test_ubuntu_jdk_has_fallback

# =============================================================================
# pkg_arch.sh — proot Arch
# =============================================================================
describe "pkg_arch.sh — 구현 검증"

_test_arch_exec_uses_proot_distro_login() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_exec | grep -q "proot-distro login"
    )
}
it "proot_exec → proot-distro login 사용" _test_arch_exec_uses_proot_distro_login

_test_arch_autoremove_handles_orphans() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_autoremove | grep -q "orphans"
    )
}
it "proot_pkg_autoremove → pacman orphan 처리" _test_arch_autoremove_handles_orphans

_test_arch_aur_installs_yay_if_missing() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_install_aur | grep -q "yay"
    )
}
it "proot_pkg_install_aur → yay 없으면 자동 설치" _test_arch_aur_installs_yay_if_missing

_test_arch_box64_tries_chaotic_aur() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_install_box64 | grep -q "chaotic"
    )
}
it "proot_pkg_install_box64 → Chaotic-AUR 폴백 있음" _test_arch_box64_tries_chaotic_aur

_test_arch_deb_or_aur_delegates_to_aur() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_install_deb_or_aur | grep -q "proot_pkg_install_aur"
    )
}
it "proot_pkg_install_deb_or_aur → Arch는 AUR에 위임" _test_arch_deb_or_aur_delegates_to_aur

# =============================================================================
# proot_pkg_install_box64 — 실패 전파 (L9)
# =============================================================================
describe "proot_pkg_install_box64 — 실패 전파"

_test_ubuntu_box64_propagates_failure() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_exec()        { return 1; }
        proot_pkg_install() { return 1; }
        curl()               { return 1; }
        _proot_rootfs()      { echo "/nonexistent-test-rootfs"; }

        if proot_pkg_install_box64; then
            echo "[ASSERT] proot_exec/proot_pkg_install 실패인데 box64가 성공 처리됨" >&2
            exit 1
        fi
    )
}
it "pkg_ubuntu proot_pkg_install_box64 → 실패 시 rc!=0 전파" _test_ubuntu_box64_propagates_failure

_test_arch_box64_propagates_failure() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        proot_exec()        { return 1; }
        proot_pkg_install() { return 1; }

        if proot_pkg_install_box64; then
            echo "[ASSERT] proot_exec 실패인데 box64가 성공 처리됨" >&2
            exit 1
        fi
    )
}
it "pkg_arch proot_pkg_install_box64 → 실패 시 rc!=0 전파" _test_arch_box64_propagates_failure

# =============================================================================
# proot_pkg_add_external_repo — set -e 안전성 (L10)
# =============================================================================
describe "proot_pkg_add_external_repo — set -e 안전성"

_test_ubuntu_add_repo_script_has_set_e() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        local captured=""
        proot_exec() { captured="$*"; }
        proot_pkg_add_external_repo "test" "https://example.com/key.asc" "deb test line"
        [[ "$captured" == *"set -eo pipefail"* ]]
    )
}
it "proot_pkg_add_external_repo → bash -c 스크립트에 set -eo pipefail 있음" _test_ubuntu_add_repo_script_has_set_e

# =============================================================================
# proot_pkg_install_deb_url — sha256 검증 (M14)
# 실제 동작 테스트: 샌드박스 stub 실행파일을 PATH 선두에 두고 proot_exec를 로컬 실행으로
# 대체해, 다운로드→sha256 검증→dpkg 경로를 그대로 태운다.
# =============================================================================
describe "pkg_ubuntu.sh — proot_pkg_install_deb_url sha256"

# $1 = 샌드박스, $2 = "ok"(wget 성공) 또는 "fail"(wget/curl 모두 실패)
_deb_url_make_stubs() {
    local sb="$1" mode="${2:-ok}"
    mkdir -p "${sb}/bin" "${sb}/tmp"

    if [ "$mode" = "ok" ]; then
        cat > "${sb}/bin/wget" << 'STUB'
#!/data/data/com.termux/files/usr/bin/bash
out=""; prev=""
for a in "$@"; do [ "$prev" = "-O" ] && out="$a"; prev="$a"; done
[ -n "$out" ] || exit 1
printf 'DEB-PAYLOAD\n' > "$out"
STUB
    else
        printf '#!/data/data/com.termux/files/usr/bin/bash\nexit 1\n' > "${sb}/bin/wget"
    fi

    # curl 폴백은 항상 실패 — wget 경로/실패 전파를 명확히 갈라 보기 위함
    printf '#!/data/data/com.termux/files/usr/bin/bash\nexit 1\n' > "${sb}/bin/curl"
    printf '#!/data/data/com.termux/files/usr/bin/bash\nexec "$@"\n' > "${sb}/bin/sudo"
    cat > "${sb}/bin/dpkg" << 'STUB'
#!/data/data/com.termux/files/usr/bin/bash
echo "dpkg $*" >> "${DEB_TEST_LOG}"
STUB
    printf '#!/data/data/com.termux/files/usr/bin/bash\nexit 0\n' > "${sb}/bin/apt-get"
    cat > "${sb}/bin/apt" << 'STUB'
#!/data/data/com.termux/files/usr/bin/bash
echo "apt $*" >> "${DEB_TEST_LOG}"
STUB
    chmod +x "${sb}/bin/"*
}

_deb_url_expected_sha() { printf 'DEB-PAYLOAD\n' | sha256sum | cut -d' ' -f1; }

_test_deb_url_sha_match_installs() {
    local sb; sb=$(make_sandbox)
    _deb_url_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        export TMPDIR="${sb}/tmp"
        export DEB_TEST_LOG="${sb}/dpkg.log"
        : > "$DEB_TEST_LOG"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_exec() { "$@"; }
        local sha; sha=$(_deb_url_expected_sha)
        proot_pkg_install_deb_url "https://example.invalid/foo.deb|${sha}" || {
            echo "[ASSERT] sha 일치인데 rc!=0" >&2; exit 1; }
        assert_file_contains "$DEB_TEST_LOG" "foo.deb"
    )
    local rc=$?
    cleanup_sandbox "$sb"
    return "$rc"
}
it "sha256 일치 → dpkg 호출 + rc 0" _test_deb_url_sha_match_installs

_test_deb_url_sha_mismatch_aborts() {
    local sb; sb=$(make_sandbox)
    _deb_url_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        export TMPDIR="${sb}/tmp"
        export DEB_TEST_LOG="${sb}/dpkg.log"
        : > "$DEB_TEST_LOG"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_exec() { "$@"; }
        local rc=0
        proot_pkg_install_deb_url \
            "https://example.invalid/foo.deb|deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
            2>/dev/null || rc=$?
        assert_nonzero "$rc" "sha256 불일치인데 rc 0" || exit 1
        if [ -s "$DEB_TEST_LOG" ]; then
            echo "[ASSERT] sha256 불일치인데 dpkg가 호출됨: $(cat "$DEB_TEST_LOG")" >&2
            exit 1
        fi
        if [ -e "${TMPDIR}/foo.deb" ]; then
            echo "[ASSERT] sha256 불일치인데 받은 .deb가 남아 있음" >&2
            exit 1
        fi
    )
    local rc=$?
    cleanup_sandbox "$sb"
    return "$rc"
}
it "sha256 불일치 → dpkg 미호출 + .deb 삭제 + rc!=0" _test_deb_url_sha_mismatch_aborts

_test_deb_url_without_sha_installs() {
    local sb; sb=$(make_sandbox)
    _deb_url_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        export TMPDIR="${sb}/tmp"
        export DEB_TEST_LOG="${sb}/dpkg.log"
        : > "$DEB_TEST_LOG"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_exec() { "$@"; }
        proot_pkg_install_deb_url "https://example.invalid/bar.deb" || {
            echo "[ASSERT] sha 미지정인데 rc!=0" >&2; exit 1; }
        assert_file_contains "$DEB_TEST_LOG" "bar.deb"
    )
    local rc=$?
    cleanup_sandbox "$sb"
    return "$rc"
}
it "sha256 미지정 → 검증 생략하고 dpkg 호출 + rc 0" _test_deb_url_without_sha_installs

_test_deb_url_download_failure_propagates() {
    local sb; sb=$(make_sandbox)
    _deb_url_make_stubs "$sb" fail
    (
        export PATH="${sb}/bin:${PATH}"
        export TMPDIR="${sb}/tmp"
        export DEB_TEST_LOG="${sb}/dpkg.log"
        : > "$DEB_TEST_LOG"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_exec() { "$@"; }
        local rc=0
        proot_pkg_install_deb_url "https://example.invalid/baz.deb" 2>/dev/null || rc=$?
        assert_nonzero "$rc" "wget/curl 모두 실패인데 rc 0" || exit 1
        if [ -s "$DEB_TEST_LOG" ]; then
            echo "[ASSERT] 다운로드 실패인데 dpkg가 호출됨" >&2
            exit 1
        fi
    )
    local rc=$?
    cleanup_sandbox "$sb"
    return "$rc"
}
it "다운로드 실패(wget+curl) → rc!=0" _test_deb_url_download_failure_propagates

_test_arch_deb_url_unsupported() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        local rc=0
        proot_pkg_install_deb_url "https://example.invalid/foo.deb" 2>/dev/null || rc=$?
        assert_nonzero "$rc" "Arch는 .deb 직접 설치를 지원하지 않으므로 rc!=0이어야 함"
    )
}
it "pkg_arch.sh — .deb 직접 설치 미지원 → rc 1" _test_arch_deb_url_unsupported

# =============================================================================
# lib/common.sh — 하위 호환 래퍼
# =============================================================================
describe "lib/common.sh — 하위 호환 API"

_test_common_exposes_legacy_api() {
    (
        source "${APP_DIR}/lib/common.sh" 2>/dev/null || true
        declare -f _prun >/dev/null 2>&1 && \
        declare -f _pkg_install >/dev/null 2>&1 && \
        declare -f _pkg_remove >/dev/null 2>&1 && \
        declare -f _load_config >/dev/null 2>&1
    )
}
it "_prun, _pkg_install, _pkg_remove, _load_config 함수 존재" _test_common_exposes_legacy_api

# =============================================================================
# proot_pkg_install_deb_or_aur — sha256 3번째 인자 (M10)
# =============================================================================
describe "pkg_ubuntu.sh — proot_pkg_install_deb_or_aur sha256"

_test_deb_or_aur_sha_match_installs() {
    local sb; sb=$(make_sandbox)
    _deb_url_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        export TMPDIR="${sb}/tmp"
        export DEB_TEST_LOG="${sb}/apt.log"
        : > "$DEB_TEST_LOG"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_exec() { "$@"; }
        local sha; sha=$(_deb_url_expected_sha)
        proot_pkg_install_deb_or_aur "https://example.invalid/deb-or-aur-test.deb" "pkg" "$sha" || {
            echo "[ASSERT] sha 일치인데 rc!=0" >&2; exit 1; }
        assert_file_contains "$DEB_TEST_LOG" "deb-or-aur-test.deb"
    )
    local rc=$?
    cleanup_sandbox "$sb"
    return "$rc"
}
it "deb_or_aur sha256 일치 → apt install 호출 + rc 0" _test_deb_or_aur_sha_match_installs

_test_deb_or_aur_sha_mismatch_aborts() {
    local sb; sb=$(make_sandbox)
    _deb_url_make_stubs "$sb" ok
    (
        export PATH="${sb}/bin:${PATH}"
        export TMPDIR="${sb}/tmp"
        export DEB_TEST_LOG="${sb}/apt.log"
        : > "$DEB_TEST_LOG"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_exec() { "$@"; }
        local rc=0
        proot_pkg_install_deb_or_aur "https://example.invalid/deb-or-aur-test.deb" "pkg" \
            "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" 2>/dev/null || rc=$?
        assert_nonzero "$rc" "sha256 불일치인데 rc 0" || exit 1
        if [ -s "$DEB_TEST_LOG" ]; then
            echo "[ASSERT] sha256 불일치인데 apt가 호출됨: $(cat "$DEB_TEST_LOG")" >&2
            exit 1
        fi
        if [ -e "${TMPDIR}/deb-or-aur-test.deb" ]; then
            echo "[ASSERT] sha256 불일치인데 받은 .deb가 남아 있음" >&2
            exit 1
        fi
    )
    local rc=$?
    cleanup_sandbox "$sb"
    return "$rc"
}
it "deb_or_aur sha256 불일치 → apt 미호출 + .deb 삭제 + rc!=0" _test_deb_or_aur_sha_mismatch_aborts

_test_arch_deb_or_aur_ignores_sha() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        local captured=""
        proot_pkg_install_aur() { captured="$*"; }
        proot_pkg_install_deb_or_aur "https://example.invalid/x.deb" "teams-for-linux" \
            "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
        assert_eq "teams-for-linux" "$captured" "Arch는 sha를 무시하고 AUR 패키지명만 넘긴다"
    )
}
it "pkg_arch deb_or_aur → sha256 인자를 무시하고 AUR에 위임" _test_arch_deb_or_aur_ignores_sha

# =============================================================================
# proot_pkg_install_box64 — 죽은 GitHub .deb 경로 제거 (M10)
# =============================================================================
describe "pkg_ubuntu.sh — box64 GitHub 경로 제거"

_test_ubuntu_box64_has_no_github_api() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        if declare -f proot_pkg_install_box64 | grep -q 'api\.github\.com'; then
            echo "[ASSERT] proot_pkg_install_box64에 GitHub API 조회가 남아 있음" >&2
            exit 1
        fi
        if declare -f proot_pkg_install_box64 | grep -q 'box64_Ubuntu_'; then
            echo "[ASSERT] proot_pkg_install_box64에 .deb 미제공 에셋 경로가 남아 있음" >&2
            exit 1
        fi
        declare -f proot_pkg_install_box64 | grep -q 'proot_pkg_install box64'
    )
}
it "proot_pkg_install_box64 → GitHub 릴리스 경로 없이 apt만 사용" _test_ubuntu_box64_has_no_github_api

print_results
