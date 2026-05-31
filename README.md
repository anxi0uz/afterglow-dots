# dotfiles-2

Personal CachyOS/driftwm rice for user `anxi0uz`.

This repo is intentionally not generic. It is hardcoded for my setup:

- compositor: `driftwm`
- monitor: `DP-1`
- mode: `1920x1080@180`
- keyboard layouts: `us,ru`
- layout switch: `Alt+Shift`
- terminal: `alacritty`
- launcher/clipboard UI: `fuzzel`
- notifications: `swaync`
- bar/tray: `waybar`
- clipboard history: `cliphist`
- Discord/screen sharing portals: `xdg-desktop-portal-wlr`
- screen recording: `gpu-screen-recorder`

## Contents

```text
config/driftwm/     driftwm config, scripts, widgets, wallpapers
config/waybar/      taskbar and tray configs
config/fuzzel/      default fuzzel config for niri/other sessions
config/driftwm/fuzzel/ driftwm-specific fuzzel config
config/swaync/      notification daemon config
config/alacritty/   default alacritty config for niri/other sessions
config/driftwm/alacritty/ driftwm-specific alacritty config
config/gtk-3.0/     GTK settings restored for the normal desktop look
packages/           dependency package lists
install.sh          copies configs into ~/.config with backup
```

## Install Dependencies

On CachyOS/Arch:

```sh
xargs -a packages/pacman.txt sudo pacman -S --needed
```

AUR / non-repo packages:

```sh
xargs -a packages/aur.txt yay -S --needed
```

If `google-chrome` exists in your CachyOS repos, installing it through `pacman` is fine too.

## Apply Configs

From the repo root:

```sh
./install.sh
```

The installer backs up existing configs to:

```text
~/.config-backups/dotfiles-2-YYYYMMDD-HHMMSS
```

Then it copies:

```text
config/* -> ~/.config/
```

After that, log out and choose the `driftwm` session in the login manager.

## Important Files

```text
~/.config/driftwm/config.toml
~/.config/driftwm/scripts/
~/.config/driftwm/widgets/
~/.config/waybar/
~/.config/fuzzel/
~/.config/swaync/
~/.config/alacritty/
```

## Keybinds

```text
Alt+Shift          switch keyboard layout
Super+Enter        terminal
Super+D            launcher
Super+V            clipboard history
Super+B            Chrome
Super+E            Nautilus
Super+Z            Zed
Super+Shift+T      Telegram
Super+Shift+G      Discord
Super+Q            close window
Super+F            fullscreen
Super+M            fit snapped window
Super+Shift+M      fit window
Super+W            overview / zoom-to-fit all windows
Super+A            home toggle
Super+C            center window
Super+S            search open windows
Super+L            lock
Super+Shift+D      toggle theme
Super+Shift+W      cycle wallpaper
Super+N            swaync notification center
Super+Shift+R      start screen recording
Super+Shift+S      stop screen recording
Super+Ctrl+Shift+Q quit driftwm
Print              screenshot to clipboard
```

Media keys:

```text
Volume Up/Down     wpctl volume
Mute               output mute
Mic Mute           microphone mute
Play/Pause         playerctl play-pause
Next/Previous      playerctl next/previous
Brightness Up/Down brightnessctl
```

## Widgets

Widgets live in:

```text
config/driftwm/widgets/
```

They are launched by:

```text
config/driftwm/widgets/launch.sh
```

Their positions are controlled in `config/driftwm/config.toml` using `[[window_rules]]`, for example:

```toml
[[window_rules]]
app_id = "drift-clock"
position = [-93, 205]
```

## Clipboard

Autostart runs:

```sh
wl-paste --type text --watch cliphist store
wl-paste --type image --watch cliphist store
```

Open clipboard history:

```text
Super+V
```

## Discord Screen Sharing

`Super+Shift+G` launches Discord through:

```text
~/.config/driftwm/scripts/discord-x11.sh
```

That wrapper forces X11/Ozone X11 so Discord hotkeys keep working while the
Discord window is focused.

The `driftwm` portal config uses the wlroots screencast backend:

```text
xdg-desktop-portal-wlr
```

Install `slurp` too; portal/screenshot tools use it for interactive region
selection. After installing portal packages, restart the session or run:

```sh
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-wlr
```

## Screen Recording

Start:

```text
Super+Shift+R
```

Stop:

```text
Super+Shift+S
```

Recordings are saved to:

```text
~/Videos/rec_YYYYMMDD_HHMMSS.mp4
```

The recorder stores a PID file under:

```text
$XDG_RUNTIME_DIR/driftwm/gpu-screen-recorder.pid
```

Log:

```text
/tmp/gpu-screen-recorder.log
```

## Theme Behavior

`theme-watch.sh` syncs the rice with GNOME/CachyOS color-scheme on startup.

If `gsettings` says `prefer-dark`, it applies dark colors and `dark_sea.glsl`.
Otherwise it applies light colors and `pink_cloud.glsl`.

It only changes driftwm, waybar, and driftwm's private alacritty config. The default
`~/.config/alacritty` and `~/.config/fuzzel` are kept for niri/other sessions.

To stop automatic theme switching, remove this autostart line from `config/driftwm/config.toml`:

```toml
"~/.config/driftwm/scripts/theme-watch.sh",
```

## Monitor

The driftwm config currently pins:

```toml
[[outputs]]
name = "DP-1"
mode = "1920x1080@180"
scale = 1.0
```

If the connector changes, check names with:

```sh
wlr-randr
```

Then edit `config/driftwm/config.toml`.

## Validation

Check driftwm config:

```sh
driftwm --check-config
```

Check scripts:

```sh
for f in ~/.config/driftwm/scripts/*.sh; do sh -n "$f" || exit 1; done
```
