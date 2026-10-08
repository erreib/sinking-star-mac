# Order of the Sinking Star on Apple Silicon Macs

An unofficial installer that builds a Mac app for playing the Windows version of
[Order of the Sinking Star](https://store.steampowered.com/app/499170/) on Apple Silicon.
It wraps the Windows Steam client in Wine and translates the game's DirectX 12 to Metal
with Apple's D3DMetal.

Nothing here contains the game or Steam. The installer downloads the wrapper pieces from
their original projects, and Steam installs the game under your own account, so you need
to own it on Steam.

Not affiliated with Thekla, Valve or Apple. Order of the Sinking Star is a trademark of
Thekla, Inc.; Steam is a trademark of Valve Corporation.

## Requirements

- Apple Silicon Mac (M1 or later). Tested on an M4 Pro.
- macOS 15 Sequoia or later.
- Rosetta 2 (`softwareupdate --install-rosetta --agree-to-license`).
- About 20 GB free: the game is about 13 GB, Steam about 1.5 GB.

## Install

Either way, the result is `~/Applications/Order of the Sinking Star.app`. It takes a few
minutes, most of it Steam updating itself.

### Installer app

1. Download **Install Order of the Sinking Star.zip** from the Releases page and open it.
2. Open **Install Order of the Sinking Star**. It isn't signed with an Apple Developer ID,
   so macOS blocks it the first time: open **System Settings > Privacy & Security**,
   scroll down and click **Open Anyway** next to the message about the app.
3. Click **Install** and follow along. It offers to install Rosetta 2 if it's missing.

### Terminal

```sh
git clone <this repo> sinking-star-mac
cd sinking-star-mac
./install.sh
```

Options:

- `--dest DIR` builds the app somewhere else.
- `--no-retina` runs Wine at macOS point resolution. It's blurrier but faster, and suits a
  non-Retina main display. By default the installer follows your main display.

## First launch

1. Open **Order of the Sinking Star** from Applications, Spotlight or Launchpad.
2. Sign in to Steam. The window can take up to a minute to appear.
3. Steam offers to install the game (about 11 GB download) and shows the download. The game
   starts when it's done.

After that, opening the app goes straight into the game, and Steam shuts itself down
(after syncing cloud saves) when you quit. Once the game is installed, the app also
switches to the game's own icon.

## Performance

At the Mac's full Retina resolution the game is demanding: an M4 Pro gets about 30 fps at
3024×1890. In **Settings**, the **Resolution: 1440p** option (2304×1440 on a 16:10 screen)
looks almost as sharp and averaged 17-19 ms per frame (about 52-57 fps) on the same
machine with the Balanced graphics mode. **Display Size Halved** is fastest but soft.
Lower graphics modes also help. Slower chips (M1, M2) will need lower settings.

The first minute after launching, or after changing graphics settings, can stutter while
D3DMetal converts shaders to Metal. They're cached after that.

## Extras (from this folder)

- `./launch.sh --hud` launches with Apple's Metal performance HUD (FPS, frame and GPU time).
- `./launch.sh --debug` adds Wine error logging; logs go to `logs/`.

The game writes its own log, including frame-time stats, to
`Order of the Sinking Star.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Order of the Sinking Star/logs/`.

## Troubleshooting

- **The Steam window is black.** A Steam update replaced the webhelper shim while Steam
  was running. Quit and reopen the app; it re-applies the shim on every launch.
- **Steam or the menu-bar icon stays after you quit the game.** The app normally closes
  everything about 20 seconds after the game exits. What it did is logged in
  `~/Library/Logs/Order of the Sinking Star - session.log`.
- **The installer refuses to start because a Wine server is running.** Quit CrossOver,
  Whisky, other Wine wrappers or a running copy of this app. Sikarugir's setup waits
  until no Wine session is running anywhere.
- **The installer failed.** Details are in `~/Library/Logs/sinking-star-mac-install.log`.
  The partial app is removed automatically, so you can just run it again.
- **Start over.** Delete the app. Your saves are in Steam Cloud.

## How it works

- **Wrapper:** a [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) app bundle
  (Template 1.0.21) with Sikarugir's Wine 11 engine (`WS12WineSikarugir11.0_1`). Wine 11
  is needed because the current Steam client won't start on the Wine 7.7 that Apple's
  Game Porting Toolkit and Whisky are based on.
- **DirectX 12:** Apple's D3DMetal 4.0 beta 2, as shipped in the Sikarugir template and
  enabled in the wrapper. It reports feature level 12_2 and Shader Model 6.6 to the game
  (the game needs 12_0 and 6.5).
- **Steam's black window:** under Wine, Steam's browser (CEF) can only paint its windows
  when it runs as a single process, and Steam ignores its own `-cef-single-process`
  option. `shim/steamwebhelper-shim.c` stands in for `steamwebhelper.exe` and re-launches
  Valve's binary with `--disable-gpu --single-process`.
- **Sharpness:** on a Retina main display, Wine's Mac driver runs in Retina mode with 200%
  Windows scaling, so the game sees the panel's real resolution.
- **Steam overlay:** disabled, since it commonly hangs DirectX startup under Wine.
- **Steam session:** Steam runs with `-silent`, so its main window and Special Offers popup
  stay hidden, and it holds the app's launch request until you've signed in (without it,
  Steam acts on the request before sign-in and drops it). `bundle/Scripts/steam-session.sh`
  shows Steam's Downloads page while the game downloads or updates, starts the game after
  the first download, and shuts Steam down once the game exits. Steam's client crashes on
  its way out under Wine and leaves its crash reporter and service running, so the script
  then ends the app's Wine session.
- **Icon:** the installer can't ship the game's artwork, so once Steam has installed the
  game, `bundle/Scripts/make-icon.sh` pulls the icon out of `sinking_star.exe` (Perl),
  draws it on a macOS-style rounded tile (JavaScript for Automation) and packs it with
  `iconutil`. All three ship with macOS.

- **Downloads:** the Sikarugir template and engine are pinned to exact versions and checked
  against SHA-256 hashes; `SteamSetup.exe` comes from Valve's CDN. The installer clears
  macOS's quarantine flag on the app it builds, so macOS doesn't ask about each Wine
  component the first time it runs.

`bundle/` is copied into the app; `bundle/steamwebhelper-shim.exe` is built from `shim/`
with mingw-w64 (the command is at the top of the source file). The installer app is an
AppleScript applet (`installer/Installer.applescript`) that runs `install.sh` with
`--status-file` and shows its progress; `./make-installer-app.sh` builds it and the
release zip into `dist/`. `tools/d3d12probe.c` is a small diagnostic that prints what the
DirectX 12 stack reports.

## Known limitations

- Tested on one Mac so far (M4 Pro, macOS 15.7, October 2026 game and Steam builds).
- D3DMetal 4.0 is a beta, and the Steam webhelper workaround depends on how Steam's
  client is built. A Steam, game or macOS update can break either.
- The app needs about 20 seconds after you quit the game to close Steam completely.

## Credits and licenses

- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) and its Wine engines, maintained
  by Gcenx and contributors. Wine is LGPL-2.1.
- Apple's D3DMetal is covered by Apple's Game Porting Toolkit license, which allows
  non-commercial distribution. It's included in the Sikarugir template the installer
  downloads; this repo doesn't redistribute it.
- The single-process webhelper approach comes from
  [steam-on-m1-wine](https://github.com/Arime9/steam-on-m1-wine).
- This repo's scripts and shim are MIT licensed (see `LICENSE`). The prebuilt shim includes
  compiler runtime code under its own terms; see `THIRD-PARTY-NOTICES.md`.
