#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 한글 입력기 (proot) — proot 내부 한글 로케일 + nimf/fcitx5
# Ubuntu: nimf .deb 직접 설치 (공식 repo 미제공) / Arch: nimf AUR → 실패 시 fcitx5 폴백
# Termux native 한글 입력기(korean_input/nimf)와 별개 — proot 내부 GUI 앱용이다.

_KOREAN_PROOT_PKGS_UBUNTU=(
    language-pack-ko
    language-pack-gnome-ko-base
    locales
    fonts-nanum-extra
    fonts-noto-cjk
    fonts-roboto
    im-config
    # nimf: Ubuntu 공식 repo 미제공 → 아래 .deb 직접 설치
)

# nimf GitHub Releases ARM64 .deb (Ubuntu 24.04 빌드 — 25.10에서도 호환)
# 태그(v1.4.17)에 고정 — releases/latest 사용 금지(무결성 검증 불가능해짐).
_KOREAN_PROOT_NIMF_DEB_BASE_URL="https://github.com/hamonikr/nimf/releases/download/v1.4.17"
_KOREAN_PROOT_NIMF_DEBS=(
    "nimf_1.4.17_arm64-ubuntu.2404.arm64.deb"
    "nimf-i18n_1.4.17_arm64-ubuntu.2404.arm64.deb"
)

# 각 .deb의 sha256 (dpkg -i 전 무결성 검증용 — proot_pkg_install_deb_url이 소비)
# -g 필수: 이 파일이 함수 안에서 source될 수 있어 -g 없으면 declare가 그 함수의
# 로컬 스코프로 묶여 함수 반환 시 배열이 통째로 사라진다.
declare -gA _KOREAN_PROOT_NIMF_DEB_SHA256=(
    ["nimf_1.4.17_arm64-ubuntu.2404.arm64.deb"]="0530909cf696828bdcd54c122ad465af8bbdf83b1e7eb2fe7a6d6da388334c58"
    ["nimf-i18n_1.4.17_arm64-ubuntu.2404.arm64.deb"]="7a1f9c3b3893439fa14a4d369e6eac722f40128a595bd98e032e14857e0201b4"
)

_KOREAN_PROOT_PKGS_ARCH=(
    noto-fonts-cjk   # 한국어 폰트 (공식 repo)
    # ttf-nanum: AUR 전용 → noto-fonts-cjk로 대체
    libhangul
)

# Arch nimf: AUR 빌드(yay) → 실패 시 fcitx5 폴백
_KOREAN_PROOT_PKGS_ARCH_NIMF=(
    nimf
    nimf-libhangul
)

_KOREAN_PROOT_PKGS_ARCH_FCITX5=(
    fcitx5-hangul
    fcitx5-configtool
)

# 생성 파일(/etc/profile.d/termux-xfce-locale.sh) 식별용 헤더/푸터 마커
_KOREAN_PROOT_MARK="# termux-xfce-korean"
_KOREAN_PROOT_END_MARK="# end-termux-xfce-korean"

# 로케일/IM env 파일 경로 — /etc/profile.d에 둔다.
# Arch 기본 스켈레톤은 ~/.bash_profile을 포함해 bash 로그인이 ~/.profile을 읽지 않으므로
# (~/.bash_profile → ~/.bashrc 체인), 모든 로그인 셸(bash/zsh)이 /etc/profile 경유로 읽는
# profile.d에 두어야 GUI 앱에 로케일이 전파된다. GPU env(부모 setup_proot_env)와 동일 채널.
_korean_proot_locale_file() {
    echo "$(_proot_rootfs)/etc/profile.d/termux-xfce-locale.sh"
}

# 패키지 목록 설치 — 이미 설치된 것은 건너뛰고, 하나라도 실패하면 rc 1
_korean_proot_install_pkgs() {
    local total=$# i=0 p
    for p in "$@"; do
        ((++i))
        if proot_pkg_is_installed "$p"; then
            echo "  (${i}/${total}) ${p} — 이미 설치됨"
        else
            echo "  (${i}/${total}) ${p} 설치 중..."
            proot_pkg_install "$p" || return 1
        fi
    done
    return 0
}

# $1 = nimf | fcitx5 — /etc/profile.d에 로케일/IM env를 쓴다.
# export 필수 — 로그인 쉘이 source하므로 export 없으면 쉘 변수로만 남아 GUI 앱에 전파 안 됨.
# 전체가 생성 파일이므로 항상 덮어쓴다(멱등). 마커로 감싸 식별을 단순화한다.
_korean_proot_write_locale() {
    local im="$1" f
    f="$(_korean_proot_locale_file)"
    mkdir -p "$(dirname "$f")"

    {
        echo "$_KOREAN_PROOT_MARK"
        echo "export LANG=ko_KR.UTF-8"
        echo "export LANGUAGE=ko_KR.UTF-8"
        echo "export LC_ALL=ko_KR.UTF-8"
        if [ "$im" = "nimf" ]; then
            echo "export GTK_IM_MODULE=nimf"
            echo "export QT_IM_MODULE=nimf"
            echo 'export XMODIFIERS="@im=nimf"'
            echo 'command -v nimf >/dev/null 2>&1 && ! pgrep -x nimf >/dev/null 2>&1 && { nimf & disown; } 2>/dev/null'
        else
            echo "export GTK_IM_MODULE=fcitx5"
            echo "export QT_IM_MODULE=fcitx5"
            echo 'export XMODIFIERS="@im=fcitx5"'
            echo 'command -v fcitx5 >/dev/null 2>&1 && ! pgrep -x fcitx5 >/dev/null 2>&1 && { fcitx5 -d --replace 2>/dev/null & disown; } 2>/dev/null'
        fi
        echo "$_KOREAN_PROOT_END_MARK"
    } > "$f"
    return 0
}

_korean_proot_install_ubuntu() {
    _korean_proot_install_pkgs "${_KOREAN_PROOT_PKGS_UBUNTU[@]}" || return 1

    # nimf은 Ubuntu 공식 repo에 없으므로 GitHub Releases .deb 직접 설치
    if ! proot_exec bash -c "command -v nimf >/dev/null 2>&1"; then
        echo "  nimf .deb 설치 중..."
        # nimf 런타임 의존성 (Ubuntu 패키지명 — 무엇이 필요한지는 도메인 지식)
        proot_pkg_install libglib2.0-0 libgtk-3-0 libdbus-1-3 2>/dev/null || true

        local deb
        local -a urls=()
        for deb in "${_KOREAN_PROOT_NIMF_DEBS[@]}"; do
            urls+=("${_KOREAN_PROOT_NIMF_DEB_BASE_URL}/${deb}|${_KOREAN_PROOT_NIMF_DEB_SHA256[$deb]:-}")
        done
        proot_pkg_install_deb_url "${urls[@]}" || return 1
    fi

    _korean_proot_write_locale nimf || return 1

    local locale_file
    locale_file="$(_proot_rootfs)/etc/default/locale"
    mkdir -p "$(dirname "$locale_file")"
    cat > "$locale_file" << 'EOF'
LANG=ko_KR.UTF-8
LANGUAGE=ko_KR.UTF-8
EOF

    # im-config로 nimf을 기본 입력기로 설정 (없어도 치명적이지 않음)
    proot_exec bash -c "im-config -n nimf 2>/dev/null || true" || true
    return 0
}

_korean_proot_install_arch() {
    _korean_proot_install_pkgs "${_KOREAN_PROOT_PKGS_ARCH[@]}" || return 1

    # nimf AUR 빌드 시도 → 하나라도 실패하면 fcitx5 폴백
    local use_nimf=true p
    for p in "${_KOREAN_PROOT_PKGS_ARCH_NIMF[@]}"; do
        if proot_pkg_is_installed "$p"; then
            continue
        fi
        proot_pkg_install_aur "$p" 2>/dev/null || { use_nimf=false; break; }
    done

    if $use_nimf; then
        _korean_proot_write_locale nimf || return 1
    else
        echo "[WARN] nimf AUR 빌드 실패 → fcitx5로 폴백" >&2
        _korean_proot_install_pkgs "${_KOREAN_PROOT_PKGS_ARCH_FCITX5[@]}" || return 1
        _korean_proot_write_locale fcitx5 || return 1
    fi

    local locale_gen
    locale_gen="$(_proot_rootfs)/etc/locale.gen"
    mkdir -p "$(dirname "$locale_gen")"
    grep -q '^ko_KR.UTF-8 UTF-8$' "$locale_gen" 2>/dev/null || \
        echo "ko_KR.UTF-8 UTF-8" >> "$locale_gen"
    proot_exec sudo locale-gen || return 1
    return 0
}

app_install_korean_proot() {
    if ! has_proot_distro; then
        echo "[ERROR] proot 환경이 필요합니다" >&2
        return 1
    fi

    echo "${PROOT_DISTRO} 한글 환경 설정"

    case "${PROOT_DISTRO:-}" in
        ubuntu)
            _korean_proot_install_ubuntu || return 1
            ;;
        archlinux)
            _korean_proot_install_arch || return 1
            ;;
        *)
            echo "[ERROR] 지원하지 않는 PROOT_DISTRO: ${PROOT_DISTRO:-<unset>}" >&2
            return 1
            ;;
    esac

    echo "proot 한글 IME 설정 완료"
    echo "proot 세션을 다시 로그인하면 한글 입력기가 자동 기동됩니다."
    return 0
}

app_remove_korean_proot() {
    rm -f "$(_korean_proot_locale_file)" 2>/dev/null || true

    # 폰트/로케일 패키지는 남긴다 (다른 앱이 의존) — IME만 제거
    case "${PROOT_DISTRO:-}" in
        ubuntu)
            proot_pkg_remove nimf nimf-i18n 2>/dev/null || true
            ;;
        archlinux)
            local p
            for p in nimf nimf-libhangul fcitx5-hangul fcitx5-configtool; do
                if proot_pkg_is_installed "$p"; then
                    proot_pkg_remove "$p" 2>/dev/null || true
                fi
            done
            ;;
    esac

    echo "proot 한글 IME 제거 완료 (폰트/로케일 패키지는 유지)"
    return 0
}

app_is_installed_korean_proot() {
    [ -f "$(_korean_proot_locale_file)" ]
}
