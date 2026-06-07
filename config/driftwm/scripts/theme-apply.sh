#!/bin/sh
# Apply rice theme to driftwm, waybar, GTK, and the driftwm-private Alacritty config.
# Usage: theme-apply.sh light|dark [--no-restart]
#
# driftwm picks up config.toml changes via mtime poll (~500ms).
# waybar is killed and relaunched in autostart order unless --no-restart is passed.

set -eu

mode="${1:-}"
no_restart="${2:-}"

case "$mode" in
    light|dark) ;;
    *) echo "usage: $0 light|dark [--no-restart]" >&2; exit 2 ;;
esac

RICE="$HOME/.config/driftwm"
WAYBAR_CSS="$HOME/.config/waybar/bottom.css"
FOOT_CONFIG="$HOME/.config/foot/foot.ini"
GTK3_SETTINGS="$HOME/.config/gtk-3.0/settings.ini"
GTK4_CSS="$HOME/.config/gtk-4.0/gtk.css"

set_waybar_color() {
    name="$1"
    value="$2"
    file="$3"

    [ -f "$file" ] || return 0
    sed -i "s|^@define-color $name .*;|@define-color $name $value;|" "$file"
}

set_gtk_ini() {
    file="$1"
    key="$2"
    value="$3"

    if grep -q "^$key=" "$file" 2>/dev/null; then
        sed -i "s|^$key=.*|$key=$value|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

set_main_ini() {
    file="$1"
    key="$2"
    value="$3"

    [ -f "$file" ] || return 0

    if grep -q "^$key=" "$file" 2>/dev/null; then
        sed -i "s|^$key=.*|$key=$value|" "$file"
        return 0
    fi

    tmp="$(mktemp "$file.XXXXXX")"
    awk -v key="$key" -v value="$value" '
        /^\[/ && !done {
            print key "=" value
            done = 1
        }
        { print }
        END {
            if (!done) {
                print key "=" value
            }
        }
    ' "$file" >"$tmp" && mv "$tmp" "$file"
}

start_waybar() {
    if command -v setsid >/dev/null 2>&1; then
        setsid waybar -c "$HOME/.config/waybar/bottom.jsonc" -s "$HOME/.config/waybar/bottom.css" >/tmp/waybar-bottom.log 2>&1 < /dev/null &
    else
        waybar -c "$HOME/.config/waybar/bottom.jsonc" -s "$HOME/.config/waybar/bottom.css" >/tmp/waybar-bottom.log 2>&1 < /dev/null &
    fi
}

if [ "$mode" = "light" ]; then
    DECOR_BG="#F4E6C3"
    DECOR_FG="#514737"
    SHADER="pink_cloud.glsl"
    GTK_THEME="adw-gtk3"
    GTK_DARK=0
    GTK_SCHEME="default"

    BAR_BG="#F4E6C3"
    BAR_FG="#514737"
    BAR_BORDER="#D8C59E"
    BAR_EDGE="#EAD9B8"
    TASKBAR_FG="#6A5A43"
    TASKBAR_BORDER="#DDCAA6"
    HOVER_BG="#EAD9B8"
    HOVER_FG="#3F3526"
    ACTIVE_BG="#6F5634"
    ACTIVE_FG="#FFF1D0"
    WARN_BG="#ECD6AA"
    WARN_FG="#8A5A12"
    CRITICAL_BG="#E7B6A9"
    CRITICAL_FG="#5C1B14"
    TOOLTIP_BG="#FFF1D0"
    TOOLTIP_FG="#4F4636"
    TOOLTIP_BORDER="#C9B58E"
else
    DECOR_BG="#050605"
    DECOR_FG="#D8D2C3"
    SHADER="dark_sea.glsl"
    GTK_THEME="adw-gtk3-dark"
    GTK_DARK=1
    GTK_SCHEME="prefer-dark"

    BAR_BG="#050605"
    BAR_FG="#B8B8AE"
    BAR_BORDER="#252520"
    BAR_EDGE="#050505"
    TASKBAR_FG="#A4A49A"
    TASKBAR_BORDER="#20201C"
    HOVER_BG="#181814"
    HOVER_FG="#D8D2C3"
    ACTIVE_BG="#D8D2C3"
    ACTIVE_FG="#050605"
    WARN_BG="#17130E"
    WARN_FG="#D2A24C"
    CRITICAL_BG="#4A1717"
    CRITICAL_FG="#FFD0D0"
    TOOLTIP_BG="#050605"
    TOOLTIP_FG="#D8D2C3"
    TOOLTIP_BORDER="#44443C"
fi

# driftwm: decorations.bg_color, decorations.fg_color, background.path.
# Keep photo wallpapers intact: only replace a wallpaper path that already points
# at one of this rice's static shader files.
sed -i \
    -e "s|^bg_color = \".*\"|bg_color = \"$DECOR_BG\"|" \
    -e "s|^fg_color = \".*\"|fg_color = \"$DECOR_FG\"|" \
    -e "s|^path = \".*/wallpapers/[^\"]*\\.glsl\"|path = \"$RICE/wallpapers/static/$SHADER\"|" \
    "$RICE/config.toml"

# Swap the driftwm-private terminal palette together with the rest of the theme.
sed -i "s|colors-[a-z]*\\.toml|colors-${mode}.toml|" "$RICE/alacritty/alacritty.toml"
set_main_ini "$FOOT_CONFIG" initial-color-theme "$mode"

if command -v pkill >/dev/null 2>&1; then
    if [ "$mode" = "light" ]; then
        pkill -USR2 -x foot 2>/dev/null || true
        pkill -USR2 -x footclient 2>/dev/null || true
    else
        pkill -USR1 -x foot 2>/dev/null || true
        pkill -USR1 -x footclient 2>/dev/null || true
    fi
fi

set_waybar_color bar_bg "$BAR_BG" "$WAYBAR_CSS"
set_waybar_color bar_fg "$BAR_FG" "$WAYBAR_CSS"
set_waybar_color bar_border "$BAR_BORDER" "$WAYBAR_CSS"
set_waybar_color bar_edge "$BAR_EDGE" "$WAYBAR_CSS"
set_waybar_color taskbar_fg "$TASKBAR_FG" "$WAYBAR_CSS"
set_waybar_color taskbar_border "$TASKBAR_BORDER" "$WAYBAR_CSS"
set_waybar_color hover_bg "$HOVER_BG" "$WAYBAR_CSS"
set_waybar_color hover_fg "$HOVER_FG" "$WAYBAR_CSS"
set_waybar_color active_bg "$ACTIVE_BG" "$WAYBAR_CSS"
set_waybar_color active_fg "$ACTIVE_FG" "$WAYBAR_CSS"
set_waybar_color warn_bg "$WARN_BG" "$WAYBAR_CSS"
set_waybar_color warn_fg "$WARN_FG" "$WAYBAR_CSS"
set_waybar_color critical_bg "$CRITICAL_BG" "$WAYBAR_CSS"
set_waybar_color critical_fg "$CRITICAL_FG" "$WAYBAR_CSS"
set_waybar_color tooltip_bg "$TOOLTIP_BG" "$WAYBAR_CSS"
set_waybar_color tooltip_fg "$TOOLTIP_FG" "$WAYBAR_CSS"
set_waybar_color tooltip_border "$TOOLTIP_BORDER" "$WAYBAR_CSS"

mkdir -p "$(dirname "$GTK3_SETTINGS")" "$(dirname "$GTK4_CSS")"
[ -f "$GTK3_SETTINGS" ] || printf '[Settings]\n' >"$GTK3_SETTINGS"
set_gtk_ini "$GTK3_SETTINGS" gtk-application-prefer-dark-theme "$GTK_DARK"
set_gtk_ini "$GTK3_SETTINGS" gtk-cursor-theme-name "capitaine-cursors"
set_gtk_ini "$GTK3_SETTINGS" gtk-theme-name "$GTK_THEME"
printf '%s\n' '/* afterglow: keep GTK4/libadwaita apps on the system color-scheme. */' >"$GTK4_CSS"

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface color-scheme "$GTK_SCHEME" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface cursor-theme "capitaine-cursors" >/dev/null 2>&1 || true
fi

if [ "$no_restart" = "--no-restart" ]; then
    exit 0
fi

# Restart the screen-anchored bottom bar.
pkill -x waybar 2>/dev/null || true
sleep 0.3
start_waybar

# swayosd-server snapshots the GTK theme at startup; restart for OSD popups
# (volume, brightness) to render in the new palette.
if command -v swayosd-server >/dev/null 2>&1; then
    pkill -x swayosd-server 2>/dev/null || true
    sleep 0.2
    swayosd-server --top-margin 0.95 &
fi
