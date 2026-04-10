# App-Installer

[Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) 환경에서 동작하는 앱 추가 설치/제거 GUI 도구입니다.  
zenity 다이얼로그로 앱을 선택하면 proot(Ubuntu/Arch) 또는 Termux native에 자동으로 설치합니다.

**테스트 기기**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

---

## 사용법

```bash
# Termux_XFCE 설치 후 XFCE 메뉴 또는 터미널에서
app-installer

# 직접 실행
bash ~/app-installer/install.sh
```

XFCE 데스크탑에서 애플리케이션 메뉴 → App Installer 로 실행할 수 있습니다.

---

## 지원 앱 목록

| 앱 | 설명 | 설치 위치 |
|----|------|-----------|
| **VS Code** | Microsoft Visual Studio Code (arm64 deb) | proot |
| **LibreOffice** | 오피스 스위트 | proot |
| **Thunderbird** | 이메일 클라이언트 | Termux native |
| **VLC** | 멀티미디어 플레이어 | proot |
| **Nautilus** | GNOME 파일 관리자 | proot |
| **Notion** | 메모·생산성 앱 | proot |
| **Wine** | Windows 앱 실행 (Box64 + Wine-Staging) | proot / native |
| **Miniforge** | Conda 패키지 관리자 (miniforge3) | proot |
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
# Windows 앱 실행
wine kakao.exe
wine hancom.exe

# Wine 설정
wine winecfg

# DLL/런타임 설치
winetricks vcrun2019
winetricks dotnet48
```

> **한계**: 안티치트 게임, 커널 드라이버 의존 앱, 최신 .NET 복잡 앱은 동작하지 않습니다.

---

## 동작 방식

`~/.config/termux-xfce/config`에서 `PROOT_DISTRO`, `PROOT_USER`를 읽어 동작합니다.  
Termux_XFCE 설치 시 자동 생성됩니다.

```
PROOT_DISTRO=ubuntu
PROOT_USER=yanghoeg
```

config가 없으면 `ubuntu`를 기본값으로 사용합니다.

### proot 앱 실행 방식

```bash
proot-distro login <distro> --user <user> --shared-tmp -- env DISPLAY=:1.0 <command>
```

설치 후 `.desktop` 파일이 `$PREFIX/share/applications/`에 생성되어 XFCE 메뉴에 자동 등록됩니다.

---

## 파일 구조

```
app-installer/
├── install.sh              ← zenity GUI 메인 (설치·제거 루프)
├── install_vscode.sh       ← VS Code (Microsoft arm64 deb)
├── install_libreoffice.sh  ← LibreOffice
├── install_thunderbird.sh  ← Thunderbird (Termux native)
├── install_vlc.sh          ← VLC
├── install_nautilus.sh     ← Nautilus
├── install_notion.sh       ← Notion
├── install_wine.sh         ← Wine (Box64 + Wine-Staging, proot/native 분기)
├── install_miniforge.sh    ← Miniforge3
├── install_dbeaver.sh      ← DBeaver
├── install_thorium.sh      ← Thorium Browser
├── install_tor_browser.sh  ← Tor Browser
├── install_sasm.sh         ← SASM 어셈블리 IDE
├── install_burpsuite.sh    ← Burp Suite
└── install_1password.sh    ← 1Password (--install / --uninstall)
```

---

## 브랜치 전략

| 브랜치 | 용도 |
|--------|------|
| `main` | 안정 버전 — 실기기 테스트 완료 |
| `dev` | 개발 중 — 기능 추가·버그 수정 후 main에 머지 |

---

## 연관 프로젝트

- [yanghoeg/Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) — 메인 설치 스크립트 (이 저장소를 Git Submodule로 포함)
