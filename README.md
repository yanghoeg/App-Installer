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

### GUI

```bash
# From Termux terminal after Termux_XFCE is installed
app-installer

# From XFCE desktop
# Desktop icon → App Installer  or  Application menu → App Installer
```

### CLI

```bash
bash app-install.sh list              # List all apps with install status
bash app-install.sh list 개발         # Filter by category
bash app-install.sh install claude_code  # Install an app
bash app-install.sh remove vlc          # Remove an app
bash app-install.sh status claude_code   # Check install status
```

## Supported Apps

| App | Description | Install target | Notes |
|-----|-------------|----------------|-------|
| **VS Code** | Visual Studio Code | proot | `--disable-gpu` applied |
| **LibreOffice** | Office suite | proot | bwrap stub installed |
| **Thunderbird** | Email client | Termux native | |
| **VLC** | Multimedia player | Termux native | |
| **Nautilus** | GNOME file manager | proot | software renderer (MIT-SHM workaround) |
| **Notion** | Notes & productivity | proot | AppImage extracted |
| **Teams** | Microsoft Teams for Linux | proot | community Electron client |
| **Wine** | Run Windows apps (Box64 + Wine-Staging) | proot / native | ELF→box64 wrapper (no binfmt_misc) |
| **Miniforge** | Conda package manager | proot | CLI only |
| **DBeaver** | Universal database client | proot | |
| **Thorium** | Chromium-based browser | proot | .deb extraction (AUR x86-only) |
| **Tor Browser** | Anonymous browser | proot | arm64 port |
| **SASM** | Assembly IDE | proot | Arch: built from source (fasm x86-only) |
| **Burp Suite** | Web security testing tool | proot | arm64 installer |
| **Claude Code** | Anthropic AI coding assistant CLI | Termux native | runs native ELF via glibc-runner, bypasses npm + disables self-update |

## arm64 Compatibility Notes

Tested on real devices (Ubuntu 25.10 / Arch Linux ARM) — known workarounds applied automatically:

| Issue | Workaround |
|-------|-----------|
| GTK4 apps crash (glycin/bwrap) | `proot_setup_bwrap`: installs no-op bwrap stub in proot |
| `sudo` resets PATH (sudo-rs) | `proot_setup_sudo_path`: symlinks Termux tools to `/usr/local/bin` |
| Nautilus MIT-SHM BadAccess | `GSK_RENDERER=cairo GDK_RENDERING=image` forces software renderer |
| VS Code GPU process crash | `--disable-gpu` + `dbus-run-session` |
| Wine x86-64 ELF not auto-run (no binfmt_misc) | rename to `.elf`, create `box64` wrapper script |
| Thorium AUR is x86-only | extract arm64 .deb directly with `ar` |
| SASM `fasm` dep is x86-only (Arch) | build SASM from source with `qmake` + `nasm` |
| Claude Code v2.1.114+ native ELF (requires glibc dynamic linker) | bypass npm — fetch tarball directly, run via `grun` wrapper |

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
PROOT_USER=<username>
```

Falls back to `ubuntu` if the config file is missing.

proot apps are launched via `prun`:

```bash
proot-distro login <distro> --user <user> --shared-tmp -- env DISPLAY=:0.0 <command>
```

After installation, a `.desktop` file is written to `$PREFIX/share/applications/` so the app appears in the XFCE menu automatically.

You can also enter the proot shell directly:

```bash
ubuntu          # enter Ubuntu proot interactive shell
ubuntu <cmd>    # run single command in Ubuntu proot
```

## File Structure

```
app-installer/
├── install.sh                  ← GUI main (yad/zenity, install/remove loop)
├── app-install.sh              ← CLI interface (list/install/remove/status)
├── ports/
│   └── pkg_manager.sh          ← package manager contract (interface)
├── adapters/
│   └── output/
│       ├── pkg_proot_base.sh   ← shared proot helpers (bwrap stub, sudo path)
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
