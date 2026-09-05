#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: 도메인 앱 인스톨러 — mock 어댑터로 비즈니스 로직 검증
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
source "${SCRIPT_DIR}/framework.sh"
source "${SCRIPT_DIR}/mocks.sh"

# 공통 설정: sandbox + mock 어댑터 + 도메인 로드
_setup() {
    local sb="$1"
    export PROOT_DISTRO="ubuntu"
    export PROOT_USER="testuser"
    setup_fs_sandbox "$sb"
    source "${APP_DIR}/ports/pkg_manager.sh"
    source "${APP_DIR}/lib/fetch.sh"
    unset _WINE_BACKEND_SH   # 샌드박스마다 HOME/PREFIX가 바뀌므로 재소싱 강제
    source "${APP_DIR}/lib/wine_backend.sh"
    source "${APP_DIR}/domain/desktop.sh"
    source "${APP_DIR}/domain/apps.sh"
    for _f in "${APP_DIR}/domain/installers/"*.sh; do source "$_f"; done
    mock_pkg_adapter  # 도메인 소싱 후 override — has_proot_distro 포함
    reset_mock_calls
}

# =============================================================================
# APP_REGISTRY — 레지스트리 구조 검증
# =============================================================================
describe "APP_REGISTRY — 구조 검증"

_test_registry_not_empty() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    assert_nonzero "${#APP_REGISTRY[@]}" "APP_REGISTRY가 비어 있음"
    cleanup_sandbox "$sb"
}
it "APP_REGISTRY가 비어 있지 않다" _test_registry_not_empty

_test_registry_all_have_three_fields() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local failed=0
    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r id name desc <<< "$entry"
        if [ -z "$id" ] || [ -z "$name" ] || [ -z "$desc" ]; then
            echo "[ASSERT] 불완전한 APP_REGISTRY 항목: '${entry}'" >&2
            failed=1
        fi
    done
    cleanup_sandbox "$sb"
    return "$failed"
}
it "모든 APP_REGISTRY 항목은 id|name|desc 세 필드를 가진다" _test_registry_all_have_three_fields

_test_registry_all_have_installer_functions() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local failed=0
    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r id _ _ <<< "$entry"
        for fn in "app_install_${id}" "app_remove_${id}" "app_is_installed_${id}"; do
            if ! declare -f "$fn" >/dev/null 2>&1; then
                echo "[ASSERT] 함수 미정의: ${fn}" >&2
                failed=1
            fi
        done
    done
    cleanup_sandbox "$sb"
    return "$failed"
}
it "모든 앱에 app_install/app_remove/app_is_installed 함수가 있다" _test_registry_all_have_installer_functions

# =============================================================================
# Thunderbird — Termux native
# =============================================================================
describe "Thunderbird — Termux native 설치"

_test_thunderbird_install_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_thunderbird
    assert_was_called "termux_pkg_install thunderbird"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install thunderbird 호출" _test_thunderbird_install_calls_termux_pkg

_test_thunderbird_install_creates_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_thunderbird
    assert_file_exists "${PREFIX}/share/applications/thunderbird.desktop"
    assert_file_exists "${HOME}/Desktop/thunderbird.desktop"
    cleanup_sandbox "$sb"
}
it "install → .desktop 파일 생성" _test_thunderbird_install_creates_desktop

_test_thunderbird_remove_calls_pkg_remove() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    # 설치 상태 시뮬레이션
    touch "${PREFIX}/share/applications/thunderbird.desktop"
    touch "${HOME}/Desktop/thunderbird.desktop"
    app_remove_thunderbird
    assert_was_called "termux_pkg_remove thunderbird"
    cleanup_sandbox "$sb"
}
it "remove → termux_pkg_remove thunderbird 호출" _test_thunderbird_remove_calls_pkg_remove

_test_thunderbird_remove_deletes_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    touch "${PREFIX}/share/applications/thunderbird.desktop"
    touch "${HOME}/Desktop/thunderbird.desktop"
    app_remove_thunderbird
    [ ! -e "${PREFIX}/share/applications/thunderbird.desktop" ]
    [ ! -e "${HOME}/Desktop/thunderbird.desktop" ]
    cleanup_sandbox "$sb"
}
it "remove → .desktop 파일 삭제" _test_thunderbird_remove_deletes_desktop

_test_thunderbird_is_installed_false_without_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_is_installed_thunderbird && { echo "[ASSERT] desktop 없는데 설치됨으로 반환" >&2; return 1; }
    cleanup_sandbox "$sb"
}
it "desktop 파일 없으면 is_installed → false" _test_thunderbird_is_installed_false_without_desktop

_test_thunderbird_is_installed_true_with_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    touch "${PREFIX}/share/applications/thunderbird.desktop"
    app_is_installed_thunderbird
    cleanup_sandbox "$sb"
}
it "desktop 파일 있으면 is_installed → true" _test_thunderbird_is_installed_true_with_desktop

# =============================================================================
# VLC — Termux native
# =============================================================================
describe "VLC — Termux native 설치"

_test_vlc_install_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_vlc
    assert_was_called "termux_pkg_install vlc"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install vlc 호출" _test_vlc_install_calls_termux_pkg

_test_vlc_does_not_call_proot() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_vlc
    assert_not_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "install → proot 함수 미호출 (native 전용)" _test_vlc_does_not_call_proot

_test_native_pkg_failure_propagates_without_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    termux_pkg_install() { return 41; }

    if app_install vlc; then
        echo "[ASSERT] pkg 실패가 app_install 성공으로 처리됨" >&2
        cleanup_sandbox "$sb"
        return 1
    fi
    [ ! -e "${PREFIX}/share/applications/vlc.desktop" ]
    cleanup_sandbox "$sb"
}
it "native pkg 실패 → non-zero 반환, .desktop 미생성" _test_native_pkg_failure_propagates_without_desktop

# =============================================================================
# btop — Termux native (root-repo)
# =============================================================================
describe "btop — Termux native 설치 (root-repo)"

_test_btop_enables_root_repo() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_btop 2>/dev/null || true
    assert_was_called "termux_pkg_enable_repo root-repo"
    assert_was_called "termux_pkg_install btop"
    cleanup_sandbox "$sb"
}
it "install → root-repo를 켜고 btop을 깐다" _test_btop_enables_root_repo

_test_btop_install_failure_propagates() {
    local sb rc; sb=$(make_sandbox); _setup "$sb"
    termux_pkg_install() { return 1; }
    rc=0; app_install_btop >/dev/null 2>&1 || rc=$?
    assert_nonzero "$rc" "termux_pkg_install 실패는 app_install_btop 실패로 이어져야 함" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "termux_pkg_install 실패 → app_install_btop non-zero 반환" _test_btop_install_failure_propagates

# =============================================================================
# VS Code — proot 설치
# =============================================================================
describe "VS Code — proot 설치"

_test_vscode_install_adds_external_repo() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_vscode
    assert_was_called "proot_pkg_add_external_repo vscode"
    cleanup_sandbox "$sb"
}
it "install → proot_pkg_add_external_repo 호출 (MS apt repo)" _test_vscode_install_adds_external_repo

_test_vscode_install_calls_proot_pkg_install_code() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_vscode
    assert_was_called "proot_pkg_install code"
    cleanup_sandbox "$sb"
}
it "install → proot_pkg_install code 호출" _test_vscode_install_calls_proot_pkg_install_code

_test_vscode_install_calls_update_first() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_vscode
    assert_was_called "proot_pkg_update"
    cleanup_sandbox "$sb"
}
it "install → proot_pkg_update를 먼저 호출한다" _test_vscode_install_calls_update_first

_test_vscode_remove_calls_proot_pkg_remove_vscode() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_remove_vscode
    assert_was_called "proot_pkg_remove_vscode"
    cleanup_sandbox "$sb"
}
it "remove → proot_pkg_remove_vscode 호출" _test_vscode_remove_calls_proot_pkg_remove_vscode

# =============================================================================
# LibreOffice — proot 설치 (패키지명 추상화)
# =============================================================================
describe "LibreOffice — proot 설치"

_test_libreoffice_install_uses_abstract_pkg_fn() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_libreoffice
    assert_was_called "proot_pkg_install_libreoffice"
    cleanup_sandbox "$sb"
}
it "install → proot_pkg_install_libreoffice 호출 (Ubuntu/Arch 추상화)" _test_libreoffice_install_uses_abstract_pkg_fn

_test_libreoffice_does_not_hardcode_pkg_name() {
    # proot_pkg_remove/install 에 구체적 패키지명(libreoffice, libreoffice-fresh)이 없어야 함
    ! grep -q "proot_pkg_remove libreoffice\|proot_pkg_install libreoffice" \
        "${APP_DIR}/domain/installers/libreoffice.sh" 2>/dev/null
}
it "libreoffice.sh 도메인 — distro별 패키지명 하드코딩 없음" _test_libreoffice_does_not_hardcode_pkg_name

# =============================================================================
# DBeaver — JDK 추상화
# =============================================================================
describe "DBeaver — proot 설치"

_test_dbeaver_install_uses_abstract_jdk() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_dbeaver
    assert_was_called "proot_pkg_install_jdk"
    cleanup_sandbox "$sb"
}
it "install → proot_pkg_install_jdk 호출 (JDK 패키지명 추상화)" _test_dbeaver_install_uses_abstract_jdk

_test_dbeaver_failure_propagates_without_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    proot_exec() { return 23; }

    if app_install dbeaver; then
        echo "[ASSERT] proot_exec 실패가 app_install 성공으로 처리됨" >&2
        cleanup_sandbox "$sb"
        return 1
    fi
    [ ! -e "${PREFIX}/share/applications/dbeaver.desktop" ]
    cleanup_sandbox "$sb"
}
it "다운로드 실패 → non-zero 반환, .desktop 미생성" _test_dbeaver_failure_propagates_without_desktop

# =============================================================================
# Miniforge — 설치 판단 기준 (디렉토리)
# =============================================================================
describe "Miniforge — 설치 상태 판단"

_test_miniforge_not_installed_without_dir() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_is_installed_miniforge && { echo "[ASSERT] miniforge3 디렉토리 없는데 installed" >&2; return 1; }
    cleanup_sandbox "$sb"
}
it "miniforge3 디렉토리 없으면 is_installed → false" _test_miniforge_not_installed_without_dir

_test_miniforge_installed_with_dir() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    mkdir -p "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/${PROOT_USER}/miniforge3"
    app_is_installed_miniforge
    cleanup_sandbox "$sb"
}
it "miniforge3 디렉토리 있으면 is_installed → true" _test_miniforge_installed_with_dir

_test_miniforge_failure_propagates() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    proot_exec() { return 24; }

    if app_install miniforge; then
        echo "[ASSERT] proot_exec 실패가 app_install 성공으로 처리됨" >&2
        cleanup_sandbox "$sb"
        return 1
    fi
    cleanup_sandbox "$sb"
}
it "다운로드 실패 → app_install이 non-zero 반환" _test_miniforge_failure_propagates

# =============================================================================
# SASM — 패키지 설치 추상화
# =============================================================================
describe "SASM — proot 설치"

_test_sasm_uses_abstract_install_fn() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_sasm
    assert_was_called "proot_pkg_install_sasm"
    cleanup_sandbox "$sb"
}
it "install → proot_pkg_install_sasm 호출 (Ubuntu codename/Arch AUR 추상화)" _test_sasm_uses_abstract_install_fn

_test_sasm_does_not_hardcode_mantic() {
    ! grep -q "mantic\|noble\|oracular" \
        "${APP_DIR}/domain/installers/sasm.sh" 2>/dev/null
}
it "sasm.sh 도메인 — Ubuntu codename 하드코딩 없음" _test_sasm_does_not_hardcode_mantic

# =============================================================================
# Wine — proot/native 분기
# =============================================================================
describe "Wine — proot/native 분기 로직"

_test_wine_proot_path_calls_box64() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine
    assert_was_called "proot_pkg_install_box64"
    cleanup_sandbox "$sb"
}
it "proot 있음 → proot_pkg_install_box64 호출" _test_wine_proot_path_calls_box64

_test_wine_proot_path_calls_wine_mesa() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine
    assert_was_called "proot_pkg_install_wine_mesa"
    cleanup_sandbox "$sb"
}
it "proot 있음 → proot_pkg_install_wine_mesa 호출" _test_wine_proot_path_calls_wine_mesa

_test_wine_native_path_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=false
    # _wine_install_native에서 wget이 없으면 실패하지만, 호출 기록은 됨
    app_install_wine 2>/dev/null || true
    assert_was_called "termux_pkg_enable_repo glibc-repo"
    cleanup_sandbox "$sb"
}
it "proot 없음 → termux_pkg_enable_repo glibc-repo 호출 (native 경로, L14)" _test_wine_native_path_calls_termux_pkg

_test_wine_proot_path_does_not_call_termux_glibc() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine
    assert_not_called "termux_pkg_install glibc-repo"
    cleanup_sandbox "$sb"
}
it "proot 있음 → glibc-repo 설치 미호출 (proot 경로)" _test_wine_proot_path_does_not_call_termux_glibc

# =============================================================================
# Wine 백엔드 이중화 (box64 / hangover)
# =============================================================================
describe "Wine 백엔드 — 리졸버"

_test_wine_backend_defaults_to_box64() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    assert_eq "box64" "$(wine_backend)" "백엔드 미설치 시 기본값"
    cleanup_sandbox "$sb"
}
it "설정·설치 모두 없으면 box64" _test_wine_backend_defaults_to_box64

_test_wine_backend_prefers_hangover_when_present() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    : > "${PREFIX}/bin/wine-hangover"; chmod +x "${PREFIX}/bin/wine-hangover"
    assert_eq "hangover" "$(wine_backend)" "hangover 설치 시 우선"
    cleanup_sandbox "$sb"
}
it "설정 없고 hangover만 있으면 hangover" _test_wine_backend_prefers_hangover_when_present

_test_wine_backend_honours_config() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    : > "${PREFIX}/bin/wine-hangover"; chmod +x "${PREFIX}/bin/wine-hangover"
    : > "${PREFIX}/bin/wine-box64";    chmod +x "${PREFIX}/bin/wine-box64"
    wine_backend_set box64
    assert_eq "box64" "$(wine_backend)" "설정 파일이 우선"
    cleanup_sandbox "$sb"
}
it "둘 다 설치 시 설정 파일 값을 따른다" _test_wine_backend_honours_config

_test_wine_backend_ignores_stale_config() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    : > "${PREFIX}/bin/wine-box64"; chmod +x "${PREFIX}/bin/wine-box64"
    wine_backend_set hangover 2>/dev/null || true
    # 설정은 hangover지만 실제로는 없음 → 설치된 box64로 폴백
    assert_eq "box64" "$(wine_backend)" "설정이 가리키는 백엔드가 없으면 폴백"
    cleanup_sandbox "$sb"
}
it "설정이 미설치 백엔드를 가리키면 설치된 쪽으로 폴백" _test_wine_backend_ignores_stale_config

_test_wine_prefix_per_backend() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    assert_eq "${HOME}/.wine" "$(wine_prefix)" "box64 WINEPREFIX"
    : > "${PREFIX}/bin/wine-hangover"; chmod +x "${PREFIX}/bin/wine-hangover"
    assert_eq "${HOME}/.wine-hangover" "$(wine_prefix)" "hangover WINEPREFIX"
    cleanup_sandbox "$sb"
}
it "백엔드마다 WINEPREFIX가 분리된다" _test_wine_prefix_per_backend

_test_wine_backend_set_default_does_not_override() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    wine_backend_set hangover
    wine_backend_set_default box64
    assert_file_contains "$_WINE_BACKEND_CONF" "hangover" "기존 사용자 선택 보존"
    cleanup_sandbox "$sb"
}
it "wine_backend_set_default는 기존 설정을 덮어쓰지 않는다" _test_wine_backend_set_default_does_not_override

_test_wine_backend_available() {
    local sb rc; sb=$(make_sandbox); _setup "$sb"
    rc=0; wine_backend_available || rc=$?
    assert_nonzero "$rc" "미설치 상태" || { cleanup_sandbox "$sb"; return 1; }
    : > "${PREFIX}/bin/wine-box64"; chmod +x "${PREFIX}/bin/wine-box64"
    rc=0; wine_backend_available || rc=$?
    assert_zero "$rc" "box64 설치 상태" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "wine_backend_available은 백엔드 하나라도 있으면 성공" _test_wine_backend_available

describe "Wine 백엔드 — 디스패처 / Hangover"

_test_wine_dispatcher_written() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    wine_wire_frontend
    assert_file_exists "${PREFIX}/bin/wine" "디스패처"
    assert_file_exists "${PREFIX}/bin/wine-backend" "전환 CLI"
    assert_file_contains "${PREFIX}/bin/wine" 'exec "$PREFIX/bin/wine-$_b"' "백엔드로 위임"
    cleanup_sandbox "$sb"
}
it "wine_wire_frontend가 디스패처+CLI를 만든다" _test_wine_dispatcher_written

_test_legacy_wine_wrapper_migrates() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    # 백엔드 분리 이전 설치 재현: $PREFIX/bin/wine 자체가 box64 래퍼
    printf '#!/bin/bash\nexec grun "$HOME/.wine-staging/bin/wine64" "$@"\n' > "${PREFIX}/bin/wine"
    chmod +x "${PREFIX}/bin/wine"

    wine_wire_frontend

    assert_file_exists "${PREFIX}/bin/wine-box64" "레거시 래퍼가 보존된다"
    assert_file_contains "${PREFIX}/bin/wine-box64" "wine-staging" "원본 내용 유지"
    assert_file_contains "${PREFIX}/bin/wine" "termux-xfce-wine-dispatcher" "디스패처로 교체"
    cleanup_sandbox "$sb"
}
it "레거시 \$PREFIX/bin/wine 래퍼는 wine-box64로 이관된다" _test_legacy_wine_wrapper_migrates

_test_foreign_wine_binary_not_migrated() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    # 우리 래퍼가 아닌 wine(wine-staging 문자열 없음)은 wine-box64로 이관하지 않는다.
    # (PATH 상의 wine 자체는 디스패처로 교체된다 — 백엔드 분리 이전과 동일한 동작)
    printf '#!/bin/bash\necho other-wine\n' > "${PREFIX}/bin/wine"
    chmod +x "${PREFIX}/bin/wine"

    wine_wire_frontend

    [ -e "${PREFIX}/bin/wine-box64" ] && {
        echo "[ASSERT] 남의 wine 바이너리를 wine-box64로 옮김" >&2; return 1
    }
    cleanup_sandbox "$sb"
}
it "우리 래퍼가 아닌 wine은 wine-box64로 이관하지 않는다" _test_foreign_wine_binary_not_migrated

_test_wine_box64_installs_to_own_path() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine
    assert_file_exists "${PREFIX}/bin/wine-box64" "box64 래퍼는 전용 경로에"
    assert_file_exists "${PREFIX}/bin/wine" "디스패처도 함께 생성"
    cleanup_sandbox "$sb"
}
it "wine 설치는 wine-box64 + 디스패처를 만든다" _test_wine_box64_installs_to_own_path

_test_hangover_enables_x11_repo() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_hangover 2>/dev/null || true
    assert_was_called "termux_pkg_enable_repo x11-repo"
    assert_was_called "termux_pkg_install hangover"
    cleanup_sandbox "$sb"
}
it "hangover 설치는 x11-repo를 켜고 hangover를 깐다" _test_hangover_enables_x11_repo

_test_hangover_fails_without_upstream_binary() {
    local sb rc; sb=$(make_sandbox); _setup "$sb"
    # mock pkg는 실제로 hangover-wine을 만들지 않는다 → 실패해야 한다
    rc=0; app_install_hangover >/dev/null 2>&1 || rc=$?
    assert_nonzero "$rc" "hangover-wine 없으면 실패해야 함" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "hangover-wine 바이너리가 없으면 non-zero" _test_hangover_fails_without_upstream_binary

_test_hangover_wires_frontend() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    : > "${PREFIX}/bin/hangover-wine"; chmod +x "${PREFIX}/bin/hangover-wine"
    app_install_hangover >/dev/null 2>&1
    assert_file_exists "${PREFIX}/bin/wine-hangover" "hangover 래퍼"
    assert_file_exists "${PREFIX}/bin/wine" "디스패처"
    assert_file_contains "${PREFIX}/bin/wine-hangover" 'exec "$PREFIX/bin/hangover-wine"' "상위 바이너리 호출"
    assert_file_contains "$_WINE_BACKEND_CONF" "hangover" "기본 백엔드 설정"
    cleanup_sandbox "$sb"
}
it "hangover 설치는 래퍼+디스패처를 만들고 기본 백엔드가 된다" _test_hangover_wires_frontend

_test_remove_one_backend_keeps_dispatcher() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    : > "${PREFIX}/bin/hangover-wine"; chmod +x "${PREFIX}/bin/hangover-wine"
    app_install_hangover >/dev/null 2>&1
    MOCK_HAS_PROOT=true
    app_install_wine >/dev/null 2>&1
    app_remove_wine >/dev/null 2>&1
    assert_file_exists "${PREFIX}/bin/wine" "hangover가 남았으므로 디스패처 유지"
    assert_file_contains "$_WINE_BACKEND_CONF" "hangover" "남은 백엔드로 전환"
    cleanup_sandbox "$sb"
}
it "한쪽 백엔드 제거 시 디스패처는 남은 쪽을 가리킨다" _test_remove_one_backend_keeps_dispatcher

_test_remove_last_backend_drops_dispatcher() {
    local sb rc; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine >/dev/null 2>&1
    app_remove_wine >/dev/null 2>&1
    rc=0; [ -e "${PREFIX}/bin/wine" ] || rc=$?
    assert_nonzero "$rc" "마지막 백엔드 제거 시 디스패처도 사라져야 함" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "마지막 백엔드를 지우면 디스패처도 사라진다" _test_remove_last_backend_drops_dispatcher

describe "Wine 앱 — 백엔드 중립 실행"

_test_wine_apps_use_wine_exec_shell() {
    local f rc failed=0
    for f in notepadpp sevenzip sumatrapdf winmerge; do
        command grep -q "wine_exec_shell" "${APP_DIR}/domain/installers/${f}.sh" || {
            echo "[ASSERT] ${f}.sh가 wine_exec_shell을 쓰지 않음" >&2; failed=1
        }
        command grep -q 'HOME/\.wine/drive_c' "${APP_DIR}/domain/installers/${f}.sh" && {
            echo "[ASSERT] ${f}.sh에 \$HOME/.wine/drive_c 하드코딩이 남아 있음" >&2; failed=1
        }
    done
    return $failed
}
it "Wine 앱 4종이 WINEPREFIX를 하드코딩하지 않는다" _test_wine_apps_use_wine_exec_shell

_test_wine_exec_shell_injects_prefix_native() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=false
    local out
    out=$(wine_exec_shell 'printf "%s" "$WINEPREFIX"')
    assert_eq "${HOME}/.wine" "$out" "native 문맥에서 WINEPREFIX 주입"
    cleanup_sandbox "$sb"
}
it "wine_exec_shell이 native 문맥에 WINEPREFIX를 주입한다" _test_wine_exec_shell_injects_prefix_native

_test_wine_exec_shell_uses_proot_for_box64() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    wine_exec_shell 'true'
    assert_was_called "proot_exec_wine"
    cleanup_sandbox "$sb"
}
it "box64+proot에서는 proot_exec_wine을 탄다" _test_wine_exec_shell_uses_proot_for_box64

# H6: Termux native 문맥(하이브리드 앱 4종 + wine.sh _wine_install_native)은 Android에 없는
# 하드코딩 /tmp를 쓰면 안 된다. ${TMPDIR:-/tmp}로 폴백해야 한다.
# wine.sh의 _wine_install_tarball_proot는 proot 컨테이너 내부(실제 리눅스 /tmp 존재)에서
# 실행되므로 범위 밖 — _wine_install_native 함수 본문만 검사한다.
_test_wine_apps_no_bare_tmp() {
    local f failed=0
    for f in notepadpp sumatrapdf winmerge sevenzip; do
        if command grep -nE '(^|[^A-Za-z0-9_}])/tmp/' "${APP_DIR}/domain/installers/${f}.sh"; then
            echo "[ASSERT] ${f}.sh에 bare /tmp/ 가 남아 있음 (위 라인)" >&2
            failed=1
        fi
    done
    local native_body
    native_body=$(sed -n '/^_wine_install_native()/,/^}/p' "${APP_DIR}/domain/installers/wine.sh")
    if echo "$native_body" | command grep -nE '(^|[^A-Za-z0-9_}])/tmp/'; then
        echo "[ASSERT] wine.sh _wine_install_native에 bare /tmp/ 가 남아 있음 (위 라인)" >&2
        failed=1
    fi
    return $failed
}
it "Wine 계열 설치기가 Termux 문맥에서 bare /tmp를 쓰지 않는다" _test_wine_apps_no_bare_tmp

_test_notepadpp_snippet_uses_tmpdir() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    : > "${PREFIX}/bin/wine-hangover"; chmod +x "${PREFIX}/bin/wine-hangover"
    local captured=""
    wine_exec_shell() { captured="$1"; return 0; }
    app_install_notepadpp >/dev/null 2>&1
    assert_output_contains "$captured" '${TMPDIR:-/tmp}/npp.zip' "notepadpp 스니펫이 TMPDIR 폴백을 쓴다"
    cleanup_sandbox "$sb"
}
it "notepadpp 스니펫이 \${TMPDIR:-/tmp}를 주입한다 (hangover 문맥)" _test_notepadpp_snippet_uses_tmpdir

# H7: mesa-zink-glibc는 termux-glibc repo에 존재하지 않는 패키지명
# (오라클: https://packages.termux.dev/apt/termux-glibc/dists/glibc/stable/binary-aarch64/Packages)
_test_wine_native_pkg_list_has_no_mesa_zink() {
    if command grep -q "mesa-zink-glibc" "${APP_DIR}/domain/installers/wine.sh"; then
        echo "[ASSERT] wine.sh에 존재하지 않는 패키지 mesa-zink-glibc가 남아 있음" >&2
        return 1
    fi
    command grep -q "mesa-glibc" "${APP_DIR}/domain/installers/wine.sh" || {
        echo "[ASSERT] wine.sh에 mesa-glibc가 없음" >&2
        return 1
    }
}
it "wine.sh native 패키지 목록에 존재하지 않는 mesa-zink-glibc 대신 mesa-glibc가 있다" \
    _test_wine_native_pkg_list_has_no_mesa_zink

# =============================================================================
# L13 — api_stt.sh --debug 모드가 /tmp를 하드코딩하는 문제
# =============================================================================
describe "STT — --debug 임시파일 경로"

_test_stt_debug_uses_tmpdir_fallback() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_api_stt
    assert_file_contains "${_STT_SCRIPT}" 'TMPDIR:-/tmp}/stt_debug.txt'
    if grep -qE '[^}]/tmp/stt_debug' "${_STT_SCRIPT}"; then
        echo "[ASSERT] 생성된 스크립트에 하드코딩된 /tmp/stt_debug가 남아 있음" >&2
        cleanup_sandbox "$sb"
        return 1
    fi
    cleanup_sandbox "$sb"
}
it "stt-recognize --debug → \${TMPDIR:-/tmp}/stt_debug.txt 사용, 하드코딩 없음" _test_stt_debug_uses_tmpdir_fallback

# =============================================================================
# M8 — 제거 루프가 마지막 && 의 rc를 그대로 흘리는 문제
# =============================================================================
describe "제거 루프 — 마지막 패키지 미설치 시 rc"

_test_gpu_dev_remove_rc0_when_last_missing() {
    local sb rc; sb=$(make_sandbox); _setup "$sb"
    # _PKGS_GPU_DEV 마지막 항목(libpeas)만 미설치로 남긴다
    MOCK_INSTALLED_PKGS="clvk clinfo gtkmm4 libsigc++-3.0 libcairomm-1.16 libglibmm-2.68 libpangomm-2.48 swig"
    rc=0; app_remove_gpu_dev || rc=$?
    assert_zero "$rc" "마지막 패키지(libpeas)가 이미 없어도 rc 0"
    cleanup_sandbox "$sb"
}
it "gpu_dev 제거: 마지막 패키지가 이미 없어도 rc 0" _test_gpu_dev_remove_rc0_when_last_missing

_test_gpu_native_remove_rc0_when_last_missing() {
    local sb rc; sb=$(make_sandbox); _setup "$sb"
    # app_remove_gpu_native 목록 마지막 항목(mesa-demos)만 미설치로 남긴다
    MOCK_INSTALLED_PKGS="mesa-vulkan-icd-freedreno vulkan-loader-generic mesa-vulkan-icd-swrast mesa-dev"
    rc=0; app_remove_gpu_native || rc=$?
    assert_zero "$rc" "마지막 패키지(mesa-demos)가 이미 없어도 rc 0"
    cleanup_sandbox "$sb"
}
it "gpu_native 제거: 마지막 패키지가 이미 없어도 rc 0" _test_gpu_native_remove_rc0_when_last_missing

_test_korean_input_remove_rc0_when_last_missing() {
    local sb rc; sb=$(make_sandbox); _setup "$sb"
    # app_remove_korean_input 목록 마지막 항목(libhangul)만 미설치로 남긴다.
    # libhangul-static은 일부러 뺀다 — grep -qw가 하이픈 경계에서 "libhangul"을
    # "libhangul-static" 안의 단어로도 매치해 버려 last-missing 조건이 깨진다.
    MOCK_INSTALLED_PKGS="fcitx5-configtool fcitx5-hangul fcitx5"
    rc=0; app_remove_korean_input || rc=$?
    assert_zero "$rc" "마지막 패키지(libhangul)가 이미 없어도 rc 0"
    cleanup_sandbox "$sb"
}
it "korean_input 제거: 마지막 패키지가 이미 없어도 rc 0" _test_korean_input_remove_rc0_when_last_missing

# =============================================================================
# M9 — llama-model-get 헬퍼: curl -f 없이 404/403 HTML을 .gguf로 저장하는 문제
# =============================================================================
describe "llama.cpp — 모델 다운로드 헬퍼"

_test_llama_model_get_uses_curl_f_and_cleans_up() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_llama_cpp >/dev/null 2>&1
    assert_file_contains "$_LLAMA_MODEL_GET_BIN" "curl -fL -C -" "curl -f로 HTTP 오류를 감지해야 함"
    assert_file_contains "$_LLAMA_MODEL_GET_BIN" 'rm -f "$OUT"' "실패 시 손상된 부분 파일을 지워야 함"
    cleanup_sandbox "$sb"
}
it "llama-model-get 헬퍼가 curl -f로 실패를 감지하고 부분 파일을 지운다" _test_llama_model_get_uses_curl_f_and_cleans_up

# =============================================================================
# Claude Code — 업그레이드 지원
# =============================================================================
describe "Claude Code — 설치/업그레이드"

# 설치된 상태 시뮬레이션 (wrapper + native binary + VERSION 파일)
_claude_fake_install() {
    local ver="$1"
    mkdir -p "${CLAUDE_CODE_PREFIX}"
    printf '#!/bin/sh\n' > "${CLAUDE_CODE_BIN_PATH}"; chmod +x "${CLAUDE_CODE_BIN_PATH}"
    printf 'binary\n'    > "${CLAUDE_CODE_PREFIX}/claude"; chmod +x "${CLAUDE_CODE_PREFIX}/claude"
    printf '%s\n' "$ver" > "${CLAUDE_CODE_VERSION_FILE}"
}

# L14: glibc-repo는 termux_pkg_install이 아니라 termux_pkg_enable_repo로 활성화해야
# 한다 (termux_pkg_enable_repo가 is_installed 단락 처리를 소유).
_test_claude_glibc_repo_uses_enable_repo_not_install() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_INSTALLED_PKGS="glibc-repo"
    _claude_code_remove_npm_wrapper() { :; }
    _claude_code_download_native()    { :; }
    _claude_code_install_wrapper()    { :; }
    _claude_code_configure_settings() { :; }
    app_install_claude_code
    assert_not_called "termux_pkg_install glibc-repo"
    assert_was_called "termux_pkg_install glibc-runner"
    cleanup_sandbox "$sb"
}
it "glibc-repo 이미 설치 → app_install_claude_code가 termux_pkg_install glibc-repo를 호출하지 않는다 (L14)" \
    _test_claude_glibc_repo_uses_enable_repo_not_install

_test_glibc_repo_idiom_used_in_wine_and_claude() {
    grep -q "termux_pkg_enable_repo glibc-repo" "${APP_DIR}/domain/installers/wine.sh" || {
        echo "[ASSERT] wine.sh에 termux_pkg_enable_repo glibc-repo 없음" >&2
        return 1
    }
    grep -q "termux_pkg_enable_repo glibc-repo" "${APP_DIR}/domain/installers/claude_code.sh" || {
        echo "[ASSERT] claude_code.sh에 termux_pkg_enable_repo glibc-repo 없음" >&2
        return 1
    }
}
it "wine.sh/claude_code.sh 모두 glibc-repo에 termux_pkg_enable_repo 사용 (L14)" \
    _test_glibc_repo_idiom_used_in_wine_and_claude

_test_claude_supports_upgrade() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_can_upgrade claude_code
    cleanup_sandbox "$sb"
}
it "claude_code는 업그레이드를 지원한다 (app_can_upgrade)" _test_claude_supports_upgrade

_test_thunderbird_no_upgrade() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_can_upgrade thunderbird && { echo "[ASSERT] thunderbird에 업그레이드 함수가 있으면 안 됨" >&2; return 1; }
    cleanup_sandbox "$sb"
}
it "thunderbird는 업그레이드를 지원하지 않는다" _test_thunderbird_no_upgrade

_test_claude_download_writes_version() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    # fetch_verified는 빈 파일을 실패로 보므로(무결성 계약) 실제로 내용을 만드는 stub을 쓴다
    fetch_verified() { printf 'tgz\n' > "$2"; }
    tar()  { :; }   # 압축해제 성공 흉내
    mkdir -p "${CLAUDE_CODE_PREFIX}"; : > "${CLAUDE_CODE_PREFIX}/claude"
    _claude_code_download_native "9.9.9"
    assert_eq "9.9.9" "$(cat "${CLAUDE_CODE_VERSION_FILE}")" "VERSION 파일 내용"
    cleanup_sandbox "$sb"
}
it "download → VERSION 파일에 버전 기록" _test_claude_download_writes_version

_test_claude_download_tar_failure_propagates() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    fetch_verified() { printf 'tgz\n' > "$2"; }  # 다운로드(성공+검증통과) 흉내
    tar()  { return 1; } # 압축해제 실패 흉내
    local rc=0
    _claude_code_download_native "9.9.9" >/dev/null 2>&1 || rc=$?
    assert_nonzero "$rc" "tar 실패 시 _claude_code_download_native가 실패해야 함" || { cleanup_sandbox "$sb"; return 1; }
    [ ! -f "${CLAUDE_CODE_VERSION_FILE}" ] || { echo "[ASSERT] tar 실패인데 VERSION 파일이 기록됨" >&2; cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "다운로드 성공 + tar 실패 → download가 실패를 전파한다 (VERSION 미기록)" _test_claude_download_tar_failure_propagates

_test_claude_installed_version_empty_when_absent() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    assert_eq "" "$(_claude_code_installed_version)" "미설치 시 빈 문자열"
    cleanup_sandbox "$sb"
}
it "VERSION 파일 없으면 installed_version → 빈 문자열" _test_claude_installed_version_empty_when_absent

_test_claude_upgrade_when_outdated() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_fake_install "1.0.0"
    _claude_code_fetch_latest_version() { echo "2.0.0"; }
    _claude_code_download_native() { _record_call "download $1"; printf '%s\n' "$1" > "${CLAUDE_CODE_VERSION_FILE}"; }
    _claude_code_install_wrapper()  { _record_call "install_wrapper"; }
    _claude_code_smoke_check()      { return 0; }
    app_upgrade_claude_code
    assert_was_called "download 2.0.0"
    assert_was_called "install_wrapper"
    cleanup_sandbox "$sb"
}
it "구버전 설치됨 → 최신 버전 다운로드 (업그레이드)" _test_claude_upgrade_when_outdated

_test_claude_upgrade_when_latest() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_fake_install "2.0.0"
    _claude_code_fetch_latest_version() { echo "2.0.0"; }
    _claude_code_download_native() { _record_call "download $1"; }
    local rc; app_upgrade_claude_code && rc=0 || rc=$?
    assert_eq "2" "$rc" "이미 최신이면 return 2"
    assert_not_called "download"
    cleanup_sandbox "$sb"
}
it "이미 최신 → 다운로드 없이 return 2" _test_claude_upgrade_when_latest

_test_claude_upgrade_not_installed() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local rc; app_upgrade_claude_code 2>/dev/null && rc=0 || rc=$?
    assert_eq "1" "$rc" "미설치 업그레이드 시 return 1"
    cleanup_sandbox "$sb"
}
it "미설치 상태 업그레이드 → return 1" _test_claude_upgrade_not_installed

_test_claude_remove_uninstalls_npm() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_fake_install "1.0.0"
    # npm 패키지가 남아 있는 상황을 흉내 — 제거 함수가 이걸 호출하는지만 검증
    _claude_code_remove_npm_wrapper() { _record_call "remove_npm_wrapper"; }
    app_remove_claude_code
    assert_was_called "remove_npm_wrapper"
    cleanup_sandbox "$sb"
}
it "remove → npm 글로벌 패키지도 제거 시도" _test_claude_remove_uninstalls_npm

_test_claude_upgrade_backs_up_current() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_fake_install "1.0.0"
    _claude_code_fetch_latest_version() { echo "2.0.0"; }
    _claude_code_download_native() { printf '%s\n' "$1" > "${CLAUDE_CODE_VERSION_FILE}"; printf 'new\n' > "${CLAUDE_CODE_PREFIX}/claude"; }
    _claude_code_install_wrapper()  { :; }
    _claude_code_smoke_check()      { return 0; }
    app_upgrade_claude_code
    assert_file_exists "${CLAUDE_CODE_PREFIX}/claude.bak.v1.0.0" "이전 버전 백업이 생성됨"
    cleanup_sandbox "$sb"
}
it "업그레이드 → 이전 버전 백업 생성" _test_claude_upgrade_backs_up_current

_test_claude_upgrade_smoke_fail_rollbacks() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_fake_install "1.0.0"
    _claude_code_fetch_latest_version() { echo "2.0.0"; }
    _claude_code_download_native() { printf '%s\n' "$1" > "${CLAUDE_CODE_VERSION_FILE}"; printf 'broken\n' > "${CLAUDE_CODE_PREFIX}/claude"; }
    _claude_code_install_wrapper()  { _record_call "install_wrapper"; }
    _claude_code_smoke_check()      { return 1; }
    local rc; app_upgrade_claude_code 2>/dev/null && rc=0 || rc=$?
    assert_eq "1" "$rc" "스모크 실패 시 return 1"
    assert_eq "1.0.0" "$(cat "${CLAUDE_CODE_VERSION_FILE}")" "VERSION이 1.0.0으로 롤백됨"
    cleanup_sandbox "$sb"
}
it "스모크 실패 → 이전 버전으로 자동 롤백" _test_claude_upgrade_smoke_fail_rollbacks

_test_claude_manual_rollback() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_fake_install "3.0.0"
    # 사전에 이전 버전 백업이 있다고 가정
    printf 'old\n' > "${CLAUDE_CODE_PREFIX}/claude.bak.v1.0.0"
    _claude_code_install_wrapper() { :; }
    app_rollback_claude_code "1.0.0"
    assert_eq "1.0.0" "$(cat "${CLAUDE_CODE_VERSION_FILE}")" "VERSION이 1.0.0으로 변경됨"
    cleanup_sandbox "$sb"
}
it "수동 롤백 → 지정 버전으로 복원" _test_claude_manual_rollback

_test_claude_rollback_no_backup() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_fake_install "1.0.0"
    local rc; app_rollback_claude_code 2>/dev/null && rc=0 || rc=$?
    assert_eq "1" "$rc" "백업 없으면 return 1"
    cleanup_sandbox "$sb"
}
it "백업 없이 롤백 → return 1" _test_claude_rollback_no_backup

# =============================================================================
# has_proot_distro — 유틸 함수
# =============================================================================
describe "has_proot_distro — proot 설치 감지"

_test_has_proot_true_when_rootfs_exists() {
    local sb; sb=$(make_sandbox)
    _setup "$sb"
    # setup_fs_sandbox에서 rootfs 디렉토리를 생성함
    # mock에서 has_proot_distro를 override했으므로 MOCK_HAS_PROOT로 제어
    MOCK_HAS_PROOT=true
    has_proot_distro
    cleanup_sandbox "$sb"
}
it "MOCK_HAS_PROOT=true → has_proot_distro 성공" _test_has_proot_true_when_rootfs_exists

_test_has_proot_false_when_no_rootfs() {
    local sb; sb=$(make_sandbox)
    _setup "$sb"
    MOCK_HAS_PROOT=false
    has_proot_distro && { echo "[ASSERT] proot 없는데 true 반환" >&2; return 1; }
    cleanup_sandbox "$sb"
}
it "MOCK_HAS_PROOT=false → has_proot_distro 실패" _test_has_proot_false_when_no_rootfs

# =============================================================================
# desktop.sh — .desktop 파일 관리
# =============================================================================
describe "domain/desktop.sh — .desktop 파일 관리"

_test_desktop_register_creates_files() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    desktop_register "testapp" "Test App" "testapp --run" "testapp" "Utility;"
    assert_file_exists "${PREFIX}/share/applications/testapp.desktop"
    assert_file_exists "${HOME}/Desktop/testapp.desktop"
    cleanup_sandbox "$sb"
}
it "desktop_register → share/applications + Desktop 양쪽에 파일 생성" _test_desktop_register_creates_files

_test_desktop_register_content() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    desktop_register "myapp" "My Application" "myapp --flag" "myapp-icon" "Development;"
    assert_file_contains "${PREFIX}/share/applications/myapp.desktop" "Name=My Application"
    assert_file_contains "${PREFIX}/share/applications/myapp.desktop" "Exec=myapp --flag"
    assert_file_contains "${PREFIX}/share/applications/myapp.desktop" "Icon=myapp-icon"
    cleanup_sandbox "$sb"
}
it "desktop_register → 올바른 내용으로 .desktop 파일 작성" _test_desktop_register_content

_test_desktop_register_with_extra_field() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    desktop_register "mailapp" "Mail" "mail" "mail" "Network;" "MimeType=x-scheme-handler/mailto;"
    assert_file_contains "${PREFIX}/share/applications/mailapp.desktop" "MimeType=x-scheme-handler/mailto;"
    cleanup_sandbox "$sb"
}
it "desktop_register → extra 필드가 .desktop에 포함됨" _test_desktop_register_with_extra_field

_test_desktop_remove_deletes_both_files() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    touch "${PREFIX}/share/applications/myapp.desktop"
    touch "${HOME}/Desktop/myapp.desktop"
    desktop_remove "myapp"
    [ ! -e "${PREFIX}/share/applications/myapp.desktop" ]
    [ ! -e "${HOME}/Desktop/myapp.desktop" ]
    cleanup_sandbox "$sb"
}
it "desktop_remove → share/applications + Desktop 파일 모두 삭제" _test_desktop_remove_deletes_both_files

_test_desktop_is_registered_true() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    touch "${PREFIX}/share/applications/myapp.desktop"
    desktop_is_registered "myapp"
    cleanup_sandbox "$sb"
}
it "desktop_is_registered → 파일 있으면 true" _test_desktop_is_registered_true

_test_desktop_is_registered_false() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    desktop_is_registered "nonexistent" && { echo "[ASSERT] 없는 파일을 registered로 반환" >&2; return 1; }
    cleanup_sandbox "$sb"
}
it "desktop_is_registered → 파일 없으면 false" _test_desktop_is_registered_false

# =============================================================================
# install.sh — DI 로드 검증
# =============================================================================
describe "install.sh — 설정 로드 + DI"

_load_install_partial() {
    local sb="$1"
    setup_fs_sandbox "$sb"
    cat > "${HOME}/.config/termux-xfce/config" << 'EOF'
PROOT_DISTRO="ubuntu"
PROOT_USER="testuser"
EOF
    # zenity + proot-distro mock
    zenity()       { echo "ZENITY: $*"; }
    proot-distro() { echo "PROOT: $*"; }
    # SCRIPT_DIR를 APP_DIR로 고정 후 메인 루프(while true) 전까지만 source
    local tmp
    tmp=$(mktemp)
    echo "SCRIPT_DIR='${APP_DIR}'" > "$tmp"
    awk '/^while true/{ exit } /^SCRIPT_DIR=/ { next } { print }' "${APP_DIR}/install.sh" >> "$tmp"
    source "$tmp"
    rm -f "$tmp"
}

_test_install_loads_config() {
    local sb; sb=$(make_sandbox)
    _load_install_partial "$sb"
    assert_eq "ubuntu"   "${PROOT_DISTRO:-}" "PROOT_DISTRO"
    assert_eq "testuser" "${PROOT_USER:-}"   "PROOT_USER"
    cleanup_sandbox "$sb"
}
it "install.sh → config에서 PROOT_DISTRO/PROOT_USER 로드" _test_install_loads_config

_test_install_loads_app_registry() {
    local sb; sb=$(make_sandbox)
    _load_install_partial "$sb"
    assert_nonzero "${#APP_REGISTRY[@]}" "APP_REGISTRY가 비어 있음"
    cleanup_sandbox "$sb"
}
it "install.sh → APP_REGISTRY 로드 완료" _test_install_loads_app_registry

_test_install_fallback_proot_distro() {
    local sb; sb=$(make_sandbox)
    export HOME="${sb}/home"
    export PREFIX="${sb}/usr"
    mkdir -p "${HOME}/.config/termux-xfce" \
             "${PREFIX}/share/applications" \
             "${PREFIX}/var/lib/proot-distro/installed-rootfs/ubuntu/home"
    zenity()       { echo "ZENITY: $*"; }
    proot-distro() { echo "PROOT: $*"; }
    local tmp; tmp=$(mktemp)
    echo "SCRIPT_DIR='${APP_DIR}'" > "$tmp"
    awk '/^while true/{ exit } /^SCRIPT_DIR=/ { next } { print }' "${APP_DIR}/install.sh" >> "$tmp"
    source "$tmp"
    rm -f "$tmp"
    assert_eq "ubuntu" "${PROOT_DISTRO:-}" "config 없을 때 ubuntu 기본값"
    cleanup_sandbox "$sb"
}
it "config 없을 때 PROOT_DISTRO=ubuntu 기본값" _test_install_fallback_proot_distro

# =============================================================================
# 문법 검사 — 모든 도메인 파일
# =============================================================================
describe "도메인 파일 — bash 문법 검사"

for _f in "${APP_DIR}/domain/installers/"*.sh \
          "${APP_DIR}/domain/desktop.sh" \
          "${APP_DIR}/domain/apps.sh"; do
    _name=$(basename "$_f")
    _test_syntax() { bash -n "${APP_DIR}/domain/${_name}" 2>/dev/null || bash -n "$_f" 2>/dev/null; }
    it "${_name} — 문법 오류 없음" _test_syntax
done

describe "어댑터 파일 — bash 문법 검사"

for _f in "${APP_DIR}/adapters/output/"*.sh; do
    _name=$(basename "$_f")
    _test_adapter_syntax() { bash -n "$_f" 2>/dev/null; }
    it "${_name} — 문법 오류 없음" _test_adapter_syntax
done

# =============================================================================
# TAB_GROUPS — 탭 소속 불변식 (install.sh _category_in_tab 로직 복제)
# =============================================================================
describe "TAB_GROUPS — 탭 소속 불변식"

# install.sh의 _category_in_tab과 동일한 매칭 로직
_category_in_tab() {
    local category="$1" tab_categories="$2"
    IFS=',' read -ra _cats <<< "$tab_categories"
    for _c in "${_cats[@]}"; do
        [ "$_c" = "$category" ] && return 0
    done
    return 1
}

_test_registry_categories_map_to_exactly_one_tab() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local failed=0
    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r id _ category _ <<< "$entry"
        local match_count=0 tab_label
        for group in "${TAB_GROUPS[@]}"; do
            IFS='|' read -r tab_label tab_cats <<< "$group"
            _category_in_tab "$category" "$tab_cats" && (( match_count++ )) || true
        done
        if [ "$match_count" -ne 1 ]; then
            echo "[ASSERT] id=${id} category=${category} 가 탭 ${match_count}개에 매칭됨 (기대: 1)" >&2
            failed=1
        fi
    done
    cleanup_sandbox "$sb"
    return "$failed"
}
it "모든 APP_REGISTRY 항목의 카테고리는 정확히 하나의 탭에만 속한다" _test_registry_categories_map_to_exactly_one_tab

_test_wine_ids_resolve_to_wine_tab() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local failed=0
    local wine_ids=(wine hangover notepadpp winmerge sevenzip sumatrapdf)
    local id
    for id in "${wine_ids[@]}"; do
        local found=0
        for entry in "${APP_REGISTRY[@]}"; do
            IFS='|' read -r _id _name _category _desc <<< "$entry"
            [ "$_id" = "$id" ] || continue
            found=1
            _category_in_tab "$_category" "Wine" || {
                echo "[ASSERT] id=${id} category=${_category} 가 Wine 탭에 속하지 않음" >&2
                failed=1
            }
        done
        if [ "$found" -eq 0 ]; then
            echo "[ASSERT] id=${id} 가 APP_REGISTRY에 없음" >&2
            failed=1
        fi
    done
    cleanup_sandbox "$sb"
    return "$failed"
}
it "wine/hangover/notepadpp/winmerge/sevenzip/sumatrapdf — Wine 탭에 소속" _test_wine_ids_resolve_to_wine_tab

# =============================================================================
# korean_proot — proot 한글 IME (M1: 부모 repo domain/proot_env.sh에서 이관)
# =============================================================================
describe "korean_proot — proot 한글 IME"

# "nimf 미설치" 상황: 표준 mock의 proot_exec는 항상 rc 0이라 command -v nimf가
# 성공으로 보인다 → bash -c 호출만 실패시켜 .deb 경로로 진입시킨다.
_korean_proot_mock_nimf_missing() {
    proot_exec() {
        _record_call "proot_exec $*"
        [ "${1:-}" = "bash" ] && return 1
        return 0
    }
}

_test_korean_proot_requires_proot() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=false
    local rc=0
    app_install_korean_proot >/dev/null 2>&1 || rc=$?
    cleanup_sandbox "$sb"
    assert_nonzero "$rc" "proot 없음인데 rc 0"
}
it "proot 없음 → rc!=0" _test_korean_proot_requires_proot

_test_korean_proot_unsupported_distro() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    PROOT_DISTRO="debian"
    local rc=0
    app_install_korean_proot >/dev/null 2>&1 || rc=$?
    cleanup_sandbox "$sb"
    assert_nonzero "$rc" "미지원 distro인데 rc 0"
}
it "지원하지 않는 PROOT_DISTRO → rc!=0" _test_korean_proot_unsupported_distro

_test_korean_proot_ubuntu_installs_pkgs_and_deb() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _korean_proot_mock_nimf_missing
    app_install_korean_proot >/dev/null
    assert_was_called "proot_pkg_install language-pack-ko" || { cleanup_sandbox "$sb"; return 1; }
    assert_was_called "proot_pkg_install im-config" || { cleanup_sandbox "$sb"; return 1; }
    # url|sha 형식 인자 2개 (nimf + nimf-i18n)
    assert_was_called "proot_pkg_install_deb_url https://github.com/hamonikr/nimf/releases/download/v1.4.17/nimf_1.4.17_arm64-ubuntu.2404.arm64.deb|0530909cf696828bdcd54c122ad465af8bbdf83b1e7eb2fe7a6d6da388334c58 https://github.com/hamonikr/nimf/releases/download/v1.4.17/nimf-i18n_1.4.17_arm64-ubuntu.2404.arm64.deb|7a1f9c3b3893439fa14a4d369e6eac722f40128a595bd98e032e14857e0201b4" \
        || { cleanup_sandbox "$sb"; return 1; }
    assert_file_contains "$(_korean_proot_profile)" "GTK_IM_MODULE=nimf" || { cleanup_sandbox "$sb"; return 1; }
    assert_file_exists "$(_proot_rootfs)/etc/default/locale" || { cleanup_sandbox "$sb"; return 1; }
    assert_file_contains "$(_proot_rootfs)/etc/default/locale" "LANG=ko_KR.UTF-8" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "ubuntu → 로케일 패키지 + nimf .deb(url|sha) 설치 + profile/기본 locale 작성" \
    _test_korean_proot_ubuntu_installs_pkgs_and_deb

_test_korean_proot_ubuntu_deb_failure_propagates() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _korean_proot_mock_nimf_missing
    proot_pkg_install_deb_url() { _record_call "proot_pkg_install_deb_url $*"; return 1; }
    local rc=0
    app_install_korean_proot >/dev/null 2>&1 || rc=$?
    cleanup_sandbox "$sb"
    assert_nonzero "$rc" ".deb 설치 실패인데 rc 0"
}
it "ubuntu → proot_pkg_install_deb_url 실패 시 rc!=0 전파" _test_korean_proot_ubuntu_deb_failure_propagates

_test_korean_proot_arch_nimf_success() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    PROOT_DISTRO="archlinux"
    setup_fs_sandbox "$sb"
    app_install_korean_proot >/dev/null
    assert_was_called "proot_pkg_install noto-fonts-cjk" || { cleanup_sandbox "$sb"; return 1; }
    assert_was_called "proot_pkg_install_aur nimf" || { cleanup_sandbox "$sb"; return 1; }
    assert_file_contains "$(_korean_proot_profile)" "GTK_IM_MODULE=nimf" || { cleanup_sandbox "$sb"; return 1; }
    assert_not_called "proot_pkg_install fcitx5-hangul" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "archlinux → AUR nimf 성공 시 nimf profile, fcitx5 미설치" _test_korean_proot_arch_nimf_success

_test_korean_proot_arch_fcitx5_fallback() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    PROOT_DISTRO="archlinux"
    setup_fs_sandbox "$sb"
    proot_pkg_install_aur() { _record_call "proot_pkg_install_aur $*"; return 1; }
    app_install_korean_proot >/dev/null 2>&1
    assert_was_called "proot_pkg_install fcitx5-hangul" || { cleanup_sandbox "$sb"; return 1; }
    assert_was_called "proot_pkg_install fcitx5-configtool" || { cleanup_sandbox "$sb"; return 1; }
    assert_file_contains "$(_korean_proot_profile)" "@im=fcitx5" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "archlinux → AUR nimf 실패 시 fcitx5 폴백" _test_korean_proot_arch_fcitx5_fallback

_test_korean_proot_arch_locale_gen() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    PROOT_DISTRO="archlinux"
    setup_fs_sandbox "$sb"
    app_install_korean_proot >/dev/null
    app_install_korean_proot >/dev/null   # 2회 실행해도 locale.gen 중복 없음
    local lg; lg="$(_proot_rootfs)/etc/locale.gen"
    assert_file_contains "$lg" "ko_KR.UTF-8 UTF-8" || { cleanup_sandbox "$sb"; return 1; }
    local n; n=$(grep -c '^ko_KR.UTF-8 UTF-8$' "$lg")
    assert_eq "1" "$n" "locale.gen 항목 중복" || { cleanup_sandbox "$sb"; return 1; }
    assert_was_called "proot_exec sudo locale-gen" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "archlinux → locale.gen에 ko_KR.UTF-8 추가 (중복 없음) + locale-gen 실행" _test_korean_proot_arch_locale_gen

_test_korean_proot_idempotent_profile() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_korean_proot >/dev/null
    app_install_korean_proot >/dev/null
    local n; n=$(grep -c '^# termux-xfce-korean$' "$(_korean_proot_profile)")
    cleanup_sandbox "$sb"
    assert_eq "1" "$n" "두 번 설치했는데 마커가 중복됨"
}
it "멱등 — 두 번 설치해도 profile 마커는 1개" _test_korean_proot_idempotent_profile

_test_korean_proot_profile_nimf_autostart() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_korean_proot >/dev/null
    local profile; profile="$(_korean_proot_profile)"
    assert_file_contains "$profile" "command -v nimf" || { cleanup_sandbox "$sb"; return 1; }
    assert_file_contains "$profile" "pgrep -x nimf" || { cleanup_sandbox "$sb"; return 1; }
    assert_file_contains "$profile" "disown" || { cleanup_sandbox "$sb"; return 1; }
    assert_file_contains "$profile" "export LANG=ko_KR.UTF-8" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "profile nimf 기동 — command -v / pgrep -x / disown 가드 포함" _test_korean_proot_profile_nimf_autostart

_test_korean_proot_remove_strips_block() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local profile; profile="$(_korean_proot_profile)"
    mkdir -p "$(dirname "$profile")"
    printf 'BEFORE_LINE\n' > "$profile"
    app_install_korean_proot >/dev/null
    app_is_installed_korean_proot || { echo "[ASSERT] 설치 후 is_installed false" >&2; cleanup_sandbox "$sb"; return 1; }

    local rc=0
    app_remove_korean_proot >/dev/null || rc=$?
    assert_zero "$rc" "remove가 rc!=0" || { cleanup_sandbox "$sb"; return 1; }
    assert_was_called "proot_pkg_remove nimf nimf-i18n" || { cleanup_sandbox "$sb"; return 1; }
    if grep -q 'termux-xfce-korean' "$profile"; then
        echo "[ASSERT] remove 후에도 마커 블록이 남아 있음" >&2
        cleanup_sandbox "$sb"; return 1
    fi
    assert_file_contains "$profile" "BEFORE_LINE" || { cleanup_sandbox "$sb"; return 1; }
    if app_is_installed_korean_proot; then
        echo "[ASSERT] remove 후에도 is_installed true" >&2
        cleanup_sandbox "$sb"; return 1
    fi
    cleanup_sandbox "$sb"
}
it "remove → profile 블록 제거 + rc 0 + is_installed false" _test_korean_proot_remove_strips_block

# =============================================================================
# 설치기 계약 — 전체 APP_REGISTRY 파라메트릭 테스트
# domain/apps.sh app_install() 위의 계약 주석 참조:
#   app_install_<id>는 critical 명령(pkg install/curl/proot_exec 등) 실패 시
#   반드시 non-zero를 반환해야 하며, 실패 시 .desktop 런처를 만들지 말 것.
# =============================================================================
describe "설치기 계약 — 전체 APP_REGISTRY (파라메트릭)"

# (a) 모든 id가 app_install_*/app_remove_*/app_is_installed_* 를 정의하는가
_test_contract_functions_defined_for_all_ids() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local failed=0 entry id
    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r id _ _ _ <<< "$entry"
        local fn
        for fn in app_install app_remove app_is_installed; do
            declare -F "${fn}_${id}" >/dev/null 2>&1 || {
                echo "[ASSERT] id=${id} — ${fn}_${id} 미정의" >&2
                failed=1
            }
        done
    done
    cleanup_sandbox "$sb"
    return "$failed"
}
it "APP_REGISTRY 전체 — app_install_*/app_remove_*/app_is_installed_* 정의됨" _test_contract_functions_defined_for_all_ids

# (b) 모든 critical primitive가 실패하면 app_install_<id>는 반드시 non-zero를 반환하고
#     .desktop을 생성하지 않아야 한다. has_proot_distro는 true로 고정해
#     proot 설치기가 "proot 없음" 조기 에러가 아니라 실제 critical 명령까지 도달하게 한다.
_test_contract_install_failure_propagates_for_all_ids() {
    local sb; sb=$(make_sandbox)
    _setup "$sb"
    MOCK_HAS_PROOT=true
    mock_all_install_primitives_fail
    local failed=0 entry id
    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r id _ _ _ <<< "$entry"

        # 외부 critical 명령이 전혀 없는(순수 로컬 파일 생성) 설치기 — 실패시킬 primitive가
        # 없으므로 이 mock 하에서도 정상적으로 0을 반환/desktop 등록함. (a) 함수 정의 여부는
        # 위 테스트에서 이미 검증됨 — 여기서는 (b) 실패 전파 단정만 건너뛴다.
        case "$id" in
            api_brightness|api_volume|api_notification|api_tts|api_stt|api_wallpaper)
                continue ;;
        esac

        rm -rf "${HOME:?}" "${PREFIX:?}"
        setup_fs_sandbox "$sb"
        reset_mock_calls

        local rc=0
        app_install "$id" >/dev/null 2>&1 || rc=$?
        if [ "$rc" -eq 0 ]; then
            echo "[ASSERT] id=${id} — 모든 critical primitive가 실패했는데 app_install_${id}가 0을 반환함 (계약 위반)" >&2
            failed=1
        fi
        if [ -n "$(ls -A "${PREFIX}/share/applications" 2>/dev/null)" ]; then
            echo "[ASSERT] id=${id} — 실패했는데 .desktop이 생성됨: $(ls "${PREFIX}/share/applications")" >&2
            failed=1
        fi
    done
    cleanup_sandbox "$sb"
    return "$failed"
}
it "APP_REGISTRY 전체 — critical primitive 전부 실패 시 app_install이 실패를 전파하고 .desktop을 만들지 않는다" \
    _test_contract_install_failure_propagates_for_all_ids

# wine은 proot/native 양쪽으로 분기하는 유일한 설치기 — native 분기도 별도 확인
_test_contract_wine_native_failure_propagates() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    mock_all_install_primitives_fail
    MOCK_HAS_PROOT=false
    local rc=0
    app_install_wine >/dev/null 2>&1 || rc=$?
    assert_nonzero "$rc" "wine native 분기 — critical primitive 실패 시 실패해야 함" || { cleanup_sandbox "$sb"; return 1; }
    if [ -e "${PREFIX}/share/applications/wine.desktop" ]; then
        echo "[ASSERT] wine native 분기 — 실패했는데 .desktop이 생성됨" >&2
        cleanup_sandbox "$sb"; return 1
    fi
    cleanup_sandbox "$sb"
}
it "wine — native 분기도 critical primitive 실패 시 실패를 전파한다" _test_contract_wine_native_failure_propagates

# (c) 정상(성공) mock에서는 app_install_<id>가 0을 반환해야 한다 (Task2 수정이 성공 경로를
#     깨지 않았는지 확인). 순수 로컬 파일 생성만 하는 api_* 류도 포함해 전부 검증한다.
#     gpu_proot/korean_locale은 app-installer 밖 의존성(실기기 sysfs / 상위 프로젝트 파일)
#     때문에 유닛 테스트로 재현 불가 — skip.
_test_contract_install_success_for_all_ids() {
    local sb; sb=$(make_sandbox)
    _setup "$sb"
    local failed=0 entry id

    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r id _ _ _ <<< "$entry"

        case "$id" in
            gpu_proot)
                skip "app_install_gpu_proot — 실기기 /sys/class/kgsl/kgsl-3d0/gpu_model 필요, 유닛 테스트로 재현 불가"
                continue ;;
            korean_locale)
                skip "app_install_korean_locale — 메인 프로젝트(Termux_XFCE) domain/locale_ko.sh + ports/ui.sh(ui_warn 등) 의존, app-installer 단독 테스트 불가"
                continue ;;
        esac

        rm -rf "${HOME:?}" "${PREFIX:?}"
        setup_fs_sandbox "$sb"
        MOCK_INSTALLED_PKGS=""
        MOCK_PROOT_INSTALLED_PKGS=""
        MOCK_HAS_PROOT=true
        reset_mock_calls
        unset -f curl wget tar dpkg npm fetch_verified 2>/dev/null || true
        source "${APP_DIR}/lib/fetch.sh"

        # mock만으로는 만들 수 없는 "실제 업스트림 산출물"이 필요한 소수의 설치기만
        # 최소한으로 보강한다 (다운로드 파이프라인 자체를 검증하는 게 아니라, 그 이후의
        # 계약 로직 — 실패 전파/= desktop 등록 — 이 성공 경로에서 깨지지 않았는지만 본다).
        case "$id" in
            hangover)
                : > "${PREFIX}/bin/hangover-wine"; chmod +x "${PREFIX}/bin/hangover-wine"
                ;;
            claude_code)
                # 실다운로드 회피 — fetch_verified는 빈 파일을 무결성 실패로 보므로 내용을 만든다
                fetch_verified() { printf 'tgz\n' > "$2"; }
                tar()  { :; }
                npm()  { return 1; }
                mkdir -p "${CLAUDE_CODE_PREFIX}"
                : > "${CLAUDE_CODE_PREFIX}/claude"
                ;;
            nimf)
                fetch_verified() { printf 'deb\n' > "$2"; }
                dpkg() { return 0; }
                ;;
        esac

        local rc=0
        app_install "$id" >/dev/null 2>&1 || rc=$?
        if [ "$rc" -ne 0 ]; then
            echo "[ASSERT] id=${id} — 정상(성공) mock에서도 app_install_${id}가 실패함 (rc=${rc})" >&2
            failed=1
        fi
    done

    cleanup_sandbox "$sb"
    return "$failed"
}
it "APP_REGISTRY 전체 — 정상 mock에서는 app_install이 성공한다 (gpu_proot/korean_locale은 skip)" \
    _test_contract_install_success_for_all_ids

# =============================================================================
# M10: 다운로드 무결성 — 버전 핀 + sha256 상수 + 스니펫 주입
# =============================================================================
describe "다운로드 무결성 — sha256 상수"

_test_sha256_constants_are_64hex() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local failed=0 v val
    for v in _SEVENZIP_SHA256 _SUMATRA_SHA256 _NOTEPADPP_SHA256 _WINMERGE_SHA256 \
             _WINE_STAGING_SHA256 _WINETRICKS_SHA256 _NIMF_DEB_SHA256 _TOR_SHA256 \
             _THORIUM_DEB_SHA256 _DBEAVER_SHA256 _NOTION_SHA256 _BURP_SHA256 \
             _MINIFORGE_SHA256 _TEAMS_DEB_SHA256
    do
        val="${!v:-}"
        if ! [[ "$val" =~ ^[0-9a-f]{64}$ ]]; then
            echo "[ASSERT] ${v}가 64자 hex가 아님: '${val}'" >&2
            failed=1
        fi
    done
    val="${CLAUDE_CODE_TARBALL_SHA256[2.1.261]:-}"
    if ! [[ "$val" =~ ^[0-9a-f]{64}$ ]]; then
        echo "[ASSERT] CLAUDE_CODE_TARBALL_SHA256[2.1.261]가 64자 hex가 아님: '${val}'" >&2
        failed=1
    fi
    cleanup_sandbox "$sb"
    return "$failed"
}
it "설치기 sha256 상수 15종이 모두 64자 hex다" _test_sha256_constants_are_64hex

describe "다운로드 무결성 — 스니펫 주입"

# wine_exec_shell 문맥(별도 셸)에는 fetch_verified 정의가 텍스트로 주입돼야 한다.
_test_sevenzip_snippet_injects_fetch_verified() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    : > "${PREFIX}/bin/wine-hangover"; chmod +x "${PREFIX}/bin/wine-hangover"
    local captured=""
    wine_exec_shell() { captured="$1"; return 0; }
    app_install_sevenzip >/dev/null 2>&1
    assert_output_contains "$captured" "fetch_verified ()" || { cleanup_sandbox "$sb"; return 1; }
    assert_output_contains "$captured" "$_SEVENZIP_SHA256" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "sevenzip 스니펫에 fetch_verified 정의 + sha256이 주입된다" _test_sevenzip_snippet_injects_fetch_verified

_test_wine_apps_snippets_inject_fetch_verified() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    : > "${PREFIX}/bin/wine-hangover"; chmod +x "${PREFIX}/bin/wine-hangover"
    local failed=0 id sha_var captured
    for id in sumatrapdf:_SUMATRA_SHA256 notepadpp:_NOTEPADPP_SHA256 winmerge:_WINMERGE_SHA256; do
        sha_var="${id#*:}"; id="${id%%:*}"
        captured=""
        wine_exec_shell() { captured="$1"; return 0; }
        "app_install_${id}" >/dev/null 2>&1
        [[ "$captured" == *"fetch_verified ()"* ]] || { echo "[ASSERT] ${id} 스니펫에 fetch_verified 정의 없음" >&2; failed=1; }
        [[ "$captured" == *"${!sha_var}"* ]] || { echo "[ASSERT] ${id} 스니펫에 ${sha_var} 값 없음" >&2; failed=1; }
    done
    cleanup_sandbox "$sb"
    return "$failed"
}
it "sumatrapdf/notepadpp/winmerge 스니펫에도 fetch_verified + sha256이 주입된다" \
    _test_wine_apps_snippets_inject_fetch_verified

# proot 문맥(proot_exec bash -c ... _ url sha)에도 sha 값이 위치인자로 넘어가야 한다.
_test_proot_installers_pass_sha_to_snippet() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local failed=0 pair id sha_var
    for pair in tor_browser:_TOR_SHA256 thorium:_THORIUM_DEB_SHA256 dbeaver:_DBEAVER_SHA256 \
                notion:_NOTION_SHA256 burpsuite:_BURP_SHA256 miniforge:_MINIFORGE_SHA256
    do
        id="${pair%%:*}"; sha_var="${pair#*:}"
        reset_mock_calls
        "app_install_${id}" >/dev/null 2>&1 || true
        assert_was_called "${!sha_var}" || {
            echo "[ASSERT] ${id}: proot_exec 인자에 ${sha_var} 값이 없음" >&2; failed=1; }
        assert_was_called "fetch_verified" || {
            echo "[ASSERT] ${id}: 스니펫에 fetch_verified 주입 없음" >&2; failed=1; }
    done
    cleanup_sandbox "$sb"
    return "$failed"
}
it "tor/thorium/dbeaver/notion/burp/miniforge가 스니펫에 sha256을 넘긴다" \
    _test_proot_installers_pass_sha_to_snippet

describe "teams — GitHub API 제거 + 3인자 deb_or_aur"

_test_teams_uses_pinned_url_with_sha() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_teams >/dev/null 2>&1
    assert_was_called "proot_pkg_install_deb_or_aur ${_TEAMS_DEB_URL} teams-for-linux ${_TEAMS_DEB_SHA256}" \
        || { cleanup_sandbox "$sb"; return 1; }
    assert_not_called "proot_exec curl" || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "teams → 핀 URL + sha256 3인자, API curl 호출 없음" _test_teams_uses_pinned_url_with_sha

describe "claude_code — M11 핀 상향"

_test_claude_pin_version() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    assert_eq "2.1.261" "$CLAUDE_CODE_PIN_VERSION" "핀 버전" || { cleanup_sandbox "$sb"; return 1; }
    assert_eq "2.1.261" "$(_claude_code_fetch_latest_version)" "fetch_latest_version 출력" \
        || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "CLAUDE_CODE_PIN_VERSION = 2.1.261 (M11)" _test_claude_pin_version

_test_claude_download_uses_fetch_verified() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local captured=""
    fetch_verified() { captured="$3"; printf 'tgz\n' > "$2"; }
    tar() { :; }
    mkdir -p "${CLAUDE_CODE_PREFIX}"; : > "${CLAUDE_CODE_PREFIX}/claude"
    _claude_code_download_native "2.1.261"
    assert_eq "${CLAUDE_CODE_TARBALL_SHA256[2.1.261]}" "$captured" "핀 버전 sha256이 fetch_verified로 전달됨" \
        || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "download → 등록된 sha256을 fetch_verified에 넘긴다" _test_claude_download_uses_fetch_verified

_test_claude_download_unknown_version_skips_sha() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local captured="UNSET"
    fetch_verified() { captured="${3:-}"; printf 'tgz\n' > "$2"; }
    tar() { :; }
    mkdir -p "${CLAUDE_CODE_PREFIX}"; : > "${CLAUDE_CODE_PREFIX}/claude"
    _claude_code_download_native "9.9.9"
    assert_eq "" "$captured" "미등록 버전은 빈 sha(검증 생략)로 넘어가야 함" \
        || { cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "미등록 버전 → 빈 sha256(검증 생략)" _test_claude_download_unknown_version_skips_sha

print_results
