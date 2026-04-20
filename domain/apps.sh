#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: apps.sh — 앱 레지스트리 + 설치 라우팅
# =============================================================================
# 형식: "id|이름|카테고리|설명"
# id는 domain/installers/${id}.sh의 app_install_${id}/app_remove_${id}/app_is_installed_${id} 와 매핑
# 카테고리: 그래픽 | 미디어 | 오피스 | 브라우저 | 개발 | 보안 | 유틸 | 소통

APP_REGISTRY=(
    "thunderbird|Thunderbird|소통|이메일 클라이언트 (Termux native)"
    "vlc|VLC|미디어|미디어 플레이어 (proot)"
    "gimp|GIMP|그래픽|이미지 편집 (Termux native)"
    "inkscape|Inkscape|그래픽|벡터 그래픽 편집 (Termux native)"
    "audacity|Audacity|미디어|오디오 편집 (Termux native)"
    "vscode|Visual Studio Code|개발|코드 에디터 (Termux native)"
    "libreoffice|LibreOffice|오피스|오픈소스 오피스 (proot)"
    "burpsuite|Burp Suite|보안|웹 보안 테스트 도구 (Termux native)"
    "tor_browser|Tor Browser|브라우저|익명 웹 브라우저 (proot)"
    "notion|Notion|오피스|노트 및 협업 도구 (proot AppImage)"
    "dbeaver|DBeaver|개발|범용 데이터베이스 클라이언트 (proot)"
    "miniforge|Miniforge3|개발|Python conda 환경 (proot)"
    "sasm|SASM|개발|어셈블러 IDE (proot)"
    "nautilus|Nautilus|유틸|파일 관리자 (proot)"
    "wine|Wine (Box64+Staging)|유틸|Windows 앱 실행"
    "kakaotalk|KakaoTalk|소통|카카오톡 PC (Wine)"
    "notepadpp|Notepad++|개발|텍스트 에디터 (Wine)"
    "sevenzip|7-Zip|유틸|파일 압축/해제 (Wine)"
    "sumatrapdf|Sumatra PDF|오피스|PDF/EPUB/MOBI 뷰어 (Wine)"
    "winmerge|WinMerge|개발|파일/폴더 비교·병합 (Wine)"
    "teams|Microsoft Teams|소통|팀 협업 도구 (proot)"
    "thorium|Thorium|브라우저|고속 웹 브라우저 (proot)"
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
