# App Installer

<div align="center">

[English](README.md) &nbsp;|&nbsp; **[한국어](README.ko.md)**

[![Android](https://img.shields.io/badge/Android-Termux-3DDC84?logo=android)](https://termux.dev)
[![usix-termux](https://img.shields.io/badge/usix--termux-submodule-blue)](https://github.com/yanghoeg/usix-termux)

</div>

---

[usix-termux](https://github.com/yanghoeg/usix-termux) 환경에서 동작하는 **앱 추가 설치/제거 GUI** 도구입니다.  
yad notebook 탭 GUI(zenity 폴백)로 앱을 선택하면 proot(Ubuntu/Arch) 또는 Termux native에 자동으로 설치합니다.

**테스트 기기**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

## 사용법

```bash
# usix-termux 설치 후 터미널에서
app-installer

# XFCE 데스크탑에서
# 바탕화면 아이콘 → App Installer  또는  애플리케이션 메뉴 → App Installer
```

**App Installer 저장소 폴더**(부모 저장소의 `app-installer/`)에서는 CLI로 실행할 수 있습니다.

```bash
bash app-install.sh list
bash app-install.sh list 개발
bash app-install.sh install vlc
bash app-install.sh status vlc
bash app-install.sh remove vlc
```

분류 필터에는 `개발`, `시스템`, `Termux API`, `Wine` 등 레지스트리의 값을 사용합니다.
`install`은 이미 설치된 것으로 판정한 항목을 건너뜁니다 — 단 앱이 무결성 확인
(`app_verify_<id>`)을 제공하면 그 확인에 실패한 설치본은 재설치로 복구합니다
(현재 Claude Code만 해당). `status`는 상태를 출력하며
알려진 ID라면 설치·미설치 모두 성공으로 종료하므로 종료 코드만으로 설치 여부를
판정할 수 없습니다. 알 수 없는 ID와 작업 실패는 0이 아닌 코드로 종료합니다.
CLI에는 `upgrade`나 `rollback` 하위 명령이 없습니다.

### 업그레이드 · 롤백

설치된 앱에 `app_upgrade_<id>` 핸들러가 있으면 GUI에 **제거**와 **업그레이드**를
함께 표시합니다. 현재 핸들러는 다음과 같습니다.

| 앱 | 업그레이드 동작 |
|----|-----------------|
| Claude Code | `CLAUDE_CODE_PIN_VERSION`으로 갱신. 기록된 기존 버전을 백업하고 다운로드 후 `--version` 실행. 백업 실패 시 바이너리 교체 전에 중단. 다운로드·스모크 실패 시 해당 백업 복원 시도 |
| Codex CLI | `CODEX_PIN_VERSION`으로 바이너리·`codex-code-mode-host` 헬퍼·래퍼 갱신. Claude Code의 백업·스모크·롤백 절차는 없음 |
| Notion | 기존 AppImage 런처를 Termux Firefox 웹 런처로 교체. 이전 앱 디렉터리는 제거할 때까지 보존 |

그 외 설치된 항목은 제거할 수 있습니다. Claude Code의 스모크 검사는 `/login`을
확인하지 않으며 신규 설치에는 이전 버전 백업이 없습니다. 수동 롤백과 실기기 검증은
[Claude Code 핀·복구 안내](docs/claude-code-login-regression.md)를 참고하세요.

## 지원 앱 목록

CLI에는 [domain/apps.sh](domain/apps.sh)의 ID를 사용합니다. 여러 ID를 묶은 행도
실제로는 각각 설치하는 항목입니다. `tor_browser`는 상태 확인·제거용으로 남겨 두었으며
GUI에서는 기존 설치가 감지될 때만 표시합니다. CLI 목록에는 계속 포함됩니다.

| ID | 앱 | 설명 | 설치 위치 | 비고 |
|----|----|------|-----------|------|
| `vscode` | **VS Code** | Visual Studio Code | proot | `--disable-gpu` 자동 적용 |
| `libreoffice` | **LibreOffice** | 오피스 스위트 | proot | bwrap 스텁 설치 |
| `thunderbird` | **Thunderbird** | 이메일 클라이언트 | Termux native | |
| `vlc` | **VLC** | 멀티미디어 플레이어 | Termux native | |
| `gimp` | **GIMP** | 이미지 편집 | Termux native | |
| `inkscape` | **Inkscape** | 벡터 그래픽 편집 | Termux native | |
| `audacity` | **Audacity** | 오디오 편집 | Termux native | |
| `nautilus` | **Nautilus** | GNOME 파일 관리자 | proot | 소프트웨어 렌더러 (MIT-SHM 우회) |
| `notion` | **Notion** | 메모·생산성 앱 | Termux native | Firefox 웹 런처 |
| `teams` | **Teams** | Microsoft Teams for Linux | proot | 커뮤니티 Electron 클라이언트 |
| `wine` | **Wine (Box64+Staging)** | Box64로 Windows 앱 실행 | proot / native | ELF→box64 래퍼 (binfmt_misc 없음) |
| `hangover` | **Wine (Hangover)** | FEX/ARM64EC로 Windows 앱 실행 | Termux native | WINEPREFIX 분리 |
| `notepadpp` | **Notepad++** | 텍스트 에디터 | Wine | |
| `sevenzip` | **7-Zip** | 파일 압축/해제 | Wine | |
| `sumatrapdf` | **Sumatra PDF** | PDF/EPUB/MOBI 뷰어 | Wine | |
| `winmerge` | **WinMerge** | 파일/폴더 비교·병합 | Wine | |
| `miniforge` | **Miniforge** | Conda 패키지 관리자 | proot | CLI 전용 |
| `dbeaver` | **DBeaver** | 유니버설 데이터베이스 클라이언트 | proot | Java가 포함된 arm64 tarball |
| `thorium` | **Thorium** | Chromium 기반 고성능 브라우저 | proot | .deb 직접 추출 (AUR x86 전용) |
| `tor_browser` | **Tor Browser** | 기존 ARM64 포트 제거 | proot | 이 설치기에서는 신규 설치 중단 |
| `sasm` | **SASM** | 어셈블리 IDE | proot | Arch: 소스 빌드 (fasm x86 전용) |
| `burpsuite` | **Burp Suite** | 웹 보안 테스트 도구 | proot | arm64 인스톨러 |
| `onepassword` | **1Password** | 패스워드 매니저 CLI (`op`) | proot | GUI는 arm64 미지원 |
| `claude_code` | **Claude Code** | AI 코딩 어시스턴트 CLI | Termux native | glibc-runner 병행 필요 |
| `llama_cpp` | **llama.cpp** | GGUF 추론 (`llama-gpu` / `llama-cli` / `llama-server`) | Termux native | `llama-gpu` = 네이티브 OpenCL GPU 가속 (기본 컨텍스트 4096, `LLAMA_CTX`로 변경); `llama-model-get`로 Qwen2.5/Qwen3.5 GGUF 다운로드 (`3.5-2b` Q5, `3.5-4b` Q4) |
| `aichat` | **aichat** | 터미널 AI 어시스턴트 CLI | Termux native | 로컬(`llama-server`)/클라우드 API 연동 |
| `crush` | **Crush** | 터미널 AI 코딩 에이전트 | Termux native | 제공자 API 키 필요 |
| `codex` | **Codex CLI** | OpenAI 코딩 에이전트 CLI | Termux native | 업스트림 정적 musl 바이너리(핀 버전) + `codex-code-mode-host` 헬퍼 + proot 네트워크 shim(DNS/CA). 래퍼가 임베디드 모드로 고정(`features.daemon_auto_start=false`)하므로 `codex agents` / `/daemon`은 사용 불가. `codex login` 또는 `OPENAI_API_KEY` 필요 |
| `code_server` | **code-server** | 브라우저에서 여는 VS Code | Termux native | 127.0.0.1:8080 서빙 |
| `ml_python` | **PyTorch + ONNX Runtime** | 온디바이스 ML 런타임 | Termux native | 약 280MB |
| `ncnn_upscale` | **AI 업스케일 (ncnn)** | Real-ESRGAN + RIFE | Termux native | Vulkan 가속 |
| `jujutsu` | **Jujutsu** | Git 호환 VCS + `lazyjj` | Termux native | |
| `television` | **television** | 퍼지 파인더 (`tv`) | Termux native | |
| `superfile` | **superfile** | 현대적 TUI 파일 매니저 (`spf`) | Termux native | |
| `uutils` | **uutils-coreutils** | Rust 재구현 coreutils | Termux native | GNU coreutils와 병존 |
| `wayvnc` | **wayvnc** | 데스크탑 VNC 서버 | Termux native | wlroots 전용, Anland/KWin 미지원 (`wayvnc-start`) |
| `neovim`, `helix` | **Neovim / Helix** | 터미널 모달 에디터 | Termux native | |
| `btop` | **btop** | 시각적 리소스 모니터 (htop 후속) | Termux native | root-repo 활성화 필요 |
| `just`, `mise`, `hyperfine`, `tokei`, `direnv`, `watchexec` | **개발 CLI** | just, mise, hyperfine, tokei, direnv, watchexec | Termux native | mise·direnv는 셸 hook 직접 추가 필요 |

## 시스템 앱 (시스템 탭)

| ID | 앱 | 설명 | 설치 위치 | 비고 |
|----|----|------|-----------|------|
| `gpu_native` | **GPU 가속** | Adreno Vulkan + Zink OpenGL | Termux native | X11 런처에서 가속 또는 소프트웨어 폴백 선택 |
| `gpu_dev` | **GPU 개발 도구** | clvk, clinfo 등 | Termux native | |
| `gpu_proot` | **GPU 가속 (proot)** | 컨테이너 Turnip + Zink | proot | Termux glibc KGSL Turnip(버전·sha256 고정)을 넣고 검증 후 활성화. Ubuntu 24.04·25.10·26.04는 OpenGL을 lfdevs Freedreno KGSL 빌드(`/opt/termux-xfce-mesa`, 고정)로 EGL 확인 후 전환 |
| `chroot_ng` | **proot 가속 런타임 (chroot-ng)** | ptrace 없는 `prun` 실행 엔진 (실험적) | Termux native (소스 빌드) | 고정 커밋 빌드, 기기 판정·rootfs 실행 검사 통과 시 설치. `PRUN_RUNTIME=chroot-ng`일 때만 사용 |
| `korean_input` | **한글 입력기 (fcitx5)** | fcitx5-hangul 한글 입력 | Termux native | X11 입력기로 선택; XFCE 재시작 필요 |
| `korean_proot` | **한글 입력기 (proot)** | proot 내부 한글 로케일 + nimf/fcitx5 입력기 | proot | Ubuntu=nimf .deb, Arch=nimf AUR→fcitx5 폴백 |
| `korean_locale` | **한글 로케일** | force_gettext.so 기반 UI 한글화 | Termux native | 부모 usix-termux 저장소와 번역 카탈로그 ZIP 필요 |
| `nimf` | **한글 입력기 (nimf)** | nimf 한글 입력 | Termux native | 흡혈귀왕 빌드 |

## Termux API 앱 (Termux API 탭)

| ID | 앱 | 설명 | 설치 위치 | 비고 |
|----|----|------|-----------|------|
| `api_brightness` | **밝기 조절** | XFCE 패널용 화면 밝기 조절 스크립트 | Termux native | |
| `api_volume` | **볼륨 조절** | XFCE 패널용 볼륨 조절 스크립트 | Termux native | |
| `api_conky_battery` | **패널 배터리** | XFCE genmon 패널에 배터리 잔량·온도 표시 | Termux native | Generic Monitor에 `~/.local/bin/battery-genmon` 직접 등록; `battery-info`는 팝업 |
| `api_notification` | **알림 도구** | 스크립트에서 Android 알림바 전송 | Termux native | |
| `api_tts` | **TTS 음성** | 텍스트를 음성으로 변환 (Android TTS) | Termux native | |
| `api_stt` | **음성인식** | 음성을 텍스트로 변환 (Android STT) | Termux native | |
| `api_wallpaper` | **배경화면 동기화** | XFCE 배경화면을 Android에 동기화 | Termux native | |

Termux API 앱은 `termux-api` 패키지와 Termux:API APK가 필요합니다.

## arm64 호환성 비고

설치기에 다음 우회 처리가 구현되어 있습니다. 이전 실기기 확인 환경은 Ubuntu 25.10 /
Arch Linux ARM이며 현재 모든 앱·버전의 동작을 보장하는 결과는 아닙니다. 새 구성은
[실기기 체크리스트](TEST_LOG.md)로 확인하세요.

| 문제 | 우회법 |
|------|--------|
| GTK4 앱 충돌 (glycin/bwrap) | `proot_setup_bwrap`: 네임스페이스 격리 없이 명령을 실행하는 bwrap 호환 래퍼 설치 |
| `sudo` PATH 초기화 (sudo-rs) | `proot_setup_sudo_path`: Termux 툴을 `/usr/local/bin`에 심링크 |
| Nautilus MIT-SHM BadAccess | `GSK_RENDERER=cairo GDK_RENDERING=image` 소프트웨어 렌더러 강제 |
| VS Code GPU 프로세스 crash | `--disable-gpu` + `dbus-run-session` |
| Wine x86-64 ELF 자동 실행 불가 (binfmt_misc 없음) | ELF 파일을 `bin/.elf/`로 옮긴 뒤 `box64` 래퍼 생성 |
| Thorium AUR은 x86 전용 | `ar`로 arm64 .deb 직접 추출 |
| SASM `fasm` 의존성이 x86 전용 (Arch) | `qmake` + `nasm`으로 소스 빌드 |
| 1Password GUI arm64 미지원 | `1password-cli`(`op`) 설치 |
| 사용자 Bash 로그인 구성이 `~/.profile`을 읽지 않음 | `korean_proot`이 `/etc/profile.d/termux-xfce-locale.sh`에 기록하고 `prun` 명령은 Bash 로그인 셸에서 실행 |

proot 데스크탑 런처는 공통 `prun-gui` 헬퍼를 사용하고 현재 디스플레이를 상속합니다.
CLI 전용 도구는 메뉴 항목을 만들지 않을 수 있습니다.

## Wine — 두 가지 백엔드

두 백엔드를 동시에 설치할 수 있고, PATH 상의 `wine`은 활성 백엔드로 위임하는 디스패처입니다.

| 백엔드 | 구성 | WINEPREFIX | 래퍼 |
|--------|------|------------|------|
| `box64` (proot) | 고정 커밋의 Box64 소스 빌드 + Wine-Staging x86_64 tarball | proot 사용자의 `$HOME/.wine` | `wine-box64` |
| `box64` (proot 없음) | glibc-runner + box64-glibc + Wine-Staging tarball | Termux의 `$HOME/.wine` | `wine-box64` |
| `hangover` | `hangover` 패키지 (Wine는 네이티브 arm64, 앱만 FEX/ARM64EC) | `$HOME/.wine-hangover` | `wine-hangover` |

```bash
wine-backend            # 활성 백엔드 + 설치 상태 확인
wine-backend hangover   # 설치된 백엔드로 전환
wine kakao.exe          # 활성 백엔드로 Windows 앱 실행
wine winecfg            # Wine 환경 설정

# 설정된 proot 배포판에 box64 백엔드를 설치한 경우
wine-backend box64
prun winetricks vcrun2019
prun winetricks dotnet48
```

prefix는 서로 분리되어 있으며 백엔드를 바꿔도 Windows 앱이 옮겨지지는 않습니다.
공용 `.desktop` 파일 때문에 전환 후에도 설치된 것으로 표시될 수 있고, 이때 CLI는
`install`을 건너뜁니다. 이 설치기로 옮기려면 원래 백엔드가 활성화된 상태에서 앱을
제거하고 새 백엔드로 전환한 뒤 다시 설치하세요. 두 prefix에 사본을 모두 남기려면
두 번째 백엔드의 Wine 명령으로 해당 Windows 앱의 설치 파일을 실행하세요. GUI에는 별도 재설치 명령이 없습니다. 제거는 현재 활성 백엔드의
prefix에 적용됩니다.

성능과 호환성은 기기·앱에 따라 다릅니다. 커널 드라이버나 안티치트가 필요한 앱은
대표적인 제약 대상이며, winetricks로 런타임을 설치했다고 실행을 보장하지는 않습니다.

## 동작 방식

CLI와 GUI 모두 명시한 `PROOT_DISTRO`, `PROOT_USER` 환경변수를 우선 사용하고,
지정하지 않은 값은 `~/.config/termux-xfce/config`에서 읽습니다.
usix-termux 설치 시 자동 생성됩니다.

```
PROOT_DISTRO=ubuntu
PROOT_USER=desktop
```

배포판을 지정하지 않으면 `ubuntu`를 기본값으로 사용합니다. `PROOT_DISTRO=""`는
native 전용 모드입니다. 배포판만 바꾸면 이전 배포판의 사용자 대신 새 배포판의
사용자를 자동으로 탐지합니다.

proot GUI 런처는 `prun-gui`로 로딩 알림을 표시한 뒤 부모 설치기의 `prun`에 명령을
전달합니다. 명령은 Bash 로그인 셸에서 실행하며 컨테이너 안에서는 `LD_PRELOAD`를
해제합니다. KWin이 동적으로 지정한 Xwayland 디스플레이를 포함해 현재 `DISPLAY`를
상속하며, 그래픽 세션 밖에서는 부모 래퍼가 `:0.0`을 기본값으로 사용합니다.

```bash
prun libreoffice
prun                  # PROOT_SHELL에서 지정한 대화형 셸
ubuntu                # Ubuntu 셸 (해당 배포판을 설치한 경우)
ubuntu uname -m        # Ubuntu에서 단일 명령 실행
```

GUI 항목은 `$PREFIX/share/applications/`에 등록하고 `~/Desktop`에도 복사할 수 있습니다.
CLI 전용 설치기는 `.desktop` 파일을 만들지 않아도 됩니다. rootfs 헬퍼는
`$PREFIX/var/lib/proot-distro` 아래의 `containers/<distro>/rootfs`와 구형
`installed-rootfs/<distro>` 경로를 모두 지원합니다.

### 한글 입력과 UI 한글화

native `korean_input`(fcitx5)과 `nimf`는 `~/.config/termux-xfce/input-method`에
선택을 저장합니다(`none`, `nimf`, `fcitx5`). 공통
`$PREFIX/etc/profile.d/termux-xfce-input.sh`가 X11에 적용하고 선택된 native 입력기만
자동 시작합니다. 다른 입력기를 설치하면 선택이 바뀌며 선택된 입력기를 제거하면
`none`으로 돌아갑니다. XFCE를 재시작해 적용하세요. Wayland 경로는 X11 입력 모듈
변수를 지우고 KDE에서 해당 자동 시작 항목을 제외해 Anland가 Android 키보드 입력을
처리하도록 합니다.

`korean_locale`는 입력기와 별개입니다. 부모 usix-termux 저장소와
`ko/LC_MESSAGES/*.mo`가 포함된 ZIP이 필요합니다. GUI에서는 파일을 선택하고
CLI에서는 다음과 같이 지정합니다.

```bash
KOREAN_LOCALE_ZIP=/path/to/locale.zip bash app-install.sh install korean_locale
```

카탈로그가 없거나 컴파일에 실패하면 오류를 반환합니다. 로케일 훅은
`$PREFIX/lib/force_gettext.so`가 있을 때만 로드하며 native 입력기 선택과 독립적입니다.

`korean_proot`는 컨테이너용 로케일과 입력기를 설치합니다. Ubuntu는 고정된 nimf
패키지를, Arch는 AUR의 nimf를 사용하며 실패하면 fcitx5로 폴백합니다.
proot 안의 `/etc/profile.d/termux-xfce-locale.sh`에 기록하고 구형 `.profile`의
관리 블록은 제거합니다. 컨테이너 앱 설정은 native 입력기 선택과 별도로 관리합니다.

## 파일 구조

```
app-installer/
├── install.sh                  ← yad notebook GUI (zenity 폴백; 설치·제거·업그레이드)
├── app-install.sh              ← list/install/remove/status CLI
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
│   ├── input_method.sh         ← native 입력기 선택·자동 시작 공통 관리
│   ├── build_box64.sh          ← 고정된 Box64 소스 빌드 헬퍼
│   ├── build_sasm.sh           ← 고정된 SASM 소스 빌드 헬퍼
│   └── common.sh, proot_path.sh, wine_backend.sh
├── docs/
│   └── claude-code-login-regression.md ← Claude Code 핀·롤백·로그인 검증
└── tests/                      ← framework.sh, mocks.sh, test_{domain_apps,adapters,ports,fetch,proot_path,cli}.sh
                                   (test_nimf_*_real.sh: 실기기 전용)
```

## 다운로드 무결성

Wine tarball이나 고정된 `.deb`처럼 직접 받는 릴리스 파일은 설치기에 버전과 SHA-256을
선언합니다. [lib/fetch.sh](lib/fetch.sh)의 `fetch_verified`는 다운로드 실패·빈 파일·
해시 불일치 시 대상 파일을 지우고 0이 아닌 코드를 반환합니다. **해시가 비어 있으면
경고만 출력하고 검증을 생략**하므로 모든 호출에 해시를 강제하는 헬퍼는 아닙니다.

저장소 패키지는 각 패키지 관리자의 검증을 사용합니다. 소스 빌드는 별도 규칙을 따릅니다.
Box64와 SASM은 고정 Git 커밋을 검사하며 AUR 레시피는 이 프로젝트의 SHA-256 표로
고정하지 않습니다. 사용자가 선택한 llama.cpp 모델도 이 표 없이 별도로
다운로드합니다. `CLAUDE_CODE_PIN_VERSION`을 비우면 npm `latest` 조회를 사용하며
기본값은 고정 버전입니다.

직접 다운로드하는 버전을 바꿀 때는 출처를 확인하고 URL·버전·해시를 함께 갱신하세요.
해시 표에 없는 버전으로 값만 바꾸면 검증이 경고로 줄어들 수 있습니다. 부모 설치기의
APK·자산 다운로드는 별도 경로이므로 이 헬퍼의 검증 범위를 부모의 모든 다운로드에
적용해서는 안 됩니다.

## 테스트

App Installer 저장소 폴더에서 실행합니다.

```bash
for suite in domain_apps adapters ports fetch proot_path cli \
    review_claude_code review_input_gpu review_removal_wine review_app_core; do
    bash "tests/test_${suite}.sh" || exit 1
done
```

도메인, 어댑터, 포트, 다운로드, rootfs 경로, CLI, Wine 실행, 입력기 의존성,
제거 및 업그레이드 실패 처리를 검사합니다. PC에서는 mock과 정적
검사를 사용하며, CLI 테스트는 패키지·다운로드 명령을 격리한 상태에서 실제 진입점을
실행합니다. 부모 로케일 통합 테스트에는 usix-termux 저장소가 필요합니다.
`tests/test_nimf_*_real.sh`는 실기기의 Termux에서 실행하며 스크립트가 직접 proot에
진입해 패키지를 설치합니다. 호스트 테스트 반복문에는 포함하지 마세요. 부모 저장소의
`modern_install` 스위트도 공통 입력기·GPU·런처 동작을 검사합니다.
[TEST_LOG.md](TEST_LOG.md)는 통과 기록이 아닌 실기기 체크리스트입니다.

## 브랜치 전략

| 브랜치 | 용도 |
|--------|------|
| `main` | 최종 사용자용 통합 브랜치 |
| `dev` | `main` 반영 전 개발·검증 |

---

## 관련 링크

- [yanghoeg/usix-termux](https://github.com/yanghoeg/usix-termux) — 메인 설치 스크립트 (이 repo를 Git Submodule로 포함)
