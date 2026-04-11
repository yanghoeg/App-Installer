#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: apps.sh — 앱 레지스트리 + 설치 라우팅
# =============================================================================
# 형식: "id|이름|설명"
# id는 domain/installers/${id}.sh의 app_install_${id}/app_remove_${id}/app_is_installed_${id} 와 매핑

APP_REGISTRY=(
    "thunderbird|Thunderbird|이메일 클라이언트 (Termux native)"
    "vlc|VLC|미디어 플레이어 (Termux native)"
    "vscode|Visual Studio Code|코드 에디터 (proot)"
    "libreoffice|LibreOffice|오픈소스 오피스 (proot)"
    "burpsuite|Burp Suite|웹 보안 테스트 도구 (proot)"
    "tor_browser|Tor Browser|익명 웹 브라우저 (proot)"
    "notion|Notion|노트 및 협업 도구 (proot AppImage)"
    "dbeaver|DBeaver|범용 데이터베이스 클라이언트 (proot)"
    "miniforge|Miniforge3|Python conda 환경 (proot)"
    "sasm|SASM|어셈블러 IDE (proot)"
    "nautilus|Nautilus|파일 관리자 (proot)"
    "wine|Wine (Box64+Staging)|Windows 앱 실행"
    "teams|Microsoft Teams|팀 협업 도구 (proot)"
    "thorium|Thorium|고속 웹 브라우저 (proot)"
    "onepassword|1Password|패스워드 관리자 (proot)"
)

# proot 설치 여부 확인
has_proot_distro() {
    [ -n "${PROOT_DISTRO:-}" ] && \
    [ -d "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}" ]
}

# 앱 설치 상태 확인 — app_is_installed_<id> 호출
app_is_installed() {
    local id="$1"
    "app_is_installed_${id}" 2>/dev/null
}

# 앱 설치 — app_install_<id> 호출
app_install() {
    local id="$1"
    "app_install_${id}"
}

# 앱 제거 — app_remove_<id> 호출
app_remove() {
    local id="$1"
    "app_remove_${id}"
}
