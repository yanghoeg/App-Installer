# App Installer

<div align="center">

**[English](README.md)** &nbsp;|&nbsp; [한국어](README.ko.md)

[![Android](https://img.shields.io/badge/Android-Termux-3DDC84?logo=android)](https://termux.dev)
[![Termux XFCE](https://img.shields.io/badge/Termux__XFCE-submodule-blue)](https://github.com/yanghoeg/Termux_XFCE)

</div>

---

A **GUI tool for installing and removing extra apps** in the [Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) environment.  
Select an app from the zenity dialog and it installs automatically into proot (Ubuntu/Arch) or Termux native.

**Tested devices**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

## Usage

```bash
# From Termux terminal after Termux_XFCE is installed
app-installer

# From XFCE desktop
# Desktop icon → App Installer  or  Application menu → App Installer
```

## Supported Apps

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

## Wine (Box64 + Wine-Staging)

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

## How It Works

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

## File Structure

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

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable — real-device tested |
| `dev` | Development — merged to main after tests pass |

---

## Related

- [yanghoeg/Termux_XFCE](https://github.com/yanghoeg/Termux_XFCE) — main installer (includes this repo as a Git Submodule)
