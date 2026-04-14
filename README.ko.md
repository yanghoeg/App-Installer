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

```bash
# Termux_XFCE 설치 후 터미널에서
app-installer

# XFCE 데스크탑에서
# 바탕화면 아이콘 → App Installer  또는  애플리케이션 메뉴 → App Installer
```

## 지원 앱 목록

| 앱 | 설명 | 설치 위치 | 비고 |
|----|------|-----------|------|
| **VS Code** | Visual Studio Code | proot | `--disable-gpu` 자동 적용 |
| **LibreOffice** | 오피스 스위트 | proot | bwrap 스텁 설치 |
| **Thunderbird** | 이메일 클라이언트 | Termux native | |
| **VLC** | 멀티미디어 플레이어 | Termux native | |
| **Nautilus** | GNOME 파일 관리자 | proot | 소프트웨어 렌더러 (MIT-SHM 우회) |
| **Notion** | 메모·생산성 앱 | proot | AppImage 추출 방식 |
| **Teams** | Microsoft Teams for Linux | proot | 커뮤니티 Electron 클라이언트 |
| **Wine** | Windows 앱 실행 (Box64 + Wine-Staging) | proot / native | ELF→box64 래퍼 (binfmt_misc 없음) |
| **Miniforge** | Conda 패키지 관리자 | proot | CLI 전용 |
| **DBeaver** | 유니버설 데이터베이스 클라이언트 | proot | |
| **Thorium** | Chromium 기반 고성능 브라우저 | proot | .deb 직접 추출 (AUR x86 전용) |
| **Tor Browser** | 익명 브라우저 | proot | arm64 포트 |
| **SASM** | 어셈블리 IDE | proot | Arch: 소스 빌드 (fasm x86 전용) |
| **Burp Suite** | 웹 보안 테스트 도구 | proot | arm64 인스톨러 |
| **1Password** | 패스워드 매니저 CLI (`op`) | proot | GUI는 arm64 미지원 |

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

## Wine (Box64 + Wine-Staging)

proot 유무에 따라 자동 분기합니다.

| 환경 | 구성 |
|------|------|
| proot Ubuntu/Arch | proot 내부 Box64(ARM64) + Wine-Staging x86_64 tarball |
| proot 없음 | glibc-runner + box64-glibc + Wine-Staging tarball |

```bash
wine kakao.exe          # Windows 앱 실행
wine winecfg            # Wine 환경 설정
winetricks vcrun2019    # DLL/런타임 설치
winetricks dotnet48
```

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
├── install.sh                  ← zenity GUI 메인 (설치·제거 루프)
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
