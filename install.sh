#!/bin/sh
set -eu

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
config_src="$repo_dir/config"
fonts_src="$repo_dir/fonts"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
fonts_home="$data_home/fonts/afterglow"
backup_root="${DRIFT_BACKUP_ROOT:-$HOME/.config-backups}"
backup_root="${AFTERGLOW_BACKUP_ROOT:-$backup_root}"
backup_dir="$backup_root/afterglow-$(date +%Y%m%d-%H%M%S)"

dry_run=0
check_only=0
install_packages=0
packages_only=0
skip_backup=0
detect_output=0
target_output=""
target_mode=""

usage() {
    cat <<EOF
usage: ./install.sh [options]

Options:
  --check             Check tools and repo config without installing.
  --dry-run, -n       Show copy/patch actions without changing files.
  --install-packages  Install packages before applying configs.
  --packages-only     Install packages and exit without applying configs.
  --output NAME       Patch installed driftwm/waybar configs for output NAME.
  --mode MODE         Patch installed driftwm output mode, e.g. 1920x1080@180.
  --detect-output     Try to read output name/mode from wlr-randr and patch installed configs.
  --no-backup         Do not back up existing ~/.config directories.
  --help, -h          Show this help.
EOF
}

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

run() {
    if [ "$dry_run" -eq 1 ]; then
        printf '+'
        for arg in "$@"; do
            printf ' %s' "$arg"
        done
        printf '\n'
    else
        "$@"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check)
            check_only=1
            ;;
        --dry-run|-n)
            dry_run=1
            ;;
        --install-packages)
            install_packages=1
            ;;
        --packages-only)
            install_packages=1
            packages_only=1
            ;;
        --output)
            [ "$#" -ge 2 ] || die "--output needs a value"
            target_output="$2"
            shift
            ;;
        --mode)
            [ "$#" -ge 2 ] || die "--mode needs a value"
            target_mode="$2"
            shift
            ;;
        --detect-output)
            detect_output=1
            ;;
        --no-backup)
            skip_backup=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "unknown option: $1"
            ;;
    esac
    shift
done

[ -d "$config_src" ] || die "config directory not found: $config_src"
[ -f "$config_src/driftwm/config.toml" ] || die "driftwm config not found"

check_commands() {
    required="rsync"
    desktop="driftwm alacritty fuzzel waybar swaync-client swayidle swaylock grim slurp wl-copy wl-paste cliphist notify-send brightnessctl wpctl playerctl ffmpeg"
    optional="wlr-randr gpu-screen-recorder pavucontrol nautilus telegram-desktop discord zed google-chrome wlrctl foot"
    missing_required=0
    missing_desktop=0

    log "Checking commands..."

    for cmd in $required; do
        if have "$cmd"; then
            log "  ok       $cmd"
        else
            log "  missing  $cmd"
            missing_required=1
        fi
    done

    for cmd in $desktop; do
        if have "$cmd"; then
            log "  ok       $cmd"
        else
            log "  missing  $cmd"
            missing_desktop=1
        fi
    done

    for cmd in $optional; do
        if have "$cmd"; then
            log "  ok       $cmd"
        else
            log "  optional $cmd"
        fi
    done

    [ "$missing_required" -eq 0 ] || die "install required commands first"
    if [ "$missing_desktop" -ne 0 ]; then
        log "Some desktop commands are missing. Install packages before using the session."
    fi
}

install_package_list() {
    manager="$1"
    file="$2"

    [ -s "$file" ] || return 0

    case "$manager" in
        pacman)
            have pacman || die "pacman not found"
            if [ "$dry_run" -eq 1 ]; then
                log "+ sudo pacman -S --needed - < $file"
            else
                sudo pacman -S --needed - < "$file"
            fi
            ;;
        yay)
            if have yay; then
                aur_helper="yay"
            elif have paru; then
                aur_helper="paru"
            else
                die "AUR helper not found. Install yay or paru, then rerun package installation."
            fi
            if [ "$dry_run" -eq 1 ]; then
                log "+ $aur_helper -S --needed - < $file"
            else
                "$aur_helper" -S --needed - < "$file"
            fi
            ;;
        *)
            die "unknown package manager: $manager"
            ;;
    esac
}

detect_wlr_output() {
    have wlr-randr || return 1

    detected_output="$(wlr-randr 2>/dev/null | awk '/^[^[:space:]]/ { print $1; exit }')"
    detected_mode="$(wlr-randr 2>/dev/null | awk '
        /current/ {
            for (i = 1; i <= NF; i++) {
                if ($i == "px,") {
                    res = $(i - 1)
                    hz = $(i + 1)
                    sub(/,/, "", hz)
                    sub(/\.0+$/, "", hz)
                    print res "@" hz
                    exit
                }
            }
        }
    ')"

    [ -n "$detected_output" ] || return 1
    target_output="${target_output:-$detected_output}"
    target_mode="${target_mode:-$detected_mode}"
}

backup_existing_configs() {
    [ "$skip_backup" -eq 0 ] || return 0

    made_backup=0
    for src in "$config_src"/*; do
        [ -d "$src" ] || continue
        dir="${src##*/}"
        dst="$config_home/$dir"

        if [ -e "$dst" ]; then
            if [ "$made_backup" -eq 0 ]; then
                run mkdir -p "$backup_dir"
                made_backup=1
            fi
            run cp -a "$dst" "$backup_dir/$dir"
        fi
    done

    if [ "$made_backup" -eq 1 ]; then
        log "Backup dir: $backup_dir"
    else
        log "No existing configs to backup."
    fi
}

copy_configs() {
    run mkdir -p "$config_home"

    if [ "$dry_run" -eq 1 ]; then
        rsync -a --dry-run --itemize-changes \
            --exclude '__pycache__/' \
            --exclude '*.pyc' \
            --exclude '.DS_Store' \
            "$config_src/" "$config_home/"
    else
        rsync -a \
            --exclude '__pycache__/' \
            --exclude '*.pyc' \
            --exclude '.DS_Store' \
            "$config_src/" "$config_home/"
    fi
}

copy_fonts() {
    [ -d "$fonts_src" ] || return 0

    run mkdir -p "$fonts_home"

    if [ "$dry_run" -eq 1 ]; then
        rsync -a --dry-run --itemize-changes \
            "$fonts_src/" "$fonts_home/"
        if have fc-cache; then
            log "+ fc-cache -f $fonts_home"
        else
            log "fc-cache not found; font cache would need manual refresh"
        fi
    else
        rsync -a "$fonts_src/" "$fonts_home/"
        if have fc-cache; then
            fc-cache -f "$fonts_home"
        else
            log "fc-cache not found; font cache may update after next login"
        fi
    fi
}

chmod_installed_scripts() {
    scripts_dir="$config_home/driftwm/scripts"
    widgets_launcher="$config_home/driftwm/widgets/launch.sh"

    if [ -d "$scripts_dir" ]; then
        if [ "$dry_run" -eq 1 ]; then
            log "+ chmod +x $scripts_dir/*.sh"
        else
            find "$scripts_dir" -type f -name '*.sh' -exec chmod +x {} +
        fi
    fi

    if [ -f "$widgets_launcher" ]; then
        run chmod +x "$widgets_launcher"
    fi
}

rewrite_home_paths() {
    old_home="/home/anxi0uz"
    [ "$HOME" != "$old_home" ] || return 0

    escaped_home="$(printf '%s\n' "$HOME" | sed 's/[\/&]/\\&/g')"

    for dir in driftwm waybar fuzzel swaync alacritty foot gtk-3.0 gtk-4.0; do
        target="$config_home/$dir"
        [ -d "$target" ] || continue

        if [ "$dry_run" -eq 1 ]; then
            log "+ replace $old_home -> $HOME under $target"
        else
            find "$target" -type f \
                \( -name '*.toml' -o -name '*.json' -o -name '*.jsonc' -o -name '*.ini' -o -name '*.css' -o -name '*.sh' -o -name '*.py' \) \
                -exec sed -i "s|$old_home|$escaped_home|g" {} +
        fi
    done
}

patch_output_configs() {
    [ -n "$target_output" ] || [ -n "$target_mode" ] || return 0

    drift_config="$config_home/driftwm/config.toml"
    if [ -f "$drift_config" ]; then
        if [ "$dry_run" -eq 1 ]; then
            log "+ patch driftwm output name=$target_output mode=$target_mode in $drift_config"
        else
            tmp="$(mktemp "$drift_config.XXXXXX")"
            awk -v output="$target_output" -v mode="$target_mode" '
                /^\[\[outputs\]\]/ {
                    in_outputs = 1
                    seen_outputs++
                    print
                    next
                }
                in_outputs && /^\[/ {
                    in_outputs = 0
                }
                in_outputs && seen_outputs == 1 && output != "" && /^[[:space:]]*name[[:space:]]*=/ {
                    print "name = \"" output "\""
                    next
                }
                in_outputs && seen_outputs == 1 && mode != "" && /^[[:space:]]*mode[[:space:]]*=/ {
                    print "mode = \"" mode "\""
                    next
                }
                { print }
            ' "$drift_config" > "$tmp"
            chmod --reference="$drift_config" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
            mv "$tmp" "$drift_config"
        fi
    fi

    [ -n "$target_output" ] || return 0
    waybar_dir="$config_home/waybar"
    [ -d "$waybar_dir" ] || return 0

    for file in "$waybar_dir"/*.jsonc; do
        [ -f "$file" ] || continue
        if [ "$dry_run" -eq 1 ]; then
            log "+ patch waybar output=$target_output in $file"
        else
            sed -i "s|\"output\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"output\": \"$target_output\"|" "$file"
        fi
    done
}

validate_repo_config() {
    have driftwm || {
        log "driftwm not found; skipping driftwm --check-config"
        return 0
    }

    XDG_CONFIG_HOME="$repo_dir/config" driftwm --check-config
}

validate_installed_config() {
    have driftwm || return 0
    driftwm --check-config
}

if [ "$install_packages" -eq 1 ]; then
    install_package_list pacman "$repo_dir/packages/pacman.txt"
    install_package_list yay "$repo_dir/packages/aur.txt"
fi

if [ "$packages_only" -eq 1 ]; then
    log "Package step complete."
    exit 0
fi

check_commands
validate_repo_config

if [ "$detect_output" -eq 1 ]; then
    if detect_wlr_output; then
        log "Detected output: $target_output ${target_mode:-}"
    else
        log "Could not detect output with wlr-randr; keeping config output as-is."
    fi
fi

if [ "$check_only" -eq 1 ]; then
    log "Check complete."
    exit 0
fi

backup_existing_configs
copy_configs
copy_fonts
chmod_installed_scripts
rewrite_home_paths
patch_output_configs
if [ "$dry_run" -eq 0 ]; then
    validate_installed_config
fi

if [ "$dry_run" -eq 1 ]; then
    log "Dry run complete. No files were changed."
else
    log "Installed afterglow configs into $config_home."
    if [ -z "$target_output" ]; then
        log "Output config stayed pinned to the repo default. Use --detect-output or --output NAME for VMs/laptops."
    fi
    log "Log out and choose the driftwm session in your login manager."
fi
