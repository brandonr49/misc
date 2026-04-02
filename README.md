# Workstation Setup

Automated setup scripts for fresh macOS and Linux installations. Installs
applications, configures terminal environment, sets system preferences, and
gets a new machine to a usable dev state with a single command.

## macOS — Fresh install procedure

1. **Set up your user** — walk through the macOS setup assistant, create your account
2. **Sign into your Apple ID** — required for App Store installs (Xcode, MX Player)
3. **Open the App Store** — confirm you're signed in
4. **Update macOS** — System Settings > General > Software Update, install and reboot
5. **Open Terminal** (Cmd+Space → "Terminal") and clone the repo:
   ```bash
   git clone https://github.com/brandonr49/misc.git
   ```
   This triggers the Xcode Command Line Tools install dialog — click **Install**,
   wait for it to finish, then re-run the clone command.
6. **Run the script:**
   ```bash
   cd misc/
   bash setup_mac_terminal.sh                          # basic run
   bash setup_mac_terminal.sh --hostname my-macbook    # also set hostname
   bash setup_mac_terminal.sh --backup                 # back up existing dotfiles first
   bash setup_mac_terminal.sh -h                       # show help
   ```

> **Do NOT run with `sudo`.** The script sets up passwordless sudo on first run
> and handles elevation internally.

After the script finishes, **reboot** for all preferences to take effect.
See the full manual steps checklist printed at the end of the script.

### Linux (Fedora)

```bash
git clone https://github.com/brandonr49/misc.git
cd misc/
bash setup_linux.sh
```

## Repository layout

```
misc/
├── README.md
├── setup_mac_terminal.sh     # macOS setup (Homebrew, casks, defaults, dotfiles)
├── setup_linux.sh            # Linux setup (dnf/apt, dotfiles)
├── config/
│   ├── firefox_policies.json # Firefox extension auto-install policy
│   └── btt_preset.bttpreset  # BetterTouchTool preset (mouse buttons, gestures)
└── scripts/
    └── subtitle.sh           # Generate .srt subtitles from video files (whisper-cpp)
```

## What the macOS script does

The script runs in this order. Terminal environment is set up first so a Ctrl-C
during app installs still leaves you with a working shell:

| # | Section | What it does |
|---|---------|-------------|
| 1 | Hostname | Sets HostName, LocalHostName, ComputerName (optional) |
| 2 | Xcode CLT | Installs Command Line Tools if missing |
| 3 | Homebrew | Installs + full update + stale download cleanup |
| 4 | CLI tools | git, vim, tree, node, python, ffmpeg, whisper-cpp, bitwarden-cli, dockutil, mas, mysides |
| 5 | Claude Code | Installed via `npm install -g @anthropic-ai/claude-code` |
| 6 | Dotfiles | Backs up existing, writes .zshrc, .zsh_alias, .zsh_ps1, .vimrc, .gitconfig |
| 7 | Zsh | vi-mode, 10M line history, autosuggestions, syntax highlighting, bell disabled |
| 8 | Vim | gruvbox, NERDTree, CtrlP, SuperTab, mouse/trackpad scroll, bell disabled |
| 9 | Git | colored diffs, diff-highlight, aliases, osxkeychain credential helper |
| 10 | Python venv | Creates `/opt/brobpy/` venv, activated by default in .zshrc |
| 11 | macOS prefs | ~60 `defaults write` commands (see below) |
| 12 | Remove bloat | GarageBand, iMovie, Keynote, Pages, Numbers |
| 13 | GUI apps | ~33 apps via `brew install --cask` |
| 14 | Browser ext | Firefox: policies.json. Chrome: managed prefs. Firefox set as default |
| 15 | Auto-launch | Kills Microsoft Auto-Update, disables auto-start for Spotify/Docker/Slack/Discord/Steam |
| 16 | Dock layout | Clears dock, pins all major visual apps |
| 17 | Xcode IDE | Via Mac App Store (`mas install`) |
| 18 | BTT preset | Imports config/btt_preset.bttpreset (mouse buttons, gestures) |
| 19 | Whisper + subtitle | Downloads large-v3-turbo model, installs `subtitle` command |
| 20 | App Store | MX Player |
| 21 | AirCaption | Opens download page (no brew cask) |
| 22 | Background | Solid black desktop + black iTerm2 background |

## GUI apps installed

| Category | Apps |
|---|---|
| Browsers | Chrome, Firefox |
| Communication | Discord, Slack, Zulip |
| Development | Android Studio, VS Code, Docker, iTerm2, Fork, GitUp, GitHub Desktop |
| AI / LLM | Claude Desktop, Ollama |
| Media | Jellyfin, Grayjay, Spotify, VLC, MX Player |
| Networking | Tailscale, OpenVPN Connect, Microsoft Remote Desktop |
| Utilities | BetterTouchTool, Raycast, Karabiner-Elements, KeepingYouAwake, AppCleaner, The Unarchiver, GrandPerspective, Stats, Bitwarden, ForkLift, Cyberduck, Radio Silence, Maccy |
| Gaming | Steam |
| Virtualization | UTM |

## macOS preferences

**Animations**: all disabled — window open/close, Dock, Finder, Mission Control, Quick Look, rubber-band scroll, minimize uses scale effect.

**Window tiling**: margins between tiled windows removed.

**Finder**: list view, show hidden files + extensions, path bar, status bar, POSIX path in title, search current folder, no .DS_Store on network/USB, no warnings on extension change or empty trash. Sidebar: Recents/Tags/iCloud Drive removed, home directory added.

**Keyboard**: fast repeat (KeyRepeat=2, InitialKeyRepeat=15), no autocorrect, no smart quotes/dashes/capitalization/period, full keyboard access.

**Trackpad**: tap to click, increased tracking speed.

**Dock**: auto-hide, 48px icons, no recents, minimize to app icon.

**Screenshots**: saved to ~/Screenshots, PNG format, no shadow.

**Dialogs**: save and print dialogs expanded by default.

**Menu bar**: 24-hour clock, battery percentage.

**Sound**: system UI sounds disabled, beep volume 0, iTerm2 bell silenced.

**Security**: password required immediately after sleep.

**Misc**: no gatekeeper "are you sure" dialog, save to disk by default (not iCloud), press-and-hold disabled (key repeat), Quick Look text selection.

**iCloud Drive**: disabled (Desktop & Documents sync off).

## Browser extensions

Installed automatically on first launch:

**Firefox** (via `config/firefox_policies.json`):
- uBlock Origin (full — Firefox still supports MV2)
- Bitwarden
- OneTab

**Chrome** (via managed preferences — may require MDM on newer macOS):
- uBlock Origin Lite (MV3)
- Bitwarden
- OneTab
- Claude

> Claude's browser extension is Chrome-only. No Firefox version exists.

## Window management / Spaces

The script does **not** install a tiling window manager by default — try these
and uncomment your choice in the cask list:

- **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** — i3-like, no SIP disable needed, TOML config, emulates its own workspaces. `brew install --cask nikitabobko/tap/aerospace`
- **[yabai](https://github.com/koekeishiya/yabai) + [skhd](https://github.com/koekeishiya/skhd)** — more mature, some features need SIP disabled. `brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd`
- **BetterTouchTool** (already installed) has built-in window snapping
- **macOS native tiling** (Sequoia+) is configured by the preferences section (margins disabled)

## Python environment

A venv is created at `/opt/brobpy/` and activated by default in `.zshrc`.
Install packages into it normally:

```bash
pip install requests numpy pandas  # etc.
```

The venv persists across terminal sessions. To deactivate temporarily: `deactivate`

## Customization

**Edit before running:**
- `HOSTNAME=""` at top of script, or pass `--hostname` on the command line
- Cask app list — add/remove apps
- Dock app list — change pinned apps and order
- Window manager — uncomment your choice in the cask list
- WiFi off / static IP — uncomment in the preferences section

**After running:**
- Personal shell config goes in `~/.zsh_user_custom` (sourced by .zshrc, not overwritten)
- Dotfile backups saved to `~/dotfiles_backup_<timestamp>/`

## Manual steps after running

1. **Reboot** for all preferences to take effect
2. **Sign into accounts**: Tailscale, Bitwarden, Steam, Discord, Slack, Spotify, Zulip, OpenVPN (import .ovpn profiles)
3. **Grant permissions** (System Settings > Privacy & Security): Accessibility (BetterTouchTool, Karabiner, Raycast), Full Disk Access (iTerm, GrandPerspective)
4. **Git identity**: `git config --global user.name` / `user.email`
5. **Browser extensions**: verify they loaded. If Chrome extensions didn't auto-install, install manually from the Chrome Web Store
6. **iTerm2**: Profiles > Colors > verify dark background (script sets it to black)
7. **Ollama**: `ollama pull llama3` (or whichever models you want)
8. **Android Studio**: complete setup wizard on first launch
9. **AirCaption**: download from https://www.aircaption.com/download
10. **CornerFix** (square window corners): https://github.com/makalin/CornerFix

## Subtitle generation (whisper-cpp)

The script installs `whisper-cpp`, `ffmpeg`, downloads the `large-v3-turbo` whisper model,
and installs a `subtitle` command to `/usr/local/bin/`:

```bash
# Single file
subtitle /path/to/movie.mkv

# All videos in a directory
subtitle /path/to/media/

# Recursive
subtitle /path/to/media/ --recursive
```

Creates `.srt` files next to each video. Jellyfin picks these up automatically as
sidecar subtitles — no configuration needed. Runs locally on Apple Silicon Metal GPU
(~5-10x realtime speed). Skips files that already have subtitles.

Override the model or language with env vars:
```bash
WHISPER_MODEL=~/models/other-model.bin subtitle movie.mkv
WHISPER_LANG=es subtitle movie.mkv    # Spanish
```

## BetterTouchTool preset

The script imports `config/btt_preset.bttpreset` on each run. To set it up:

1. Configure BTT the way you want (mouse buttons, gestures, shortcuts)
2. BTT > Presets > right-click your preset > Export Preset
3. Save as `config/btt_preset.bttpreset` in the repo
4. Commit — next run of the script imports it on any fresh machine

Recommended BTT config: map Logitech mouse button 4/5 to Cmd+[/Cmd+] for
Finder back/forward navigation.

## Reverting changes

| What | How |
|------|-----|
| Passwordless sudo | `sudo rm /etc/sudoers.d/$(whoami)` |
| Dotfiles | Restore from `~/dotfiles_backup_<timestamp>/` |
| Homebrew apps | `brew uninstall --cask <app>` |
| Python venv | `sudo rm -rf /opt/brobpy` |
| Firefox extensions | `sudo rm /Applications/Firefox.app/Contents/Resources/distribution/policies.json` |
| Chrome managed prefs | `sudo rm "/Library/Managed Preferences/com.google.Chrome.plist"` |
| BTT preset | Reset in BTT > Presets, or delete and reimport |
| Whisper model | `rm ~/models/ggml-large-v3-turbo-q8_0.bin` |
| Subtitle command | `sudo rm /usr/local/bin/subtitle` |
| macOS preferences | Most revert on factory reset. Individual: `defaults delete <domain> <key>` |
