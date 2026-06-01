# afterglow

Personal CachyOS/driftwm rice. The repository can be named `afterglow-dots`;
inside the docs and installer it is called `afterglow`.

This repo is opinionated and still defaults to my setup:

- compositor: `driftwm`
- monitor: `DP-1`
- mode: `1920x1080@180`
- keyboard layouts: `us,ru`
- layout switch: `Alt+Shift`
- terminal: `alacritty`
- launcher/clipboard UI: `fuzzel`
- notifications: `swaync`
- bars/tray: `waybar` screen-anchored bottom bar
- clipboard history: `cliphist`
- Discord/screen sharing portals: `xdg-desktop-portal-wlr`
- screen recording: `gpu-screen-recorder`

## Screenshots

| Desktop | Notifications |
| --- | --- |
| ![Empty desktop](screens/empty%20desktop.jpg) | ![Desktop with notifications](screens/desktop%2Bnotifs.jpg) |

| Launcher | Window Search |
| --- | --- |
| ![App launcher](screens/app%20launcher.jpg) | ![Windows search](screens/windows%20search%20script.jpg) |

| Wallpaper Picker | Power Menu |
| --- | --- |
| ![Wallpaper picker](screens/wallpapers%20pick%20menu.jpg) | ![Power menu](screens/power%20menu.jpg) |

## Contents

```text
config/driftwm/     driftwm config, scripts, widgets, wallpapers
config/waybar/      bottom bar config and styles
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

On CachyOS/Arch-based:

```sh
xargs -a packages/pacman.txt sudo pacman -S --needed
```

AUR / non-repo packages:

```sh
xargs -a packages/aur.txt yay -S --needed
```

If `google-chrome` exists in your CachyOS repos, installing it through `pacman` is fine too.

The installer can also run both package lists:

```sh
./install.sh --packages-only
```

## Apply Configs

From the repo root:

Check before installing:

```sh
./install.sh --check
```

Preview file changes without writing anything:

```sh
./install.sh --dry-run
```

Install configs:

```sh
./install.sh
```

For a VM, laptop, or a monitor that is not `DP-1`, either pass the output
explicitly:

```sh
./install.sh --output Virtual-1 --mode 1920x1080@60
```

Or try automatic detection from `wlr-randr`:

```sh
./install.sh --detect-output
```

The installer backs up existing configs to:

```text
~/.config-backups/afterglow-YYYYMMDD-HHMMSS
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

`mod` means `Super`.

```text
Alt+Shift            switch keyboard layout

Super+Enter          open Alacritty
Super+D              open app launcher
Super+B              open Chrome
Super+E              open Nautilus
Super+Z              open Zed
Super+V              open clipboard history
Super+Shift+T        open Telegram
Super+Shift+G        open Discord through X11 wrapper

Super+Q              close focused window
Super+F              toggle fullscreen
Super+A              home toggle
Super+W              overview / zoom-to-fit all windows
Super+C              center focused window
Super+M              fit snapped window
Super+Shift+M        fit focused window
Super+S              search open windows

Super+L              lock
Super+Alt+L          lock
Super+N              toggle notification center
Super+Shift+D        toggle light/dark theme
Super+Shift+I        toggle caffeine / auto-lock
Super+Shift+P        open power menu
Super+Ctrl+Shift+Q   quit driftwm

Super+Shift+W        cycle shader wallpaper
Super+Ctrl+W         pick photo wallpaper

Super+Shift+R        start screen recording
Super+Shift+S        stop screen recording

Ctrl+Shift+1         screenshot area to clipboard
Ctrl+Shift+2         screenshot screen to clipboard
Ctrl+Shift+3         screenshot focused window to clipboard
Print                screenshot screen to clipboard
```

Media keys:

```text
Volume Up            raise output volume by 5%
Volume Down          lower output volume by 5%
Mute                 toggle output mute
Mic Mute             toggle microphone mute
Next                 playerctl next
Previous             playerctl previous
Play                 playerctl play-pause
Pause                playerctl play-pause
Stop                 playerctl stop
Brightness Up        raise brightness by 5%
Brightness Down      lower brightness by 5%
```

Touchpad/window gestures:

```text
Alt+3-finger-swipe       resize snapped window
Alt+Shift+3-finger-swipe resize floating window
```

## Legacy Widgets

The original driftwm Python widgets are kept in the repo, but afterglow does not
autostart them anymore. The bottom `waybar` replaced their normal desktop role.

Legacy widgets live in:

```text
config/driftwm/widgets/
```

They can still be launched manually with:

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
