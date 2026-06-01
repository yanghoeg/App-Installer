# App Installer

<div align="center">

[English](README.md) &nbsp;|&nbsp; **[한국어](README.ko.md)**

[![Android](https://img.shields.io/badge/Android-Termux-3DDC84?logo=android)](https://termux.dev)
[![Termux XFCE](https://img.shields.io/badge/Termux__XFCE-submodule-blue)](https://github.com/yanghoeg/Termux_XFCE)

</div>

---

[Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) 환경에서 동작하는 **앱 추가 설치/제거 GUI** 도구입니다.  
zenity 다이얼로그로 앱을 선택하면 proot(Ubuntu/Arch) 또는 Termux native에 자동으로 설치합니다.

**테스트 기기**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

## 사용법

### GUI

```bash
# Termux_XFCE 설치 후 터미널에서
app-installer

# XFCE 데스크탑에서
# 바탕화면 아이콘 → App Installer  또는  애플리케이션 메뉴 → App Installer
```

### CLI

```bash
bash app-install.sh list              # 전체 앱 목록 + 설치 상태
bash app-install.sh list 개발         # 카테고리별 필터
bash app-install.sh install claude_code  # 앱 설치
bash app-install.sh remove vlc          # 앱 제거
bash app-install.sh status claude_code   # 설치 여부 확인
```

## 지원 앱 목록

| 앱 | 설명 | 설치 위치 | 비고 |
|----|------|-----------|------|
| **Thunderbird** | 이메일 클라이언트 | Termux native | |
| **VLC** | 미디어 플레이어 | proot | |
| **GIMP** | 이미지 편집 | Termux native | |
| **Inkscape** | 벡터 그래픽 편집 | Termux native | |
| **Audacity** | 오디오 편집 | Termux native | |
| **VS Code** | Visual Studio Code | Termux native | |
| **Claude Code** | AI 코딩 어시스턴트 CLI | Termux native | glibc-runner + npm 우회 |
| **LibreOffice** | 오피스 스위트 | proot | bwrap 스텁 설치 |
| **Burp Suite** | 웹 보안 테스트 도구 | Termux native | arm64 인스톨러 |
| **Tor Browser** | 익명 브라우저 | proot | arm64 포트 |
| **Notion** | 메모·생산성 앱 | proot | AppImage 추출 방식 |
| **DBeaver** | 데이터베이스 클라이언트 | proot | |
| **Miniforge** | Conda 패키지 관리자 | proot | CLI 전용 |
| **SASM** | 어셈블리 IDE | proot | Arch: 소스 빌드 (fasm x86 전용) |
| **Nautilus** | GNOME 파일 관리자 | proot | 소프트웨어 렌더러 (MIT-SHM 우회) |
| **Wine** | Windows 앱 실행 (Box64 + Wine-Staging WoW64) | proot / native | 32/64-bit PE 지원 |
| **Notepad++** | 텍스트 에디터 | Wine | portable zip |
| **7-Zip** | 파일 압축/해제 | Wine | |
| **Sumatra PDF** | PDF/EPUB/MOBI 뷰어 | Wine | |
| **WinMerge** | 파일/폴더 비교·병합 | Wine | |
| **Teams** | Microsoft Teams | proot | 커뮤니티 Electron 클라이언트 |
| **Thorium** | 고속 웹 브라우저 | proot | .deb 직접 추출 (AUR x86 전용) |
| **GPU 가속** | Adreno Vulkan + Zink OpenGL | Termux native | Snapdragon 전용 |
| **GPU 가속 (proot)** | KGSL mesa + Vulkan WSI Layer | proot | Snapdragon 전용 |
| **한글 입력기 (fcitx5)** | fcitx5-hangul | Termux native | |
| **한글 입력기 (nimf)** | nimf 입력기 프레임워크 | Termux native | Termux native 빌드: [미코(미니기기코리아)](https://cafe.naver.com/minigkorea) 흡혈귀왕 제공 |
| **한글 로케일** | force_gettext.so UI 한글화 | Termux native | 한글 렌더링: [미코(미니기기코리아)](https://cafe.naver.com/minigkorea) 흡혈귀왕 제공 |
| **배터리 위젯** | XFCE 패널 배터리 표시 | Termux API | genmon |
| **밝기/볼륨 조절** | XFCE 패널 스크립트 | Termux API | |
| **알림/TTS/STT** | Android 연동 도구 | Termux API | |
| **배경화면 동기화** | XFCE↔Android 배경화면 | Termux API | |

## arm64 호환성 비고

실기기(Ubuntu 25.10 / Arch Linux ARM)에서 테스트 완료 — 아래 우회법이 자동 적용됩니다:

| 문제 | 우회법 |
|------|--------|
| GTK4 앱 충돌 (glycin/bwrap) | `proot_setup_bwrap`: proot 내 no-op bwrap 스텁 설치 |
| `sudo` PATH 초기화 (sudo-rs) | `proot_setup_sudo_path`: Termux 툴을 `/usr/local/bin`에 심링크 |
| Nautilus MIT-SHM BadAccess | `GSK_RENDERER=cairo GDK_RENDERING=image` 소프트웨어 렌더러 강제 |
| VS Code GPU 프로세스 crash | `--disable-gpu` + `dbus-run-session` |
| Wine x86-64 ELF 자동 실행 불가 (binfmt_misc 없음) | `.elf`로 이름 변경 후 `box64` 래퍼 스크립트 생성 |
| Wine 32-bit PE 미지원 (기존 amd64 빌드) | WoW64 빌드로 전환 — 64-bit Wine만으로 32-bit PE 실행 |
| Thorium AUR은 x86 전용 | `ar`로 arm64 .deb 직접 추출 |
| SASM `fasm` 의존성이 x86 전용 (Arch) | `qmake` + `nasm`으로 소스 빌드 |
| Claude Code v2.1.114+ native ELF (glibc 동적 링커 요구) | npm 우회 — tarball 직접 다운로드 후 `grun` wrapper로 실행 |

## Wine (Box64 + Wine-Staging WoW64)

proot 유무에 따라 자동 분기합니다. WoW64 빌드로 32-bit/64-bit Windows PE 모두 지원합니다.

| 환경 | 구성 |
|------|------|
| proot Ubuntu/Arch | proot 내부 Box64(ARM64) + Wine-Staging WoW64 tarball |
| proot 없음 | glibc-runner + box64-glibc + Wine-Staging WoW64 tarball |

속도 최적화:
- `termux-wake-lock` — Android CPU 쓰로틀링 방지
- `wineserver -p` — 영구 wineserver로 후속 실행 가속

```bash
wine program.exe        # Windows 앱 실행
wine winecfg            # Wine 환경 설정
winetricks vcrun2019    # DLL/런타임 설치
winetricks dotnet48
```

> **한계**: 안티치트/Themida 보호 앱, 커널 드라이버 의존 앱, 최신 .NET 복잡 앱은 동작하지 않습니다.

## 동작 방식

`~/.config/termux-xfce/config`에서 `PROOT_DISTRO`, `PROOT_USER`를 읽어 동작합니다.  
Termux_XFCE 설치 시 자동 생성됩니다.

```
PROOT_DISTRO=ubuntu
PROOT_USER=<username>
```

config가 없으면 `ubuntu`를 기본값으로 사용합니다.

proot 앱은 `prun`을 통해 실행됩니다:

```bash
proot-distro login <distro> --user <user> --shared-tmp -- env DISPLAY=:0.0 <command>
```

설치 후 `.desktop` 파일이 `$PREFIX/share/applications/`에 생성되어 XFCE 메뉴에 자동 등록됩니다.

proot 셸에 직접 진입할 수도 있습니다:

```bash
ubuntu          # Ubuntu proot 인터랙티브 셸 진입
ubuntu <명령>   # Ubuntu proot에서 단일 명령 실행
```

## 파일 구조

```
app-installer/
├── install.sh                  ← GUI 메인 (yad/zenity, 설치·제거 루프)
├── app-install.sh              ← CLI 인터페이스 (list/install/remove/status)
├── ports/
│   └── pkg_manager.sh          ← 패키지 관리 계약 (인터페이스)
├── adapters/
│   └── output/
│       ├── pkg_proot_base.sh   ← 공통 proot 헬퍼 (bwrap 스텁, sudo path)
│       ├── pkg_termux.sh       ← Termux pkg 어댑터
│       ├── pkg_ubuntu.sh       ← Ubuntu apt 어댑터
│       └── pkg_arch.sh         ← Arch pacman 어댑터
├── domain/
│   ├── apps.sh                 ← 앱 레지스트리 + install/remove 디스패처
│   ├── desktop.sh              ← .desktop 파일 생성 헬퍼
│   └── installers/             ← 앱별 설치 스크립트
└── tests/
```

## 브랜치 전략

| 브랜치 | 용도 |
|--------|------|
| `main` | 안정 버전 — 실기기 테스트 완료 |
| `dev` | 개발 중 — 기능 추가·버그 수정 후 main에 머지 |

---

## 관련 링크

- [yanghoeg/Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) — 메인 설치 스크립트 (이 repo를 Git Submodule로 포함)
