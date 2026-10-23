# App Installer

<div align="center">

**[English](README.md)** &nbsp;|&nbsp; [한국어](README.ko.md)

[![Android](https://img.shields.io/badge/Android-Termux-3DDC84?logo=android)](https://termux.dev)
[![usix-termux](https://img.shields.io/badge/usix--termux-submodule-blue)](https://github.com/yanghoeg/usix-termux)

</div>

---

A **GUI tool for installing and removing extra apps** in the [usix-termux](https://github.com/yanghoeg/usix-termux) environment.  
Select an app from the yad notebook tabbed GUI (zenity fallback) and it installs automatically into proot (Ubuntu/Arch) or Termux native.

**Tested devices**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

## Usage

```bash
# From Termux terminal after usix-termux is installed
app-installer

# From XFCE desktop
# Desktop icon → App Installer  or  Application menu → App Installer
```

From the **App Installer checkout** (`app-installer/` inside the parent repository):

```bash
bash app-install.sh list
bash app-install.sh list 개발
bash app-install.sh install vlc
bash app-install.sh status vlc
bash app-install.sh remove vlc
```

The category filter uses registry labels such as `개발`, `시스템`, `Termux API`, and
`Wine`. `install` skips entries already reported as installed — unless the app provides an
integrity check (`app_verify_<id>`) and that check fails, in which case the damaged
install is repaired by reinstalling (only Claude Code provides one today). `status` prints the
state; both installed and absent known IDs return success, so its exit code alone
is not an installed-state test. Unknown IDs and failed operations return nonzero.
The CLI has no `upgrade` or `rollback` subcommand.

### Upgrade & rollback

An installed app with an `app_upgrade_<id>` handler offers **Upgrade** alongside
**Remove** in the GUI. The current handlers are:

| App | Upgrade behavior |
|-----|------------------|
| Claude Code | Update to `CLAUDE_CODE_PIN_VERSION`; back up the recorded installed version, download and run `--version`. Abort before replacing the binary if backup fails. On download/smoke failure, attempt to restore that backup |
| Codex CLI | Update to `CODEX_PIN_VERSION`; replace the binary, the `codex-code-mode-host` helper and the wrapper, without Claude Code's backup/smoke/rollback flow |
| Notion | Replace the old AppImage launcher with a Termux Firefox web launcher; keep the old app directory until removal |

Other installed entries offer removal. The Claude Code smoke check does not test
`/login`. A fresh install has no previous-version backup. See the
[Claude Code pin and recovery guide](docs/claude-code-login-regression.md) for manual
rollback and device verification.

## Supported Apps

IDs come from [domain/apps.sh](domain/apps.sh); use them with the CLI. Rows grouping
several IDs still represent separate installable entries. `tor_browser` is retained
only for status/removal and appears in the GUI only when an old installation is
detected; the CLI list still includes it.

| ID | App | Description | Install target | Notes |
|----|-----|-------------|----------------|-------|
| `vscode` | **VS Code** | Visual Studio Code | proot | `--disable-gpu` applied |
| `libreoffice` | **LibreOffice** | Office suite | proot | bwrap stub installed |
| `thunderbird` | **Thunderbird** | Email client | Termux native | |
| `vlc` | **VLC** | Multimedia player | Termux native | |
| `gimp` | **GIMP** | Image editor | Termux native | |
| `inkscape` | **Inkscape** | Vector graphics editor | Termux native | |
| `audacity` | **Audacity** | Audio editor | Termux native | |
| `nautilus` | **Nautilus** | GNOME file manager | proot | software renderer (MIT-SHM workaround) |
| `notion` | **Notion** | Notes & productivity | Termux native | Firefox web launcher |
| `teams` | **Teams** | Microsoft Teams for Linux | proot | community Electron client |
| `wine` | **Wine (Box64+Staging)** | Run Windows apps via Box64 | proot / native | ELF→box64 wrapper (no binfmt_misc) |
| `hangover` | **Wine (Hangover)** | Run Windows apps via FEX/ARM64EC | Termux native | separate WINEPREFIX |
| `notepadpp` | **Notepad++** | Text editor | Wine | |
| `sevenzip` | **7-Zip** | Archive tool | Wine | |
| `sumatrapdf` | **Sumatra PDF** | PDF/EPUB/MOBI viewer | Wine | |
| `winmerge` | **WinMerge** | File/folder diff & merge | Wine | |
| `miniforge` | **Miniforge** | Conda package manager | proot | CLI only |
| `dbeaver` | **DBeaver** | Universal database client | proot | arm64 tarball with bundled Java |
| `thorium` | **Thorium** | Chromium-based browser | proot | .deb extraction (AUR x86-only) |
| `tor_browser` | **Tor Browser** | Remove an existing old ARM64 port | proot | New installs disabled by this installer |
| `sasm` | **SASM** | Assembly IDE | proot | Arch: built from source (fasm x86-only) |
| `burpsuite` | **Burp Suite** | Web security testing tool | proot | arm64 installer |
| `onepassword` | **1Password** | Password manager CLI (`op`) | proot | GUI not available for arm64 |
| `claude_code` | **Claude Code** | AI coding assistant CLI | Termux native | pairs with glibc-runner |
| `llama_cpp` | **llama.cpp** | GGUF inference (`llama-gpu` / `llama-cli` / `llama-server`) | Termux native | `llama-gpu` = native OpenCL GPU accel (default ctx 4096, `LLAMA_CTX` to override); `llama-model-get` fetches Qwen2.5/Qwen3.5 GGUF (`3.5-2b` Q5, `3.5-4b` Q4) |
| `aichat` | **aichat** | Terminal AI assistant CLI | Termux native | local (`llama-server`) / cloud API |
| `crush` | **Crush** | Terminal AI coding agent | Termux native | needs provider API key |
| `codex` | **Codex CLI** | OpenAI coding agent CLI | Termux native | pinned upstream static musl binary + `codex-code-mode-host` helper + proot network shim (DNS/CA); the wrapper pins embedded mode (`features.daemon_auto_start=false`), so `codex agents` / `/daemon` are unavailable; needs `codex login` or `OPENAI_API_KEY` |
| `code_server` | **code-server** | VS Code in the browser | Termux native | serve on 127.0.0.1:8080 |
| `ml_python` | **PyTorch + ONNX Runtime** | On-device ML runtimes | Termux native | ~280 MB |
| `ncnn_upscale` | **AI upscale (ncnn)** | Real-ESRGAN + RIFE | Termux native | Vulkan accelerated |
| `jujutsu` | **Jujutsu** | Git-compatible VCS + `lazyjj` | Termux native | |
| `television` | **television** | Fuzzy finder (`tv`) | Termux native | |
| `superfile` | **superfile** | Modern TUI file manager (`spf`) | Termux native | |
| `uutils` | **uutils-coreutils** | Rust rewrite of coreutils | Termux native | installed alongside GNU coreutils |
| `wayvnc` | **wayvnc** | VNC server for the desktop | Termux native | wlroots only; Anland/KWin unsupported (`wayvnc-start`) |
| `neovim`, `helix` | **Neovim / Helix** | Terminal modal editors | Termux native | |
| `btop` | **btop** | Visual resource monitor (htop successor) | Termux native | needs root-repo enabled |
| `just`, `mise`, `hyperfine`, `tokei`, `direnv`, `watchexec` | **Dev CLI** | just, mise, hyperfine, tokei, direnv, watchexec | Termux native | mise·direnv need manual shell hook |

## System Apps (시스템 tab)

| ID | App | Description | Install target | Notes |
|----|-----|-------------|----------------|-------|
| `gpu_native` | **GPU Native Acceleration** | Adreno Vulkan + Zink OpenGL | Termux native | X11 launcher selects acceleration or software fallback |
| `gpu_dev` | **GPU Dev Tools** | clvk, clinfo, etc. | Termux native | |
| `gpu_proot` | **GPU Acceleration (proot)** | Container Turnip + Zink | proot | Adds the pinned Termux glibc KGSL Turnip; activates only after the driver probe passes. On Ubuntu 24.04/25.10/26.04, OpenGL uses a pinned lfdevs Freedreno KGSL build in `/opt/termux-xfce-mesa` once an EGL check passes |
| `chroot_ng` | **proot Accelerated Runtime (chroot-ng)** | ptrace-free `prun` engine (experimental) | Termux native (source build) | Pinned-commit build; installs only after the device probe and a rootfs run pass. Used only with `PRUN_RUNTIME=chroot-ng` |
| `korean_input` | **Korean Input (fcitx5)** | fcitx5-hangul Korean input | Termux native | selects fcitx5 for X11; restart XFCE |
| `korean_proot` | **Korean Input (proot)** | Korean locale + nimf/fcitx5 IME inside the proot distro | proot | Ubuntu = nimf .deb, Arch = nimf AUR → fcitx5 fallback |
| `korean_locale` | **Korean Locale** | force_gettext.so-based UI localization | Termux native | requires the parent usix-termux checkout and a catalog ZIP |
| `nimf` | **Korean Input (nimf)** | nimf Korean input | Termux native | community build |

## Termux API Apps (Termux API tab)

| ID | App | Description | Install target | Notes |
|----|-----|-------------|----------------|-------|
| `api_brightness` | **Brightness Control** | Screen brightness script for the XFCE panel | Termux native | |
| `api_volume` | **Volume Control** | Volume control script for the XFCE panel | Termux native | |
| `api_conky_battery` | **Panel Battery** | Battery level/temperature in XFCE genmon | Termux native | add Generic Monitor manually with `~/.local/bin/battery-genmon`; `battery-info` opens a popup |
| `api_notification` | **Notification Tool** | Send Android notifications from scripts | Termux native | |
| `api_tts` | **TTS Voice** | Text-to-speech (Android TTS) | Termux native | |
| `api_stt` | **Speech Recognition** | Speech-to-text (Android STT) | Termux native | |
| `api_wallpaper` | **Wallpaper Sync** | Sync XFCE wallpaper to Android | Termux native | |

Termux API apps require the `termux-api` package and the Termux:API APK.

## arm64 Compatibility Notes

The installers implement the following workarounds. Prior device checks used
Ubuntu 25.10 / Arch Linux ARM; they do not establish that every current app/version
works. Use the [device checklist](TEST_LOG.md) when validating a new setup.

| Issue | Workaround |
|-------|-----------|
| GTK4 apps crash (glycin/bwrap) | `proot_setup_bwrap`: installs a bwrap compatibility wrapper that runs the command without namespace isolation |
| `sudo` resets PATH (sudo-rs) | `proot_setup_sudo_path`: symlinks Termux tools to `/usr/local/bin` |
| Nautilus MIT-SHM BadAccess | `GSK_RENDERER=cairo GDK_RENDERING=image` forces software renderer |
| VS Code GPU process crash | `--disable-gpu` + `dbus-run-session` |
| Wine x86-64 ELF not auto-run (no binfmt_misc) | move ELF files into `bin/.elf/`, then create `box64` wrappers |
| Thorium AUR is x86-only | extract arm64 .deb directly with `ar` |
| SASM `fasm` dep is x86-only (Arch) | build SASM from source with `qmake` + `nasm` |
| 1Password GUI not available for arm64 | install `1password-cli` (`op`) instead |
| A user's Bash login setup bypasses `~/.profile` | `korean_proot` writes `/etc/profile.d/termux-xfce-locale.sh`; `prun` command launches use Bash login shells |

Proot desktop launchers use the shared `prun-gui` helper and inherit the active
display. CLI-only tools do not necessarily create menu entries.

## Wine — two backends

Two backends can be installed side by side. `wine` on your PATH is a dispatcher that
forwards to the active one.

| Backend | Setup | WINEPREFIX | Wrapper |
|---------|-------|------------|---------|
| `box64` (proot) | Box64 source build at a pinned commit + Wine-Staging x86_64 tarball | Proot user’s `$HOME/.wine` | `wine-box64` |
| `box64` (no proot) | glibc-runner + box64-glibc + Wine-Staging tarball | Termux `$HOME/.wine` | `wine-box64` |
| `hangover` | `hangover` package (Wine native arm64, apps via FEX/ARM64EC) | `$HOME/.wine-hangover` | `wine-hangover` |

```bash
wine-backend            # show active backend + install status
wine-backend hangover   # switch to an installed backend
wine kakao.exe          # Run Windows app through the active backend
wine winecfg            # Wine configuration

# With the box64 backend installed in the configured proot distro
wine-backend box64
prun winetricks vcrun2019
prun winetricks dotnet48
```

The prefixes are separate, and switching backends does not migrate Windows apps.
Their shared `.desktop` files can still make an app appear installed after a switch;
the CLI will then skip `install`. To migrate an app through this installer, remove
it while its original backend is active, switch backends, then install it again.
To retain copies in both prefixes, install the second copy with that backend's Wine
command and the application's own installer. The GUI has no dedicated
reinstall command. Removal affects the currently active backend's prefix.

Performance and compatibility depend on the device and app. Kernel-driver and
anti-cheat requirements are common blockers; installing a runtime with winetricks
is not a guarantee that an application will work.

## How It Works

Explicit `PROOT_DISTRO` and `PROOT_USER` environment variables take priority over
`~/.config/termux-xfce/config` in both the CLI and GUI. Unset values come from the config.
This file is created automatically by the usix-termux installer.

```
PROOT_DISTRO=ubuntu
PROOT_USER=desktop
```

Falls back to `ubuntu` if no distro is specified. `PROOT_DISTRO=""` selects native-only
mode. When overriding only the distro, its user is detected instead of reusing a
saved user from another distro.

Proot GUI launchers use `prun-gui`, which shows a loading notification and forwards
the command to the parent installer's `prun`. Commands run through a Bash login shell
with `LD_PRELOAD` cleared inside the container. `DISPLAY` is inherited, including
KWin's dynamically assigned Xwayland display; outside a graphical session the
parent wrapper defaults to `:0.0`.

```bash
prun libreoffice
prun                  # interactive shell selected by PROOT_SHELL
ubuntu                # Ubuntu shell, if that distro was installed
ubuntu uname -m        # single command in Ubuntu
```

GUI entries are installed under `$PREFIX/share/applications/` and may also be copied
to `~/Desktop`; CLI-only installers need not create `.desktop` files. Rootfs helpers
recognize both `containers/<distro>/rootfs` and legacy `installed-rootfs/<distro>`
beneath `$PREFIX/var/lib/proot-distro`.

### Korean input and localization

Native `korean_input` (fcitx5) and `nimf` use
`~/.config/termux-xfce/input-method` (`none`, `nimf`, or `fcitx5`). Their shared
`$PREFIX/etc/profile.d/termux-xfce-input.sh` applies the selection to X11, and only
the selected native IME is enabled for autostart. Installing another IME switches
the selection; removing the selected IME resets it to `none`. Restart XFCE to apply.
The Wayland path clears X11 IME module variables and excludes these autostart entries
from KDE, leaving Android keyboard input to Anland.

`korean_locale` is separate from input. It requires the parent usix-termux checkout
and a ZIP containing `ko/LC_MESSAGES/*.mo`. The GUI prompts for the file; the CLI uses:

```bash
KOREAN_LOCALE_ZIP=/path/to/locale.zip bash app-install.sh install korean_locale
```

Missing catalogs or compilation failures return an error. The locale hook is loaded
only while `$PREFIX/lib/force_gettext.so` exists; native IME selection is independent.

`korean_proot` installs the container locale and IME (Ubuntu: pinned nimf packages;
Arch: nimf from AUR, with fcitx5 fallback). It writes
`/etc/profile.d/termux-xfce-locale.sh` inside proot and removes the older managed
`.profile` block. This configures container apps separately from the native selector.

## File Structure

```
app-installer/
├── install.sh                  ← yad notebook GUI (zenity fallback; install/remove/upgrade)
├── app-install.sh              ← headless list/install/remove/status CLI
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
├── lib/
│   ├── fetch.sh                ← fetch_verified — download + sha256 verification (snippet-injectable)
│   ├── input_method.sh         ← shared native IME selection and autostart
│   ├── build_box64.sh          ← pinned Box64 source-build helper
│   ├── build_sasm.sh           ← pinned SASM source-build helper
│   └── common.sh, proot_path.sh, wine_backend.sh
├── docs/
│   └── claude-code-login-regression.md ← Claude Code pin, rollback and login validation
└── tests/                      ← framework.sh, mocks.sh, test_{domain_apps,adapters,ports,fetch,proot_path,cli}.sh
                                   (test_nimf_*_real.sh: real device only)
```

## Download Integrity

Direct release payloads such as Wine tarballs and pinned `.deb` files declare their
versions and SHA-256 values in the installer. [lib/fetch.sh](lib/fetch.sh) provides
`fetch_verified`: failed/empty downloads and hash mismatches delete the destination
and return nonzero. **An empty hash only emits a warning and skips verification**;
the helper does not enforce a hash for every caller.

Repository packages use their package manager's verification. Source builds have
separate rules: Box64 and SASM check pinned Git commits, while AUR recipes are not
pinned by this project's SHA-256 table. User-selected llama.cpp
models are downloaded separately without that table. Clearing
`CLAUDE_CODE_PIN_VERSION` enables npm `latest` lookup; its default is pinned.

When changing a directly downloaded version, verify its source and update the URL,
version and hash together. Changing only a version to one absent from its hash map
can silently reduce verification to a warning. The parent installer has separate
APK/asset download paths; this helper's guarantees do not cover every parent download.

## Tests

From the App Installer checkout:

```bash
for suite in domain_apps adapters ports fetch proot_path cli \
    review_claude_code review_input_gpu review_removal_wine review_app_core; do
    bash "tests/test_${suite}.sh" || exit 1
done
```

These suites cover the domain, adapters, ports, downloads, rootfs paths, CLI,
Wine execution, input method dependencies, removal, and upgrade failure handling.
On a PC they use mocks and static checks; CLI tests run the real entry point with
isolated package/download commands. Parent locale integration tests require the
usix-termux checkout. `tests/test_nimf_*_real.sh` are run from Termux on a real device and enter proot
themselves; they install packages. Keep them outside host test loops. The parent
`modern_install` suite also covers shared IME/GPU/launcher behavior. Use
[TEST_LOG.md](TEST_LOG.md) as the device checklist, not as proof of a passing run.

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | End-user integration branch |
| `dev` | Development and validation before promotion to `main` |

---

## Related

- [yanghoeg/usix-termux](https://github.com/yanghoeg/usix-termux) — main installer (includes this repo as a Git Submodule)
