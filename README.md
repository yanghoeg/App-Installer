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

| App | Description | Install target | Notes |
|-----|-------------|----------------|-------|
| **VS Code** | Visual Studio Code | proot | `--disable-gpu` applied |
| **LibreOffice** | Office suite | proot | bwrap stub installed |
| **Thunderbird** | Email client | Termux native | |
| **VLC** | Multimedia player | Termux native | |
| **Nautilus** | GNOME file manager | proot | software renderer (MIT-SHM workaround) |
| **Notion** | Notes & productivity | proot | AppImage extracted |
| **Teams** | Microsoft Teams for Linux | proot | community Electron client |
| **Wine (Box64+Staging)** | Run Windows apps via Box64 | proot / native | ELF→box64 wrapper (no binfmt_misc) |
| **Wine (Hangover)** | Run Windows apps via FEX/ARM64EC | Termux native | faster; separate WINEPREFIX |
| **Miniforge** | Conda package manager | proot | CLI only |
| **DBeaver** | Universal database client | proot | |
| **Thorium** | Chromium-based browser | proot | .deb extraction (AUR x86-only) |
| **Tor Browser** | Anonymous browser | proot | arm64 port |
| **SASM** | Assembly IDE | proot | Arch: built from source (fasm x86-only) |
| **Burp Suite** | Web security testing tool | proot | arm64 installer |
| **1Password** | Password manager CLI (`op`) | proot | GUI not available for arm64 |
| **llama.cpp** | GGUF inference (`llama-gpu` / `llama-cli` / `llama-server`) | Termux native | `llama-gpu` = native OpenCL GPU accel (default ctx 4096, `LLAMA_CTX` to override); `llama-model-get` fetches Qwen2.5/Qwen3.5 GGUF (`3.5-2b` Q5, `3.5-4b` Q4) |
| **aichat** | Terminal AI assistant CLI | Termux native | local (`llama-server`) / cloud API |
| **Crush** | Terminal AI coding agent | Termux native | needs provider API key |
| **Codex CLI** | OpenAI coding agent CLI | Termux native | needs `OPENAI_API_KEY` |
| **code-server** | VS Code in the browser | Termux native | serve on 127.0.0.1:8080 |
| **PyTorch + ONNX Runtime** | On-device ML runtimes | Termux native | ~280 MB |
| **AI upscale (ncnn)** | Real-ESRGAN + RIFE | Termux native | Vulkan accelerated |
| **Jujutsu** | Git-compatible VCS + `lazyjj` | Termux native | |
| **television** | Fuzzy finder (`tv`) | Termux native | |
| **superfile** | Modern TUI file manager (`spf`) | Termux native | |
| **uutils-coreutils** | Rust rewrite of coreutils | Termux native | installed alongside GNU coreutils |
| **wayvnc** | VNC server for the desktop | Termux native | wayland sessions only (`wayvnc-start`) |
| **Neovim / Helix** | Terminal modal editors | Termux native | |
| **Dev CLI** | just, mise, hyperfine, tokei, direnv, watchexec | Termux native | mise·direnv need manual shell hook |

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
| 1Password GUI not available for arm64 | install `1password-cli` (`op`) instead |

## Wine — two backends

Two backends can be installed side by side. `wine` on your PATH is a dispatcher that
forwards to the active one.

| Backend | Setup | WINEPREFIX | Wrapper |
|---------|-------|------------|---------|
| `box64` (proot) | Box64 (ARM64) + Wine-Staging x86_64 tarball inside proot | `$HOME/.wine` | `wine-box64` |
| `box64` (no proot) | glibc-runner + box64-glibc + Wine-Staging tarball | `$HOME/.wine` | `wine-box64` |
| `hangover` | `hangover` package (Wine native arm64, apps via FEX/ARM64EC) | `$HOME/.wine-hangover` | `wine-hangover` |

```bash
wine-backend            # show active backend + install status
wine-backend hangover   # switch backends
wine kakao.exe          # Run Windows app through the active backend
wine winecfg            # Wine configuration
winetricks vcrun2019    # Install DLL / runtime (box64 backend, inside proot)
winetricks dotnet48
```

> The prefixes are separate on purpose — the two Wine builds (wow64 staging vs ARM64EC)
> would fight over a shared prefix. Reinstall Wine apps after switching backends.

> **Limitations**: Anti-cheat games, kernel-driver-dependent apps, and complex modern .NET apps will not work.

## How It Works

Reads `PROOT_DISTRO` and `PROOT_USER` from `~/.config/termux-xfce/config`.  
This file is created automatically by the Termux_XFCE installer.

```
PROOT_DISTRO=ubuntu
PROOT_USER=yanghoeg
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
├── install.sh                  ← zenity GUI main (install/remove loop)
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
