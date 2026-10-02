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
        grep -q "pkg install" <<< "$(declare -f termux_pkg_install)"
    )
}
it "termux_pkg_install → 'pkg install -y' 사용" _test_termux_install_uses_pkg

_test_termux_remove_uses_uninstall() {
    (
        source "${APP_DIR}/adapters/output/pkg_termux.sh"
        grep -q "pkg uninstall" <<< "$(declare -f termux_pkg_remove)"
    )
}
it "termux_pkg_remove → 'pkg uninstall -y' 사용" _test_termux_remove_uses_uninstall

_test_termux_is_installed_checks_status() {
    (
        source "${APP_DIR}/adapters/output/pkg_termux.sh"
        local implementation
        implementation=$(declare -f termux_pkg_is_installed)
        [[ "$implementation" == *'dpkg-query'* ]] && [[ "$implementation" == *'ok installed'* ]]
    )
}
it "termux_pkg_is_installed → exact dpkg installed status" _test_termux_is_installed_checks_status

# =============================================================================
# pkg_ubuntu.sh — proot Ubuntu
# =============================================================================
describe "pkg_ubuntu.sh — 구현 검증"

_test_ubuntu_exec_uses_proot_distro_login() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        grep -q "proot-distro login" <<< "$(declare -f proot_exec)"
    )
}
it "proot_exec → proot-distro login 사용" _test_ubuntu_exec_uses_proot_distro_login

_test_ubuntu_exec_wine_has_mesa_env() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        grep -q -- '--noprofile --norc' <<< "$(declare -f proot_exec_wine)"
        grep -q -- 'gpu-accel.sh' <<< "$(declare -f proot_exec_wine)"
        ! grep -q 'MESA_LOADER_DRIVER_OVERRIDE=zink' <<< "$(declare -f proot_exec_wine)"
    )
}
it "proot_exec_wine loads the optional container profile" _test_ubuntu_exec_wine_has_mesa_env

_test_proot_exec_does_not_force_display() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        export PROOT_DISTRO=ubuntu PROOT_USER=testuser DISPLAY=:91
        proot-distro() { printf '%s\n' "$@"; }
        local out
        out=$(proot_exec true)
        assert_output_contains "$out" 'DISPLAY=:91'
        unset DISPLAY
        out=$(proot_exec true)
        [[ "$out" != *DISPLAY=* ]]
    )
}
it "proot execution inherits DISPLAY instead of forcing a default" _test_proot_exec_does_not_force_display

_test_ubuntu_sasm_uses_active_distro_apt() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        local implementation
        implementation="$(declare -f proot_pkg_install_sasm)"
        [[ "$implementation" == *"apt-get install -y sasm"* ]] &&
            [[ "$implementation" != *"jammy"* ]] &&
            [[ "$implementation" != *"sed -i"* ]]
    )
}
it "proot_pkg_install_sasm → active distro APT without suite rewrite" _test_ubuntu_sasm_uses_active_distro_apt

_test_ubuntu_add_repo_uses_gpg() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        grep -q "gpg" <<< "$(declare -f proot_pkg_add_external_repo)"
    )
}
it "proot_pkg_add_external_repo → GPG 키 처리 포함" _test_ubuntu_add_repo_uses_gpg

# =============================================================================
# pkg_arch.sh — proot Arch
# =============================================================================
describe "pkg_arch.sh — 구현 검증"

_test_arch_exec_uses_proot_distro_login() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        grep -q "proot-distro login" <<< "$(declare -f proot_exec)"
    )
}
it "proot_exec → proot-distro login 사용" _test_arch_exec_uses_proot_distro_login

_test_arch_autoremove_handles_orphans() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        grep -q "orphans" <<< "$(declare -f proot_pkg_autoremove)"
    )
}
it "proot_pkg_autoremove → pacman orphan 처리" _test_arch_autoremove_handles_orphans

_test_arch_aur_installs_yay_if_missing() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        grep -q "yay" <<< "$(declare -f proot_pkg_install_aur)"
    )
}
it "proot_pkg_install_aur → yay 없으면 자동 설치" _test_arch_aur_installs_yay_if_missing

_test_arch_box64_uses_pinned_upstream_source() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        local implementation
        implementation="$(declare -f proot_pkg_install_box64)"
        [[ "$implementation" == *"box64_build_source_script"* ]] &&
            [[ "$implementation" != *"chaotic"* ]] &&
            [[ "$implementation" != *"lib32-mesa"* ]]
    )
}
it "proot_pkg_install_box64 → pinned upstream source, no Chaotic-AUR" _test_arch_box64_uses_pinned_upstream_source

_test_arch_deb_or_aur_delegates_to_aur() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        grep -q "proot_pkg_install_aur" <<< "$(declare -f proot_pkg_install_deb_or_aur)"
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
# proot_pkg_add_external_repo — failure propagation without obsolete bootstrap packages
# =============================================================================
describe "proot_pkg_add_external_repo — failure propagation"

_test_ubuntu_add_repo_script_is_strict_and_no_bootstrap_packages() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        local captured=""
        proot_exec() { captured="$*"; }
        proot_pkg_add_external_repo "test" "https://example.com/key.asc" "deb test line"
        [[ "$captured" == *"set -eu"* ]] &&
            [[ "$captured" != *"apt-transport-https"* ]] &&
            [[ "$captured" != *"software-properties-common"* ]]
    )
}
it "proot_pkg_add_external_repo → strict and no obsolete bootstrap packages" _test_ubuntu_add_repo_script_is_strict_and_no_bootstrap_packages

_test_ubuntu_add_repo_propagates_failure() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_exec() { return 37; }
        local rc=0
        proot_pkg_add_external_repo "test" "https://example.com/key.asc" "deb test line" || rc=$?
        assert_eq 37 "$rc"
    )
}
it "proot_pkg_add_external_repo returns its failed proot command status" _test_ubuntu_add_repo_propagates_failure

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
    cat > "${sb}/bin/dpkg-deb" << 'STUB'
#!/data/data/com.termux/files/usr/bin/bash
case "$3" in
    Package) name="${2##*/}"; printf '%s\n' "${name%.deb}" ;;
    Version) printf '1.0\n' ;;
    Architecture) printf 'arm64\n' ;;
    *) exit 99 ;;
esac
STUB
    cat > "${sb}/bin/dpkg-query" << 'STUB'
#!/data/data/com.termux/files/usr/bin/bash
printf 'install ok installed|1.0|arm64'
STUB
    printf '#!/data/data/com.termux/files/usr/bin/bash\nexit 0\n' > "${sb}/bin/apt-get"
    cat > "${sb}/bin/apt" << 'STUB'
#!/data/data/com.termux/files/usr/bin/bash
echo "apt $*" >> "${DEB_TEST_LOG}"
STUB
    # Use the current interpreter on both Linux hosts and Termux devices.
    local stub
    for stub in "${sb}/bin/"*; do sed -i "1c\\#!${BASH}" "$stub"; done
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
# lib/common.sh — shared configuration
# =============================================================================
describe "lib/common.sh — shared configuration API"

_test_common_exposes_only_current_config_api() {
    (
        source "${APP_DIR}/lib/common.sh" 2>/dev/null || true
        declare -f _load_app_config >/dev/null 2>&1 && \
        declare -f _detect_proot_user >/dev/null 2>&1 && \
        ! declare -f _load_config >/dev/null 2>&1 && \
        ! declare -f _prun >/dev/null 2>&1
    )
}
it "keeps config/user helpers and removes obsolete compatibility wrappers" _test_common_exposes_only_current_config_api

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
# proot_pkg_install_box64 — pinned upstream source build
# =============================================================================
describe "pkg_ubuntu.sh — box64 GitHub 경로 제거"

_test_ubuntu_box64_uses_pinned_upstream_source() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        grep -q 'box64_build_source_script' <<< "$(declare -f proot_pkg_install_box64)"
        grep -q '2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a' <<< "$(declare -f box64_build_source_script)"
    )
}
it "proot_pkg_install_box64 → verified upstream source revision" _test_ubuntu_box64_uses_pinned_upstream_source

_test_arch_wine_mesa_has_no_32bit_package() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        ! grep -q 'lib32-' <<< "$(declare -f proot_pkg_install_wine_mesa)"
    )
}
it "Arch Wine Mesa dependencies stay 64-bit" _test_arch_wine_mesa_has_no_32bit_package

_test_gpu_tools_are_distro_specific() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        grep -q 'mesa-utils vulkan-tools' <<< "$(declare -f proot_pkg_install_gpu_tools)"
    ) && (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        grep -q 'mesa-demos vulkan-tools' <<< "$(declare -f proot_pkg_install_gpu_tools)"
    )
}
it "GPU diagnostic tools use distro-specific packages" _test_gpu_tools_are_distro_specific

describe 'Arch removal — propagate failures'
_test_arch_vscode_remove_failure() {
    source "${APP_DIR}/adapters/output/pkg_arch.sh"
    local removed="" rc=0
    proot_pkg_is_installed() { [ "$1" = visual-studio-code-bin ]; }
    proot_pkg_remove() { removed="$1"; return 42; }
    if proot_pkg_remove_vscode; then rc=0; else rc=$?; fi
    assert_eq 42 "$rc"
    assert_eq visual-studio-code-bin "$removed"
}
it 'VS Code removal failure is not hidden by trying a different package' _test_arch_vscode_remove_failure

_test_arch_autoremove_failure() {
    source "${APP_DIR}/adapters/output/pkg_arch.sh"
    # Execute the actual container snippet with a fake pacman, without sudo/proot.
    proot_exec() { shift; "$@"; }
    pacman() {
        if [ "$1" = -Qdtq ]; then echo unused-package; return 0; fi
        return 42
    }
    export -f pacman
    local rc=0
    if proot_pkg_autoremove; then rc=0; else rc=$?; fi
    assert_eq 42 "$rc"
}
it 'orphan package removal failure is returned from the container shell' _test_arch_autoremove_failure

_test_arch_autoremove_empty() {
    source "${APP_DIR}/adapters/output/pkg_arch.sh"
    proot_exec() { shift; "$@"; }
    pacman() {
        if [ "$1" = -Qdtq ]; then return 1; fi
        return 42
    }
    export -f pacman
    proot_pkg_autoremove
}
it 'no orphan packages remains a successful no-op' _test_arch_autoremove_empty

describe 'Pinned source-build contracts'

_test_box64_build_uses_private_temp_dir() {
    (
        source "${APP_DIR}/lib/build_box64.sh"
        local script
        script="$(box64_build_source_script)"
        [[ "$script" == *'mktemp -d "${TMPDIR:-/tmp}/box64-${box64_version}.XXXXXX"'* ]] &&
            [[ "$script" == *"trap 'rm -rf \"\$box64_src\"' EXIT"* ]] &&
            [[ "$script" != *'/tmp/box64-'* ]] &&
            [[ "$script" == *'2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a'* ]]
    )
}
it 'Box64 source build uses a trapped mktemp directory and exact revision' _test_box64_build_uses_private_temp_dir

_test_arch_sasm_uses_pinned_build_and_install_target() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        local packages='' command=''
        proot_pkg_install() { packages="$*"; }
        proot_exec() { command="$*"; }
        proot_pkg_install_sasm
        [[ "$packages" == 'nasm qt5-base qt5-tools make gcc git' ]] &&
            [[ "$command" == *'sasm_version='\''3.16.0'\'''* ]] &&
            [[ "$command" == *'c622d5a0f00e1391171b372dac42af0f54dc2538'* ]] &&
            [[ "$command" == *'make install'* ]] &&
            [[ "$command" == *'/usr/share/sasm'* ]]
    )
}
it 'Arch SASM installs the pinned release with its runtime data' _test_arch_sasm_uses_pinned_build_and_install_target

print_results
