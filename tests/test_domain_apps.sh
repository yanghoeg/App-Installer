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

_WIP_APPS_NO_INSTALLER=()

_is_wip_app() {
    local needle="$1"
    for wip in "${_WIP_APPS_NO_INSTALLER[@]}"; do
        [ "$needle" = "$wip" ] && return 0
    done
    return 1
}

_test_registry_all_have_installer_functions() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    local failed=0
    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r id _ _ <<< "$entry"
        _is_wip_app "$id" && continue   # WIP는 별도 skip 테스트로 추적
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
it "모든 앱(WIP 제외)에 app_install/app_remove/app_is_installed 함수가 있다" \
    _test_registry_all_have_installer_functions


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

# =============================================================================
# VS Code — Termux native (code-oss)
# =============================================================================
describe "VS Code — Termux native 설치"

_test_vscode_install_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_vscode
    assert_was_called "termux_pkg_install code-oss"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install code-oss 호출" _test_vscode_install_calls_termux_pkg

_test_vscode_install_registers_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_vscode
    [ -f "${PREFIX}/share/applications/code-oss.desktop" ] || { echo "[ASSERT] desktop file not created" >&2; cleanup_sandbox "$sb"; return 1; }
    grep -q "no-sandbox" "${PREFIX}/share/applications/code-oss.desktop" || { echo "[ASSERT] --no-sandbox flag missing" >&2; cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "install → desktop 파일 생성 (--no-sandbox 포함)" _test_vscode_install_registers_desktop

_test_vscode_remove_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_remove_vscode
    assert_was_called "termux_pkg_remove code-oss"
    cleanup_sandbox "$sb"
}
it "remove → termux_pkg_remove code-oss 호출" _test_vscode_remove_calls_termux_pkg

# =============================================================================
# Burp Suite — Termux native (tur-packages)
# =============================================================================
describe "Burp Suite — Termux native 설치"

_test_burpsuite_install_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_burpsuite
    assert_was_called "termux_pkg_install burpsuite"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install burpsuite 호출" _test_burpsuite_install_calls_termux_pkg

_test_burpsuite_remove_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_remove_burpsuite
    assert_was_called "termux_pkg_remove burpsuite"
    cleanup_sandbox "$sb"
}
it "remove → termux_pkg_remove burpsuite 호출" _test_burpsuite_remove_calls_termux_pkg

# =============================================================================
# LibreOffice — proot 설치 (패키지명 추상화)
# =============================================================================
describe "LibreOffice — proot 설치"

_test_libreoffice_install_uses_proot_dep() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_libreoffice
    assert_was_called "proot_dep libreoffice"
    cleanup_sandbox "$sb"
}
it "install → proot_dep libreoffice 호출 (DEP_MAP 추상화)" _test_libreoffice_install_uses_proot_dep

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

_test_dbeaver_install_uses_proot_dep_jdk() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_dbeaver
    assert_was_called "proot_dep jdk"
    cleanup_sandbox "$sb"
}
it "install → proot_dep jdk 호출 (DEP_MAP 추상화)" _test_dbeaver_install_uses_proot_dep_jdk

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

_test_wine_proot_path_calls_mesa_vulkan_dep() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine
    assert_was_called "proot_dep mesa_vulkan"
    cleanup_sandbox "$sb"
}
it "proot 있음 → proot_dep mesa_vulkan 호출 (DEP_MAP 추상화)" _test_wine_proot_path_calls_mesa_vulkan_dep

_test_wine_native_path_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=false
    # _wine_install_native에서 wget이 없으면 실패하지만, termux_pkg_install 기록은 됨
    app_install_wine 2>/dev/null || true
    assert_was_called "termux_pkg_install glibc-repo"
    cleanup_sandbox "$sb"
}
it "proot 없음 → termux_pkg_install glibc-repo 호출 (native 경로)" _test_wine_native_path_calls_termux_pkg

_test_wine_proot_path_does_not_call_termux_glibc() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine
    assert_not_called "termux_pkg_install glibc-repo"
    cleanup_sandbox "$sb"
}
it "proot 있음 → glibc-repo 설치 미호출 (proot 경로)" _test_wine_proot_path_does_not_call_termux_glibc

_test_wine_launcher_creates_desktop_without_shell() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine
    assert_file_exists "${PREFIX}/share/applications/wine64.desktop"
    # explorer /desktop=shell은 Box64에서 먹통 → wine explorer만 사용
    if grep -q '/desktop=shell' "${PREFIX}/share/applications/wine64.desktop"; then
        echo "[ASSERT] desktop에 /desktop=shell 포함됨 (Box64 호환 불가)" >&2
        cleanup_sandbox "$sb"; return 1
    fi
    cleanup_sandbox "$sb"
}
it "proot 있음 → desktop 파일에 /desktop=shell 미포함" _test_wine_launcher_creates_desktop_without_shell

_test_wine_wrapper_has_dpi_sync() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_wine
    assert_file_contains "${PREFIX}/bin/wine" "WINE_DPI"
    assert_file_contains "${PREFIX}/bin/wine" "LogPixels"
    cleanup_sandbox "$sb"
}
it "proot 있음 → wine wrapper에 DPI 동기화 로직 포함" _test_wine_wrapper_has_dpi_sync

# =============================================================================
# KakaoTalk — Wine 앱
# =============================================================================
describe "KakaoTalk — Wine 앱 설치"

_test_kakaotalk_requires_wine() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    # wine 미설치 상태 → wine부터 설치해야 함
    app_install_kakaotalk
    assert_was_called "proot_pkg_install_box64"
    cleanup_sandbox "$sb"
}
it "Wine 미설치 시 Wine 먼저 설치" _test_kakaotalk_requires_wine

_test_kakaotalk_install_creates_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_kakaotalk
    assert_file_exists "${PREFIX}/share/applications/kakaotalk.desktop"
    assert_file_exists "${HOME}/Desktop/kakaotalk.desktop"
    cleanup_sandbox "$sb"
}
it "install → .desktop 파일 생성" _test_kakaotalk_install_creates_desktop

_test_kakaotalk_desktop_uses_wine_wrapper() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_kakaotalk
    assert_file_contains "${PREFIX}/share/applications/kakaotalk.desktop" "wine"
    assert_file_contains "${PREFIX}/share/applications/kakaotalk.desktop" "KakaoTalk"
    cleanup_sandbox "$sb"
}
it "desktop Exec에 wine wrapper 사용" _test_kakaotalk_desktop_uses_wine_wrapper

_test_kakaotalk_remove_deletes_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    touch "${PREFIX}/share/applications/kakaotalk.desktop"
    touch "${HOME}/Desktop/kakaotalk.desktop"
    app_remove_kakaotalk
    [ ! -e "${PREFIX}/share/applications/kakaotalk.desktop" ]
    [ ! -e "${HOME}/Desktop/kakaotalk.desktop" ]
    cleanup_sandbox "$sb"
}
it "remove → .desktop 파일 삭제" _test_kakaotalk_remove_deletes_desktop

# =============================================================================
# Notepad++ — Wine 앱
# =============================================================================
describe "Notepad++ — Wine 앱 설치"

_test_notepadpp_install_creates_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_notepadpp
    assert_file_exists "${PREFIX}/share/applications/notepadpp.desktop"
    cleanup_sandbox "$sb"
}
it "install → .desktop 파일 생성" _test_notepadpp_install_creates_desktop

_test_notepadpp_desktop_supports_file_open() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_notepadpp
    assert_file_contains "${PREFIX}/share/applications/notepadpp.desktop" "%f"
    assert_file_contains "${PREFIX}/share/applications/notepadpp.desktop" "text/plain"
    cleanup_sandbox "$sb"
}
it "desktop에 파일 열기(%f) 및 MimeType 포함" _test_notepadpp_desktop_supports_file_open

# =============================================================================
# 7-Zip — Wine 앱
# =============================================================================
describe "7-Zip — Wine 앱 설치"

_test_sevenzip_install_creates_desktop() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_sevenzip
    assert_file_exists "${PREFIX}/share/applications/sevenzip.desktop"
    cleanup_sandbox "$sb"
}
it "install → .desktop 파일 생성" _test_sevenzip_install_creates_desktop

_test_sevenzip_desktop_has_archive_mimetypes() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    MOCK_HAS_PROOT=true
    app_install_sevenzip
    assert_file_contains "${PREFIX}/share/applications/sevenzip.desktop" "application/zip"
    assert_file_contains "${PREFIX}/share/applications/sevenzip.desktop" "application/x-7z-compressed"
    cleanup_sandbox "$sb"
}
it "desktop에 압축 MimeType 포함" _test_sevenzip_desktop_has_archive_mimetypes

# =============================================================================
# Notion — zlib 추상화
# =============================================================================
describe "Notion — proot 설치"

_test_notion_install_uses_proot_dep_zlib() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_notion
    assert_was_called "proot_dep zlib"
    cleanup_sandbox "$sb"
}
it "install → proot_dep zlib 호출 (DEP_MAP 추상화)" _test_notion_install_uses_proot_dep_zlib

_test_notion_does_not_hardcode_zlib_pkg() {
    # zlib1g-dev / zlib 같은 distro별 패키지명이 도메인에 없어야 함
    ! grep -qE "proot_pkg_install (zlib1g-dev|zlib\b)" \
        "${APP_DIR}/domain/installers/notion.sh" 2>/dev/null
}
it "notion.sh 도메인 — distro별 zlib 패키지명 하드코딩 없음" _test_notion_does_not_hardcode_zlib_pkg

# =============================================================================
# Tor Browser — tor_deps 추상화
# =============================================================================
describe "Tor Browser — proot 설치"

_test_tor_install_uses_proot_dep() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_tor_browser
    assert_was_called "proot_dep tor_deps"
    cleanup_sandbox "$sb"
}
it "install → proot_dep tor_deps 호출 (DEP_MAP 추상화)" _test_tor_install_uses_proot_dep

# =============================================================================
# Nautilus — bwrap 스텁 설정
# =============================================================================
describe "Nautilus — proot 설치"

_test_nautilus_install_sets_up_bwrap() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_nautilus
    assert_was_called "proot_setup_bwrap"
    cleanup_sandbox "$sb"
}
it "install → proot_setup_bwrap 호출 (GTK4 glycin 대응)" _test_nautilus_install_sets_up_bwrap

# =============================================================================
# GIMP/Inkscape/Audacity — Termux native (x11-repo)
# =============================================================================
describe "GIMP — Termux native 설치"

_test_gimp_install_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_gimp
    assert_was_called "termux_pkg_install gimp"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install gimp 호출" _test_gimp_install_calls_termux_pkg

_test_gimp_does_not_call_proot() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_gimp
    assert_not_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "install → proot 함수 미호출 (native 전용)" _test_gimp_does_not_call_proot

describe "Inkscape — Termux native 설치"

_test_inkscape_install_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_inkscape
    assert_was_called "termux_pkg_install inkscape"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install inkscape 호출" _test_inkscape_install_calls_termux_pkg

_test_inkscape_does_not_call_proot() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_inkscape
    assert_not_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "install → proot 함수 미호출 (native 전용)" _test_inkscape_does_not_call_proot

describe "Audacity — Termux native 설치"

_test_audacity_install_calls_termux_pkg() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_audacity
    assert_was_called "termux_pkg_install audacity"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install audacity 호출" _test_audacity_install_calls_termux_pkg

_test_audacity_does_not_call_proot() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_install_audacity
    assert_not_called "proot_pkg_install"
    cleanup_sandbox "$sb"
}
it "install → proot 함수 미호출 (native 전용)" _test_audacity_does_not_call_proot

# =============================================================================
# Claude Code — Termux native + glibc-runner
# =============================================================================
describe "Claude Code — Termux native + glibc-runner"

# 외부 호출(curl/tar/npm) override — 실제 네트워크 미사용
_claude_code_mock_externals() {
    _claude_code_fetch_latest_version() { echo "9.9.9"; }
    _claude_code_download_native()      {
        mkdir -p "${CLAUDE_CODE_PREFIX}"
        touch "${CLAUDE_CODE_PREFIX}/claude"
        chmod +x "${CLAUDE_CODE_PREFIX}/claude"
    }
    _claude_code_remove_npm_wrapper()   { :; }
}

_test_claude_code_install_calls_glibc_runner() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_code_mock_externals
    app_install_claude_code
    assert_was_called "termux_pkg_install glibc-runner"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install glibc-runner 호출" _test_claude_code_install_calls_glibc_runner

_test_claude_code_install_calls_glibc_repo() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_code_mock_externals
    app_install_claude_code
    assert_was_called "termux_pkg_install glibc-repo"
    cleanup_sandbox "$sb"
}
it "install → termux_pkg_install glibc-repo 호출 (의존성)" _test_claude_code_install_calls_glibc_repo

_test_claude_code_install_creates_wrapper() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_code_mock_externals
    app_install_claude_code
    assert_file_exists "${CLAUDE_CODE_BIN_PATH}"
    assert_file_contains "${CLAUDE_CODE_BIN_PATH}" "exec grun"
    cleanup_sandbox "$sb"
}
it "install → wrapper script 생성 (grun 호출)" _test_claude_code_install_creates_wrapper

_test_claude_code_install_creates_settings_when_absent() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_code_mock_externals
    app_install_claude_code
    assert_file_contains "${HOME}/.claude/settings.json" "DISABLE_AUTOUPDATER"
    cleanup_sandbox "$sb"
}
it "install → settings.json 부재 시 DISABLE_AUTOUPDATER 자동 작성" _test_claude_code_install_creates_settings_when_absent

_test_claude_code_install_preserves_existing_settings() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_code_mock_externals
    mkdir -p "${HOME}/.claude"
    echo '{"theme":"dark"}' > "${HOME}/.claude/settings.json"
    app_install_claude_code
    assert_file_contains "${HOME}/.claude/settings.json" '"theme":"dark"'
    cleanup_sandbox "$sb"
}
it "install → 기존 settings.json 보존 (덮어쓰지 않음)" _test_claude_code_install_preserves_existing_settings

_test_claude_code_install_fails_on_version_lookup_error() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    _claude_code_remove_npm_wrapper()    { :; }
    _claude_code_fetch_latest_version()  { echo ""; }   # 빈 응답 시뮬레이션
    app_install_claude_code 2>/dev/null && { echo "[ASSERT] 빈 버전인데 성공" >&2; cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "버전 조회 실패 시 install → 비정상 종료" _test_claude_code_install_fails_on_version_lookup_error

_test_claude_code_remove_deletes_wrapper_and_native() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    mkdir -p "${CLAUDE_CODE_PREFIX}"
    touch "${CLAUDE_CODE_BIN_PATH}" "${CLAUDE_CODE_PREFIX}/claude"
    app_remove_claude_code
    [ ! -e "${CLAUDE_CODE_BIN_PATH}" ] || { echo "[ASSERT] wrapper 미삭제" >&2; cleanup_sandbox "$sb"; return 1; }
    [ ! -e "${CLAUDE_CODE_PREFIX}/claude" ] || { echo "[ASSERT] native 미삭제" >&2; cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "remove → wrapper + native binary 삭제" _test_claude_code_remove_deletes_wrapper_and_native

_test_claude_code_is_installed_false_default() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    app_is_installed_claude_code && { echo "[ASSERT] wrapper 없는데 installed" >&2; cleanup_sandbox "$sb"; return 1; }
    cleanup_sandbox "$sb"
}
it "wrapper/native 미존재 → is_installed false" _test_claude_code_is_installed_false_default

_test_claude_code_is_installed_true_when_present() {
    local sb; sb=$(make_sandbox); _setup "$sb"
    mkdir -p "${CLAUDE_CODE_PREFIX}"
    echo "#!/bin/sh" > "${CLAUDE_CODE_BIN_PATH}"; chmod +x "${CLAUDE_CODE_BIN_PATH}"
    touch "${CLAUDE_CODE_PREFIX}/claude"; chmod +x "${CLAUDE_CODE_PREFIX}/claude"
    app_is_installed_claude_code
    cleanup_sandbox "$sb"
}
it "wrapper + native 모두 있으면 is_installed true" _test_claude_code_is_installed_true_when_present

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
    awk '/^while true/{ exit } { print }' "${APP_DIR}/install.sh" > "$tmp"
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

print_results
