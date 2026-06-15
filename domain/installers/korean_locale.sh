#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 한글 로케일 — force_gettext.so LD_PRELOAD 기반 UI 한글화
# 스켈레톤: install.sh의 setup_korean_locale_native 로직 이관
# domain/locale_ko.sh 함수들을 호출 (메인 프로젝트에 이미 구현됨)

app_install_korean_locale() {
    # locale_ko.sh가 로드되어 있는지 확인
    if ! type setup_korean_locale_native &>/dev/null; then
        # 메인 프로젝트의 domain/locale_ko.sh 로드 시도
        local main_domain="${SCRIPT_DIR}/../domain/locale_ko.sh"
        if [ -f "$main_domain" ]; then
            source "$main_domain"
        else
            echo "[ERROR] locale_ko.sh를 찾을 수 없습니다." >&2
            echo "메인 프로젝트(Termux_XFCE)가 설치되어 있어야 합니다." >&2
            return 1
        fi
    fi

    setup_korean_locale_native
}

app_remove_korean_locale() {
    # force_gettext.so 제거
    rm -f "${PREFIX}/lib/force_gettext.so"

    # RC 파일에서 korean 블록 제거
    local rc
    for rc in "${PREFIX}/etc/bash.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        sed -i '/# termux-xfce-korean/,/^fi$/d' "$rc" 2>/dev/null || true
    done

    # startxfce4-ko 래퍼 제거
    rm -f "$HOME/bin/startxfce4-ko"

    echo "한글 로케일 제거 완료. XFCE 재시작 후 영어 UI로 복원됩니다."
}

app_is_installed_korean_locale() {
    [ -f "${PREFIX}/lib/force_gettext.so" ]
}
