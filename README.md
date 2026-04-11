# App Installer

<div align="center">

**[한국어](#한국어) · [English](#english)**

[![Android](https://img.shields.io/badge/Android-Termux-3DDC84?logo=android)](https://termux.dev)
[![Termux XFCE](https://img.shields.io/badge/Termux__XFCE-submodule-blue)](https://github.com/yanghoeg/Termux_XFCE)

</div>

---

## 한국어

[Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) 환경에서 동작하는 **앱 추가 설치/제거 GUI** 도구입니다.  
zenity 다이얼로그로 앱을 선택하면 proot(Ubuntu/Arch) 또는 Termux native에 자동으로 설치합니다.

**테스트 기기**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

### 사용법

```bash
# Termux_XFCE 설치 후 터미널에서
app-installer

# XFCE 데스크탑에서
# 애플리케이션 메뉴 → App Installer
```

### 지원 앱 목록

| 앱 | 설명 | 설치 위치 |
|----|------|-----------|
| **VS Code** | Visual Studio Code (arm64 deb) | proot |
| **LibreOffice** | 오피스 스위트 | proot |
| **Thunderbird** | 이메일 클라이언트 | Termux native |
| **VLC** | 멀티미디어 플레이어 | proot |
| **Nautilus** | GNOME 파일 관리자 | proot |
| **Notion** | 메모·생산성 앱 | proot |
| **Wine** | Windows 앱 실행 (Box64 + Wine-Staging) | proot / native |
| **Miniforge** | Conda 패키지 관리자 | proot |
| **DBeaver** | 유니버설 데이터베이스 클라이언트 | proot |
| **Thorium** | 고성능 Chromium 기반 브라우저 | proot |
| **Tor Browser** | 익명 브라우저 | proot |
| **SASM** | 어셈블리 IDE | proot |
| **Burp Suite** | 웹 보안 테스트 도구 | proot |
| **1Password** | 패스워드 매니저 | proot |

### Wine (Box64 + Wine-Staging)

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

### 동작 방식

`~/.config/termux-xfce/config`에서 `PROOT_DISTRO`, `PROOT_USER`를 읽어 동작합니다.  
Termux_XFCE 설치 시 자동 생성됩니다.

```
PROOT_DISTRO=ubuntu
PROOT_USER=yanghoeg
```

config가 없으면 `ubuntu`를 기본값으로 사용합니다.

proot 앱은 아래 방식으로 실행됩니다:

```bash
proot-distro login <distro> --user <user> --shared-tmp -- env DISPLAY=:1.0 <command>
```

설치 후 `.desktop` 파일이 `$PREFIX/share/applications/`에 생성되어 XFCE 메뉴에 자동 등록됩니다.

### 파일 구조

```
app-installer/
├── install.sh                  ← zenity GUI 메인 (설치·제거 루프)
├── ports/
│   └── pkg_manager.sh          ← 패키지 관리 계약 (인터페이스)
├── adapters/
│   └── output/
│       ├── pkg_termux.sh       ← Termux pkg 어댑터
│       ├── pkg_ubuntu.sh       ← Ubuntu apt 어댑터
│       └── pkg_arch.sh         ← Arch pacman 어댑터
├── domain/
│   ├── apps.sh                 ← 앱 레지스트리 + install/remove 디스패처
│   ├── desktop.sh              ← .desktop 파일 생성 헬퍼
│   └── installers/
│       ├── vscode.sh
│       ├── libreoffice.sh
│       ├── thunderbird.sh
│       ├── vlc.sh
│       ├── nautilus.sh
│       ├── notion.sh
│       ├── wine.sh
│       ├── miniforge.sh
│       ├── dbeaver.sh
│       ├── thorium.sh
│       ├── tor_browser.sh
│       ├── sasm.sh
│       ├── burpsuite.sh
│       └── 1password.sh
└── tests/
```

### 브랜치 전략

| 브랜치 | 용도 |
|--------|------|
| `main` | 안정 버전 — 실기기 테스트 완료 |
| `dev` | 개발 중 — 기능 추가·버그 수정 후 main에 머지 |

---

## English

A **GUI tool for installing and removing extra apps** in the [Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) environment.  
Select an app from the zenity dialog and it installs automatically into proot (Ubuntu/Arch) or Termux native.

**Tested devices**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

### Usage

```bash
# From Termux terminal after Termux_XFCE is installed
app-installer

# From XFCE desktop
# Application menu → App Installer
```

### Supported Apps

| App | Description | Install target |
|-----|-------------|----------------|
| **VS Code** | Visual Studio Code (arm64 deb) | proot |
| **LibreOffice** | Office suite | proot |
| **Thunderbird** | Email client | Termux native |
| **VLC** | Multimedia player | proot |
| **Nautilus** | GNOME file manager | proot |
| **Notion** | Notes & productivity | proot |
| **Wine** | Run Windows apps (Box64 + Wine-Staging) | proot / native |
| **Miniforge** | Conda package manager | proot |
| **DBeaver** | Universal database client | proot |
| **Thorium** | High-performance Chromium-based browser | proot |
| **Tor Browser** | Anonymous browser | proot |
| **SASM** | Assembly IDE | proot |
| **Burp Suite** | Web security testing tool | proot |
| **1Password** | Password manager | proot |

### Wine (Box64 + Wine-Staging)

Automatically branches based on whether proot is installed.

| Environment | Setup |
|-------------|-------|
| proot Ubuntu/Arch | Box64 (ARM64) + Wine-Staging x86_64 tarball inside proot |
| no proot | glibc-runner + box64-glibc + Wine-Staging tarball |

```bash
wine kakao.exe          # Run Windows app
wine winecfg            # Wine configuration
winetricks vcrun2019    # Install DLL / runtime
winetricks dotnet48
```

> **Limitations**: Anti-cheat games, kernel-driver-dependent apps, and complex modern .NET apps will not work.

### How It Works

Reads `PROOT_DISTRO` and `PROOT_USER` from `~/.config/termux-xfce/config`.  
This file is created automatically by the Termux_XFCE installer.

```
PROOT_DISTRO=ubuntu
PROOT_USER=yanghoeg
```

Falls back to `ubuntu` if the config file is missing.

proot apps are launched as:

```bash
proot-distro login <distro> --user <user> --shared-tmp -- env DISPLAY=:1.0 <command>
```

After installation, a `.desktop` file is written to `$PREFIX/share/applications/` so the app appears in the XFCE menu automatically.

### File Structure

```
app-installer/
├── install.sh                  ← zenity GUI main (install/remove loop)
├── ports/
│   └── pkg_manager.sh          ← package manager contract (interface)
├── adapters/
│   └── output/
│       ├── pkg_termux.sh       ← Termux pkg adapter
│       ├── pkg_ubuntu.sh       ← Ubuntu apt adapter
│       └── pkg_arch.sh         ← Arch pacman adapter
├── domain/
│   ├── apps.sh                 ← app registry + install/remove dispatcher
│   ├── desktop.sh              ← .desktop file creation helper
│   └── installers/             ← one file per app
└── tests/
```

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable — real-device tested |
| `dev` | Development — merged to main after tests pass |

---

## Related

- [yanghoeg/Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) — main installer (includes this repo as a Git Submodule)
