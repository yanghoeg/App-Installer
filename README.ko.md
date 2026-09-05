# App Installer

<div align="center">

[English](README.md) &nbsp;|&nbsp; **[한국어](README.ko.md)**

[![Android](https://img.shields.io/badge/Android-Termux-3DDC84?logo=android)](https://termux.dev)
[![Termux XFCE](https://img.shields.io/badge/Termux__XFCE-submodule-blue)](https://github.com/yanghoeg/Termux_XFCE)

</div>

---

[Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) 환경에서 동작하는 **앱 추가 설치/제거 GUI** 도구입니다.  
yad notebook 탭 GUI(zenity 폴백)로 앱을 선택하면 proot(Ubuntu/Arch) 또는 Termux native에 자동으로 설치합니다.

**테스트 기기**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

## 사용법

```bash
# Termux_XFCE 설치 후 터미널에서
app-installer

# XFCE 데스크탑에서
# 바탕화면 아이콘 → App Installer  또는  애플리케이션 메뉴 → App Installer
```

헤드리스 CLI(GUI 없음): `bash app-install.sh list|install <id>|remove <id>|status <id>`.

## 지원 앱 목록

| 앱 | 설명 | 설치 위치 | 비고 |
|----|------|-----------|------|
| **VS Code** | Visual Studio Code | proot | `--disable-gpu` 자동 적용 |
| **LibreOffice** | 오피스 스위트 | proot | bwrap 스텁 설치 |
| **Thunderbird** | 이메일 클라이언트 | Termux native | |
| **VLC** | 멀티미디어 플레이어 | Termux native | |
| **GIMP** | 이미지 편집 | Termux native | |
| **Inkscape** | 벡터 그래픽 편집 | Termux native | |
| **Audacity** | 오디오 편집 | Termux native | |
| **Nautilus** | GNOME 파일 관리자 | proot | 소프트웨어 렌더러 (MIT-SHM 우회) |
| **Notion** | 메모·생산성 앱 | proot | AppImage 추출 방식 |
| **Teams** | Microsoft Teams for Linux | proot | 커뮤니티 Electron 클라이언트 |
| **Wine (Box64+Staging)** | Box64로 Windows 앱 실행 | proot / native | ELF→box64 래퍼 (binfmt_misc 없음) |
| **Wine (Hangover)** | FEX/ARM64EC로 Windows 앱 실행 | Termux native | 더 빠름; WINEPREFIX 분리 |
| **Notepad++** | 텍스트 에디터 | Wine | |
| **7-Zip** | 파일 압축/해제 | Wine | |
| **Sumatra PDF** | PDF/EPUB/MOBI 뷰어 | Wine | |
| **WinMerge** | 파일/폴더 비교·병합 | Wine | |
| **Miniforge** | Conda 패키지 관리자 | proot | CLI 전용 |
| **DBeaver** | 유니버설 데이터베이스 클라이언트 | proot | |
| **Thorium** | Chromium 기반 고성능 브라우저 | proot | .deb 직접 추출 (AUR x86 전용) |
| **Tor Browser** | 익명 브라우저 | proot | arm64 포트 |
| **SASM** | 어셈블리 IDE | proot | Arch: 소스 빌드 (fasm x86 전용) |
| **Burp Suite** | 웹 보안 테스트 도구 | proot | arm64 인스톨러 |
| **1Password** | 패스워드 매니저 CLI (`op`) | proot | GUI는 arm64 미지원 |
| **Claude Code** | AI 코딩 어시스턴트 CLI | Termux native | glibc-runner 병행 필요 |
| **llama.cpp** | GGUF 추론 (`llama-gpu` / `llama-cli` / `llama-server`) | Termux native | `llama-gpu` = 네이티브 OpenCL GPU 가속 (기본 컨텍스트 4096, `LLAMA_CTX`로 변경); `llama-model-get`로 Qwen2.5/Qwen3.5 GGUF 다운로드 (`3.5-2b` Q5, `3.5-4b` Q4) |
| **aichat** | 터미널 AI 어시스턴트 CLI | Termux native | 로컬(`llama-server`)/클라우드 API 연동 |
| **Crush** | 터미널 AI 코딩 에이전트 | Termux native | 제공자 API 키 필요 |
| **Codex CLI** | OpenAI 코딩 에이전트 CLI | Termux native | `OPENAI_API_KEY` 필요 |
| **code-server** | 브라우저에서 여는 VS Code | Termux native | 127.0.0.1:8080 서빙 |
| **PyTorch + ONNX Runtime** | 온디바이스 ML 런타임 | Termux native | 약 280MB |
| **AI 업스케일 (ncnn)** | Real-ESRGAN + RIFE | Termux native | Vulkan 가속 |
| **Jujutsu** | Git 호환 VCS + `lazyjj` | Termux native | |
| **television** | 퍼지 파인더 (`tv`) | Termux native | |
| **superfile** | 현대적 TUI 파일 매니저 (`spf`) | Termux native | |
| **uutils-coreutils** | Rust 재구현 coreutils | Termux native | GNU coreutils와 병존 |
| **wayvnc** | 데스크탑 VNC 서버 | Termux native | wayland 세션 전용 (`wayvnc-start`) |
| **Neovim / Helix** | 터미널 모달 에디터 | Termux native | |
| **btop** | 시각적 리소스 모니터 (htop 후속) | Termux native | root-repo 활성화 필요 |
| **개발 CLI** | just, mise, hyperfine, tokei, direnv, watchexec | Termux native | mise·direnv는 셸 hook 직접 추가 필요 |

## 시스템 앱 (시스템 탭)

| 앱 | 설명 | 설치 위치 | 비고 |
|----|------|-----------|------|
| **GPU 가속** | Adreno Vulkan + Zink OpenGL | Termux native | |
| **GPU 개발 도구** | clvk, clinfo 등 | Termux native | |
| **GPU 가속 (proot)** | KGSL mesa + Vulkan WSI Layer | proot | Snapdragon 전용 |
| **한글 입력기 (fcitx5)** | fcitx5-hangul 한글 입력 | Termux native | |
| **한글 입력기 (proot)** | proot 내부 한글 로케일 + nimf/fcitx5 입력기 | proot | Ubuntu=nimf .deb, Arch=nimf AUR→fcitx5 폴백 |
| **한글 로케일** | force_gettext.so 기반 UI 한글화 | Termux native | |
| **한글 입력기 (nimf)** | nimf 한글 입력 | Termux native | 흡혈귀왕 빌드 |

## Termux API 앱 (Termux API 탭)

| 앱 | 설명 | 설치 위치 | 비고 |
|----|------|-----------|------|
| **밝기 조절** | XFCE 패널용 화면 밝기 조절 스크립트 | Termux native | |
| **볼륨 조절** | XFCE 패널용 볼륨 조절 스크립트 | Termux native | |
| **Conky 배터리** | Conky 위젯에 배터리 잔량·온도 표시 | Termux native | |
| **알림 도구** | 스크립트에서 Android 알림바 전송 | Termux native | |
| **TTS 음성** | 텍스트를 음성으로 변환 (Android TTS) | Termux native | |
| **음성인식** | 음성을 텍스트로 변환 (Android STT) | Termux native | |
| **배경화면 동기화** | XFCE 배경화면을 Android에 동기화 | Termux native | |

Termux API 앱은 `termux-api` 패키지와 Termux:API APK가 필요합니다.

## arm64 호환성 비고

실기기(Ubuntu 25.10 / Arch Linux ARM)에서 테스트 완료 — 아래 우회법이 자동 적용됩니다:

| 문제 | 우회법 |
|------|--------|
| GTK4 앱 충돌 (glycin/bwrap) | `proot_setup_bwrap`: proot 내 no-op bwrap 스텁 설치 |
| `sudo` PATH 초기화 (sudo-rs) | `proot_setup_sudo_path`: Termux 툴을 `/usr/local/bin`에 심링크 |
| Nautilus MIT-SHM BadAccess | `GSK_RENDERER=cairo GDK_RENDERING=image` 소프트웨어 렌더러 강제 |
| VS Code GPU 프로세스 crash | `--disable-gpu` + `dbus-run-session` |
| Wine x86-64 ELF 자동 실행 불가 (binfmt_misc 없음) | `.elf`로 이름 변경 후 `box64` 래퍼 스크립트 생성 |
| Thorium AUR은 x86 전용 | `ar`로 arm64 .deb 직접 추출 |
| SASM `fasm` 의존성이 x86 전용 (Arch) | `qmake` + `nasm`으로 소스 빌드 |
| 1Password GUI arm64 미지원 | `1password-cli`(`op`) 설치 |

## Wine — 두 가지 백엔드

두 백엔드를 동시에 설치할 수 있고, PATH 상의 `wine`은 활성 백엔드로 위임하는 디스패처입니다.

| 백엔드 | 구성 | WINEPREFIX | 래퍼 |
|--------|------|------------|------|
| `box64` (proot) | proot 내부 Box64(ARM64) + Wine-Staging x86_64 tarball | `$HOME/.wine` | `wine-box64` |
| `box64` (proot 없음) | glibc-runner + box64-glibc + Wine-Staging tarball | `$HOME/.wine` | `wine-box64` |
| `hangover` | `hangover` 패키지 (Wine는 네이티브 arm64, 앱만 FEX/ARM64EC) | `$HOME/.wine-hangover` | `wine-hangover` |

```bash
wine-backend            # 활성 백엔드 + 설치 상태 확인
wine-backend hangover   # 백엔드 전환
wine kakao.exe          # 활성 백엔드로 Windows 앱 실행
wine winecfg            # Wine 환경 설정
winetricks vcrun2019    # DLL/런타임 설치 (box64 백엔드, proot 내부)
winetricks dotnet48
```

> prefix를 일부러 분리했습니다 — 서로 다른 Wine 빌드(wow64 staging vs ARM64EC)가
> 하나의 prefix를 공유하면 깨집니다. 백엔드를 바꾼 뒤에는 Wine 앱을 다시 설치하세요.

> **한계**: 안티치트 게임, 커널 드라이버 의존 앱, 최신 .NET 복잡 앱은 동작하지 않습니다.

## 동작 방식

`~/.config/termux-xfce/config`에서 `PROOT_DISTRO`, `PROOT_USER`를 읽어 동작합니다.  
Termux_XFCE 설치 시 자동 생성됩니다.

```
PROOT_DISTRO=ubuntu
PROOT_USER=yanghoeg
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
├── install.sh                  ← yad notebook 탭 GUI 메인 (zenity 폴백; 설치·제거 루프)
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
├── lib/
│   ├── fetch.sh                ← fetch_verified — 다운로드 + sha256 검증 (스니펫 주입 지원)
│   ├── common.sh, proot_path.sh, wine_backend.sh
└── tests/
```

## 다운로드 무결성

외부에서 받는 모든 파일(.deb, tarball, zip, AppImage, 설치 exe)은 **버전이 고정**되어 있고
**sha256 상수**가 설치기 파일 상단에 박혀 있습니다 (예: `domain/installers/wine.sh`의
`_WINE_STAGING_VER` / `_WINE_STAGING_SHA256`). `lib/fetch.sh`의 `fetch_verified`가 받은 뒤
해시를 대조하고, **불일치면 받은 파일을 지우고 설치를 중단**합니다(rc≠0).
`releases/latest` 같은 "항상 최신" API 조회는 쓰지 않습니다 — 업스트림이 바뀌면 조용히
다른 바이너리가 설치되기 때문입니다. (예외: `llama_cpp.sh`의 사용자 선택 모델)

버전을 올릴 때는 새 URL을 받아 `sha256sum <파일>`로 해시를 구한 뒤 해당 설치기의
`_*_VER` / `_*_SHA256` 상수를 함께 갱신합니다.

## 브랜치 전략

| 브랜치 | 용도 |
|--------|------|
| `main` | 안정 버전 — 실기기 테스트 완료 |
| `dev` | 개발 중 — 기능 추가·버그 수정 후 main에 머지 |

---

## 관련 링크

- [yanghoeg/Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) — 메인 설치 스크립트 (이 repo를 Git Submodule로 포함)
