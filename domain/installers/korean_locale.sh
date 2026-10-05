#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 한글 로케일 — force_gettext.so LD_PRELOAD 기반 UI 한글화
# The parent project's locale domain runs with its own paths and adapters.

app_install_korean_locale() (
    local main_dir
    main_dir="$(cd "${BASH_SOURCE[0]%/*}/../../.." && pwd)" || return 1
    if [ ! -f "$main_dir/domain/locale_ko.sh" ]; then
        echo "[ERROR] 메인 프로젝트(Termux_XFCE)의 locale_ko.sh가 필요합니다." >&2
        return 1
    fi

    # Only the GUI opens a picker; the headless CLI accepts an explicit path.
    if [ -z "${KOREAN_LOCALE_ZIP:-}" ]; then
        case "${UI:-}" in
            yad|zenity)
                KOREAN_LOCALE_ZIP=$("$UI" --file-selection \
                    --title="한글 번역 카탈로그 ZIP 선택" --file-filter="*.zip") || return 1
                ;;
        esac
    fi

    SCRIPT_DIR="$main_dir"
    source "$main_dir/adapters/output/ui_terminal.sh" || return 1
    source "$main_dir/adapters/output/pkg_common_termux.sh" || return 1
    source "$main_dir/domain/termux_env.sh" || return 1
    source "$main_dir/domain/locale_ko.sh" || return 1
    setup_korean_locale_native || return 1
    [ -s "$PREFIX/lib/force_gettext.so" ]
)

app_remove_korean_locale() {
    # force_gettext.so 및 소스 해시 제거
    rm -f "${PREFIX}/lib/force_gettext.so" "${PREFIX}/lib/force_gettext.so.sha256" || return 1

    # RC 파일에서 korean 블록 제거
    local rc
    for rc in "${PREFIX}/etc/bash.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        sed -i '/# termux-xfce-korean/,/^fi$/d' "$rc" || return 1
    done

    # startxfce4-ko 래퍼 제거
    rm -f "$HOME/bin/startxfce4-ko" || return 1

    echo "한글 로케일 제거 완료. XFCE 재시작 후 영어 UI로 복원됩니다."
}

app_is_installed_korean_locale() {
    [ -s "${PREFIX}/lib/force_gettext.so" ]
}

# 카탈로그 재선택 없이 기존 한글 훅과 RC 환경만 갱신한다.
app_upgrade_korean_locale() (
    app_is_installed_korean_locale || return 1
    local main_dir
    main_dir="$(cd "${BASH_SOURCE[0]%/*}/../../.." && pwd)" || return 1
    SCRIPT_DIR="$main_dir"
    source "$main_dir/adapters/output/ui_terminal.sh" || return 1
    source "$main_dir/adapters/output/pkg_common_termux.sh" || return 1
    source "$main_dir/domain/termux_env.sh" || return 1
    source "$main_dir/domain/locale_ko.sh" || return 1
    _build_force_gettext || return 1
    setup_korean_rc
)
