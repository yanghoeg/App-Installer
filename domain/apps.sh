#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: apps.sh — 앱 레지스트리 + 설치 라우팅
# =============================================================================
# 형식: "id|이름|카테고리|설명"
# id는 domain/installers/${id}.sh의 app_install_${id}/app_remove_${id}/app_is_installed_${id} 와 매핑
# 카테고리: 시스템 | 그래픽 | 미디어 | 오피스 | 브라우저 | 개발 | 보안 | 유틸 | 소통

APP_REGISTRY=(
    "thunderbird|Thunderbird|소통|이메일 클라이언트 (Termux native)"
    "vlc|VLC|미디어|미디어 플레이어 (proot)"
    "gimp|GIMP|그래픽|이미지 편집 (Termux native)"
    "inkscape|Inkscape|그래픽|벡터 그래픽 편집 (Termux native)"
    "audacity|Audacity|미디어|오디오 편집 (Termux native)"
    "vscode|Visual Studio Code|개발|코드 에디터 (Termux native)"
    "claude_code|Claude Code|개발|AI 코딩 어시스턴트 CLI (Termux native + glibc-runner)"
    "ollama|Ollama|개발|로컬 LLM 실행기 (Termux native, 모델 별도 pull)"
    "aichat|aichat|개발|터미널 AI 어시스턴트 CLI (Termux native, Ollama/클라우드 연동)"
    "libreoffice|LibreOffice|오피스|오픈소스 오피스 (proot)"
    "burpsuite|Burp Suite|보안|웹 보안 테스트 도구 (proot)"
    "tor_browser|Tor Browser|브라우저|익명 웹 브라우저 (proot)"
    "notion|Notion|오피스|노트 및 협업 도구 (proot AppImage)"
    "dbeaver|DBeaver|개발|범용 데이터베이스 클라이언트 (proot)"
    "miniforge|Miniforge3|개발|Python conda 환경 (proot)"
    "sasm|SASM|개발|어셈블러 IDE (proot)"
    "nautilus|Nautilus|유틸|파일 관리자 (proot)"
    "wine|Wine (Box64+Staging)|유틸|Windows 앱 실행"
    "notepadpp|Notepad++|개발|텍스트 에디터 (Wine)"
    "sevenzip|7-Zip|유틸|파일 압축/해제 (Wine)"
    "sumatrapdf|Sumatra PDF|오피스|PDF/EPUB/MOBI 뷰어 (Wine)"
    "winmerge|WinMerge|개발|파일/폴더 비교·병합 (Wine)"
    "teams|Microsoft Teams|소통|팀 협업 도구 (proot)"
    "thorium|Thorium|브라우저|고속 웹 브라우저 (proot)"
    "onepassword|1Password|보안|패스워드 관리자 (proot)"
    "nimf|한글 입력기 (nimf)|시스템|nimf 한글 입력 (Termux native, 흡혈귀왕 빌드)"
    "gpu_native|GPU 가속|시스템|Adreno Vulkan + Zink OpenGL (Termux native)"
    "gpu_dev|GPU 개발 도구|시스템|clvk, clinfo 등 (Termux native)"
    "gpu_proot|GPU 가속 (proot)|시스템|KGSL mesa + Vulkan WSI Layer (proot, Snapdragon 전용)"
    "korean_input|한글 입력기 (fcitx5)|시스템|fcitx5-hangul 한글 입력 (Termux native)"
    "korean_locale|한글 로케일|시스템|force_gettext.so 기반 UI 한글화 (Termux native)"
    "api_conky_battery|Conky 배터리|Termux API|Conky 위젯에 배터리 잔량·온도 표시"
    "api_brightness|밝기 조절|Termux API|XFCE 패널용 화면 밝기 조절 스크립트"
    "api_volume|볼륨 조절|Termux API|XFCE 패널용 볼륨 조절 스크립트"
    "api_notification|알림 도구|Termux API|스크립트에서 Android 알림바 전송"
    "api_tts|TTS 음성|Termux API|텍스트를 음성으로 변환 (Android TTS)"
    "api_stt|음성인식|Termux API|음성을 텍스트로 변환 (Android STT)"
    "api_wallpaper|배경화면 동기화|Termux API|XFCE 배경화면을 Android에 동기화"
)

# 탭 그룹 정의 — install.sh GUI에서 yad notebook 탭 매핑
TAB_GROUPS=(
    "앱|소통,미디어,그래픽,오피스,브라우저,개발,보안,유틸"
    "시스템|시스템"
    "Termux API|Termux API"
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
# 설치기 계약: app_install_<id>는 임계 명령(pkg install/curl/proot_exec 등) 실패 시
# 반드시 non-zero를 반환해야 하며, 실패 시 .desktop 런처를 생성하지 말 것.
app_install() {
    local id="$1"
    "app_install_${id}"
}

# 앱 제거 — app_remove_<id> 호출
app_remove() {
    local id="$1"
    "app_remove_${id}"
}

# 업그레이드 지원 여부 — app_upgrade_<id> 함수가 정의된 앱만 true
app_can_upgrade() {
    local id="$1"
    declare -F "app_upgrade_${id}" >/dev/null 2>&1
}

# 앱 업그레이드 — app_upgrade_<id> 호출 (반환값 그대로 전달)
# 설치기 계약: app_upgrade_<id>도 임계 명령 실패 시 반드시 non-zero를 반환해야 하며,
# 실패 시 .desktop 런처를 재생성/변경하지 말 것.
app_upgrade() {
    local id="$1"
    "app_upgrade_${id}"
}
