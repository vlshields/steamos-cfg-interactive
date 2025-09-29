#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

readonly WAYLAND_SESSIONS_DIR="/usr/share/wayland-sessions"
readonly GAMESCOPE_SCRIPT="/usr/bin/gamescope-session"
readonly EXIT_STEAM_SCRIPT="/usr/bin/steamos-session-select"
readonly NA_OS_SCRIPT="/usr/bin/steamos-select-branch"
readonly STEAMOS_UPDATE="/usr/bin/steamos-update"
readonly BIOS_UPDATE="/usr/bin/jupiter-biosupdate"
readonly TIMEZONE_SCRIPT="/usr/bin/steamos-set-timezone"
readonly POLKIT_HELPERS_DIR="/usr/bin/steamos-polkit-helpers"

readonly DEFAULT_WIDTH="1920"
readonly DEFAULT_HEIGHT="1080"
readonly DEFAULT_REFRESH="60"
readonly DEFAULT_HDR="false"
readonly DEFAULT_HDR_NITS="400"
readonly DEFAULT_MANGOAPP="auto"
readonly DEFAULT_FSR="false"
readonly DEFAULT_FSR_LEVEL="1"
readonly DEFAULT_FPS_LIMIT="0"
readonly DEFAULT_FULLSCREEN="true"
readonly DEFAULT_AUTOLOGIN="false"
readonly DEFAULT_MODE="advanced"

readonly MIN_WIDTH=640
readonly MAX_WIDTH=7680
readonly MIN_HEIGHT=480
readonly MAX_HEIGHT=4320
readonly MIN_REFRESH=24
readonly MAX_REFRESH=360
readonly MIN_HDR_NITS=100
readonly MAX_HDR_NITS=10000
readonly MIN_FPS_LIMIT=0
readonly MAX_FPS_LIMIT=1000
readonly MIN_FSR_LEVEL=1
readonly MAX_FSR_LEVEL=4

declare -g USERNAME=""
declare -g CONFIG_FILE=""
declare -g CONFIG_BACKUP_DIR=""
declare -g UI_TOOL=""
declare -g MANGOAPP_AVAILABLE="false"

declare -g WIDTH="$DEFAULT_WIDTH"
declare -g HEIGHT="$DEFAULT_HEIGHT"
declare -g REFRESH="$DEFAULT_REFRESH"
declare -g HDR="$DEFAULT_HDR"
declare -g HDR_NITS="$DEFAULT_HDR_NITS"
declare -g MANGOAPP="$DEFAULT_MANGOAPP"
declare -g FSR="$DEFAULT_FSR"
declare -g FSR_LEVEL="$DEFAULT_FSR_LEVEL"
declare -g FPS_LIMIT="$DEFAULT_FPS_LIMIT"
declare -g FULLSCREEN="$DEFAULT_FULLSCREEN"
declare -g AUTOLOGIN="$DEFAULT_AUTOLOGIN"
declare -g MODE="$DEFAULT_MODE"

readonly LOG_FILE="/var/log/${SCRIPT_NAME}.log"
declare -g ROLLBACK_FILES=()

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [[ "$level" == "ERROR" ]] || [[ "$level" == "WARN" ]]; then
        echo "[$level] $message" >&2
    fi
}

cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_message "ERROR" "Script failed with exit code $exit_code"
        rollback_changes
    fi
}

rollback_changes() {
    log_message "INFO" "Rolling back changes..."
    for file in "${ROLLBACK_FILES[@]}"; do
        if [[ -f "${file}.backup" ]]; then
            mv -f "${file}.backup" "$file" 2>/dev/null || true
            log_message "INFO" "Rolled back: $file"
        fi
    done
}

trap cleanup_on_error EXIT

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "This script must be run with sudo"
        echo "This script must be run with sudo." >&2
        exit 1
    fi
}

get_real_user() {
    local user

    if [[ -n "${SUDO_USER:-}" ]]; then
        user="$SUDO_USER"
    elif [[ -n "${USER:-}" ]] && [[ "$USER" != "root" ]]; then
        user="$USER"
    else
        user=$(who am i 2>/dev/null | awk '{print $1}')
        if [[ -z "$user" ]] || [[ "$user" == "root" ]]; then
            user=$(logname 2>/dev/null || echo "")
        fi
    fi

    if [[ -z "$user" ]] || [[ "$user" == "root" ]]; then
        log_message "ERROR" "Could not determine non-root user"
        echo "Error: Could not determine the actual user. Please run with sudo from a regular user account." >&2
        exit 1
    fi

    if ! id "$user" &>/dev/null; then
        log_message "ERROR" "User $user does not exist"
        echo "Error: User $user does not exist" >&2
        exit 1
    fi

    echo "$user"
}

initialize_environment() {
    USERNAME=$(get_real_user)
    CONFIG_FILE="/home/${USERNAME}/.config/gamescope/gamescope.conf"
    CONFIG_BACKUP_DIR="/home/${USERNAME}/.config/gamescope/backups"

    log_message "INFO" "Initializing environment for user: $USERNAME"

    if ! [[ -d "/home/${USERNAME}" ]]; then
        log_message "ERROR" "Home directory does not exist for user $USERNAME"
        exit 1
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")" || {
        log_message "ERROR" "Failed to create config directory"
        exit 1
    }

    mkdir -p "$CONFIG_BACKUP_DIR" || {
        log_message "ERROR" "Failed to create backup directory"
        exit 1
    }

    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config/gamescope" || {
        log_message "ERROR" "Failed to set ownership on config directory"
        exit 1
    }
}

validate_integer() {
    local value="$1"
    local min="$2"
    local max="$3"
    local name="$4"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Invalid $name: not a number"
        echo "Error: $name must be a positive integer" >&2
        return 1
    fi

    if [[ $value -lt $min ]] || [[ $value -gt $max ]]; then
        log_message "ERROR" "Invalid $name: out of range ($min-$max)"
        echo "Error: $name must be between $min and $max" >&2
        return 1
    fi

    return 0
}

validate_boolean() {
    local value="$1"
    local name="$2"

    if [[ "$value" != "true" ]] && [[ "$value" != "false" ]]; then
        log_message "ERROR" "Invalid $name: not a boolean"
        echo "Error: $name must be 'true' or 'false'" >&2
        return 1
    fi

    return 0
}

sanitize_string() {
    local input="$1"
    local sanitized

    sanitized="${input//[^a-zA-Z0-9._-]/}"

    if [[ ${#sanitized} -gt 255 ]]; then
        sanitized="${sanitized:0:255}"
    fi

    echo "$sanitized"
}

escape_for_shell() {
    local input="$1"
    printf '%q' "$input"
}

detect_ui_tool() {
    if command -v dialog &>/dev/null; then
        UI_TOOL="dialog"
    elif command -v whiptail &>/dev/null; then
        UI_TOOL="whiptail"
    fi
    log_message "INFO" "UI tool detected: ${UI_TOOL:-none}"
}

check_dependencies() {
    local missing_deps=()

    if ! command -v gamescope &>/dev/null; then
        missing_deps+=("gamescope")
    fi

    if ! command -v steam &>/dev/null; then
        missing_deps+=("steam")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing dependencies: ${missing_deps[*]}"
        echo "Error: The following required dependencies are missing:" >&2
        printf ' - %s\n' "${missing_deps[@]}" >&2
        echo "Please install them before running this script." >&2
        exit 1
    fi

    if command -v mangoapp &>/dev/null || command -v mangohud &>/dev/null; then
        MANGOAPP_AVAILABLE="true"
        log_message "INFO" "MangoHud detected"
    else
        log_message "INFO" "MangoHud not available"
    fi
}

show_menu() {
    local title="$1"
    local text="$2"
    shift 2

    if [[ -z "$UI_TOOL" ]]; then
        return 1
    fi

    local temp_file
    temp_file=$(mktemp) || return 1
    trap "rm -f $temp_file" RETURN

    if [[ "$UI_TOOL" == "dialog" ]]; then
        dialog --title "$title" --menu "$text" 20 70 12 "$@" 2>"$temp_file"
    else
        whiptail --title "$title" --menu "$text" 20 70 12 "$@" 2>"$temp_file"
    fi

    local result=$?
    if [[ $result -eq 0 ]]; then
        cat "$temp_file"
    fi
    return $result
}

show_inputbox() {
    local title="$1"
    local text="$2"
    local default="$3"

    if [[ -z "$UI_TOOL" ]]; then
        return 1
    fi

    local temp_file
    temp_file=$(mktemp) || return 1
    trap "rm -f $temp_file" RETURN

    if [[ "$UI_TOOL" == "dialog" ]]; then
        dialog --title "$title" --inputbox "$text" 10 70 "$default" 2>"$temp_file"
    else
        whiptail --title "$title" --inputbox "$text" 10 70 "$default" 2>"$temp_file"
    fi

    local result=$?
    if [[ $result -eq 0 ]]; then
        cat "$temp_file"
    fi
    return $result
}

show_yesno() {
    local title="$1"
    local text="$2"

    if [[ -z "$UI_TOOL" ]]; then
        return 1
    fi

    if [[ "$UI_TOOL" == "dialog" ]]; then
        dialog --title "$title" --yesno "$text" 10 70
    else
        whiptail --title "$title" --yesno "$text" 10 70
    fi
}

show_checklist() {
    local title="$1"
    local text="$2"
    shift 2

    if [[ -z "$UI_TOOL" ]]; then
        return 1
    fi

    local temp_file
    temp_file=$(mktemp) || return 1
    trap "rm -f $temp_file" RETURN

    if [[ "$UI_TOOL" == "dialog" ]]; then
        dialog --title "$title" --checklist "$text" 20 70 12 "$@" 2>"$temp_file"
    else
        whiptail --title "$title" --checklist "$text" 20 70 12 "$@" 2>"$temp_file"
    fi

    local result=$?
    if [[ $result -eq 0 ]]; then
        cat "$temp_file"
    fi
    return $result
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_message "INFO" "Loading configuration from $CONFIG_FILE"

        local temp_config
        temp_config=$(mktemp) || return

        grep -E '^[A-Z_]+=' "$CONFIG_FILE" > "$temp_config" 2>/dev/null || true

        while IFS='=' read -r key value; do
            key=$(sanitize_string "$key")
            value="${value//\"/}"

            case "$key" in
                WIDTH)
                    if validate_integer "$value" "$MIN_WIDTH" "$MAX_WIDTH" "WIDTH"; then
                        WIDTH="$value"
                    fi
                    ;;
                HEIGHT)
                    if validate_integer "$value" "$MIN_HEIGHT" "$MAX_HEIGHT" "HEIGHT"; then
                        HEIGHT="$value"
                    fi
                    ;;
                REFRESH)
                    if validate_integer "$value" "$MIN_REFRESH" "$MAX_REFRESH" "REFRESH"; then
                        REFRESH="$value"
                    fi
                    ;;
                HDR_NITS)
                    if validate_integer "$value" "$MIN_HDR_NITS" "$MAX_HDR_NITS" "HDR_NITS"; then
                        HDR_NITS="$value"
                    fi
                    ;;
                FSR_LEVEL)
                    if validate_integer "$value" "$MIN_FSR_LEVEL" "$MAX_FSR_LEVEL" "FSR_LEVEL"; then
                        FSR_LEVEL="$value"
                    fi
                    ;;
                FPS_LIMIT)
                    if validate_integer "$value" "$MIN_FPS_LIMIT" "$MAX_FPS_LIMIT" "FPS_LIMIT"; then
                        FPS_LIMIT="$value"
                    fi
                    ;;
                HDR|FSR|FULLSCREEN|AUTOLOGIN)
                    if validate_boolean "$value" "$key"; then
                        declare -g "$key=$value"
                    fi
                    ;;
                MANGOAPP)
                    if [[ "$value" == "true" ]] || [[ "$value" == "false" ]] || [[ "$value" == "auto" ]]; then
                        MANGOAPP="$value"
                    fi
                    ;;
                MODE)
                    if [[ "$value" == "basic" ]] || [[ "$value" == "advanced" ]]; then
                        MODE="$value"
                    fi
                    ;;
            esac
        done < "$temp_config"

        rm -f "$temp_config"
    fi
}

save_config() {
    local backup_file="${CONFIG_BACKUP_DIR}/gamescope.conf.$(date +%Y%m%d_%H%M%S)"

    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$backup_file" || {
            log_message "ERROR" "Failed to create config backup"
            return 1
        }
        log_message "INFO" "Created config backup: $backup_file"
    fi

    {
        echo "# Gamescope Configuration"
        echo "# Generated by $SCRIPT_NAME v$SCRIPT_VERSION"
        echo "# Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "WIDTH=\"$(escape_for_shell "$WIDTH")\""
        echo "HEIGHT=\"$(escape_for_shell "$HEIGHT")\""
        echo "REFRESH=\"$(escape_for_shell "$REFRESH")\""
        echo "HDR=\"$(escape_for_shell "$HDR")\""
        echo "HDR_NITS=\"$(escape_for_shell "$HDR_NITS")\""
        echo "MANGOAPP=\"$(escape_for_shell "$MANGOAPP")\""
        echo "FSR=\"$(escape_for_shell "$FSR")\""
        echo "FSR_LEVEL=\"$(escape_for_shell "$FSR_LEVEL")\""
        echo "FPS_LIMIT=\"$(escape_for_shell "$FPS_LIMIT")\""
        echo "FULLSCREEN=\"$(escape_for_shell "$FULLSCREEN")\""
        echo "AUTOLOGIN=\"$(escape_for_shell "$AUTOLOGIN")\""
        echo "MODE=\"$(escape_for_shell "$MODE")\""
    } > "$CONFIG_FILE" || {
        log_message "ERROR" "Failed to save configuration"
        return 1
    }

    chown "${USERNAME}:${USERNAME}" "$CONFIG_FILE" || {
        log_message "ERROR" "Failed to set config file ownership"
        return 1
    }

    chmod 600 "$CONFIG_FILE" || {
        log_message "ERROR" "Failed to set config file permissions"
        return 1
    }

    log_message "INFO" "Configuration saved to $CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE"
}

configure_resolution() {
    local new_width new_height

    if [[ -n "$UI_TOOL" ]]; then
        local choice
        choice=$(show_menu "Resolution Configuration" "Select a resolution preset or choose custom:" \
            "1" "Steam Deck (1280x800)" \
            "2" "720p (1280x720)" \
            "3" "1080p (1920x1080)" \
            "4" "1440p (2560x1440)" \
            "5" "4K (3840x2160)" \
            "6" "Custom") || return

        case "$choice" in
            1) new_width="1280"; new_height="800" ;;
            2) new_width="1280"; new_height="720" ;;
            3) new_width="1920"; new_height="1080" ;;
            4) new_width="2560"; new_height="1440" ;;
            5) new_width="3840"; new_height="2160" ;;
            6)
                new_width=$(show_inputbox "Custom Resolution" "Enter width ($MIN_WIDTH-$MAX_WIDTH):" "$WIDTH") || return
                new_height=$(show_inputbox "Custom Resolution" "Enter height ($MIN_HEIGHT-$MAX_HEIGHT):" "$HEIGHT") || return
                ;;
        esac
    else
        echo "Resolution Configuration"
        echo "1) Steam Deck (1280x800)"
        echo "2) 720p (1280x720)"
        echo "3) 1080p (1920x1080)"
        echo "4) 1440p (2560x1440)"
        echo "5) 4K (3840x2160)"
        echo "6) Custom"
        read -rp "Select option (1-6): " choice

        case "$choice" in
            1) new_width="1280"; new_height="800" ;;
            2) new_width="1280"; new_height="720" ;;
            3) new_width="1920"; new_height="1080" ;;
            4) new_width="2560"; new_height="1440" ;;
            5) new_width="3840"; new_height="2160" ;;
            6)
                read -rp "Enter width [$WIDTH]: " new_width
                new_width="${new_width:-$WIDTH}"
                read -rp "Enter height [$HEIGHT]: " new_height
                new_height="${new_height:-$HEIGHT}"
                ;;
            *) return ;;
        esac
    fi

    if validate_integer "$new_width" "$MIN_WIDTH" "$MAX_WIDTH" "width" && \
       validate_integer "$new_height" "$MIN_HEIGHT" "$MAX_HEIGHT" "height"; then
        WIDTH="$new_width"
        HEIGHT="$new_height"
        log_message "INFO" "Resolution set to ${WIDTH}x${HEIGHT}"
    fi
}

configure_refresh() {
    local new_refresh

    if [[ -n "$UI_TOOL" ]]; then
        local choice
        choice=$(show_menu "Refresh Rate" "Select refresh rate:" \
            "30" "30 Hz" \
            "60" "60 Hz" \
            "90" "90 Hz" \
            "100" "100 Hz" \
            "120" "120 Hz" \
            "144" "144 Hz" \
            "165" "165 Hz" \
            "240" "240 Hz" \
            "custom" "Custom") || return

        if [[ "$choice" == "custom" ]]; then
            new_refresh=$(show_inputbox "Custom Refresh Rate" "Enter refresh rate ($MIN_REFRESH-$MAX_REFRESH Hz):" "$REFRESH") || return
        else
            new_refresh="$choice"
        fi
    else
        echo "Refresh Rate Configuration"
        echo "Common rates: 30, 60, 90, 100, 120, 144, 165, 240"
        read -rp "Enter refresh rate [$REFRESH]: " new_refresh
        new_refresh="${new_refresh:-$REFRESH}"
    fi

    if validate_integer "$new_refresh" "$MIN_REFRESH" "$MAX_REFRESH" "refresh rate"; then
        REFRESH="$new_refresh"
        log_message "INFO" "Refresh rate set to ${REFRESH}Hz"
    fi
}

configure_hdr() {
    local new_hdr_nits

    if [[ -n "$UI_TOOL" ]]; then
        if show_yesno "HDR Configuration" "Enable HDR support?"; then
            HDR="true"
            new_hdr_nits=$(show_inputbox "HDR Brightness" \
                "Enter HDR target brightness ($MIN_HDR_NITS-$MAX_HDR_NITS nits):\n\nCommon values:\n- 400: Standard HDR\n- 600: Mid-range HDR\n- 1000: HDR10\n- 1500: High-end HDR" \
                "$HDR_NITS") || return
        else
            HDR="false"
        fi
    else
        read -rp "Enable HDR support? (y/n) [$HDR]: " hdr_choice
        case "$hdr_choice" in
            [Yy]*) HDR="true" ;;
            [Nn]*) HDR="false" ;;
        esac

        if [[ "$HDR" == "true" ]]; then
            echo "HDR Target Brightness (nits)"
            echo "Common values: 400 (standard), 600 (mid), 1000 (HDR10), 1500 (high-end)"
            read -rp "Enter HDR nits [$HDR_NITS]: " new_hdr_nits
            new_hdr_nits="${new_hdr_nits:-$HDR_NITS}"
        fi
    fi

    if [[ "$HDR" == "true" ]] && [[ -n "${new_hdr_nits:-}" ]]; then
        if validate_integer "$new_hdr_nits" "$MIN_HDR_NITS" "$MAX_HDR_NITS" "HDR nits"; then
            HDR_NITS="$new_hdr_nits"
            log_message "INFO" "HDR enabled with ${HDR_NITS} nits"
        fi
    fi
}

configure_autologin() {
    if ! systemctl list-unit-files | grep -q "lightdm.service"; then
        log_message "WARN" "LightDM not installed"
        echo "Warning: LightDM is not installed. Autologin requires LightDM."
        echo "Install with: sudo apt install lightdm"
        AUTOLOGIN="false"
        return
    fi

    if [[ -n "$UI_TOOL" ]]; then
        if show_yesno "Autologin Configuration" \
            "Enable autologin to Steam gamescope session?\n\nThis will automatically log in user '$USERNAME' and start the Steam gaming session on boot."; then
            AUTOLOGIN="true"
        else
            AUTOLOGIN="false"
        fi
    else
        echo "Autologin Configuration"
        echo "This will automatically log in user '$USERNAME' to the Steam session on boot."
        read -rp "Enable autologin? (y/n) [$AUTOLOGIN]: " autologin_choice
        case "$autologin_choice" in
            [Yy]*) AUTOLOGIN="true" ;;
            [Nn]*) AUTOLOGIN="false" ;;
        esac
    fi

    log_message "INFO" "Autologin set to $AUTOLOGIN"
}

configure_advanced() {
    local new_fsr_level new_fps_limit

    if [[ -n "$UI_TOOL" ]]; then
        local options
        options=$(show_checklist "Advanced Options" "Select features to enable:" \
            "mangoapp" "MangoHud Performance Overlay" $([[ "$MANGOAPP" != "false" ]] && echo "ON" || echo "OFF") \
            "fsr" "AMD FidelityFX Super Resolution" $([[ "$FSR" == "true" ]] && echo "ON" || echo "OFF") \
            "fullscreen" "Fullscreen Mode" $([[ "$FULLSCREEN" == "true" ]] && echo "ON" || echo "OFF")) || return

        MANGOAPP="false"
        FSR="false"
        FULLSCREEN="false"

        for opt in $options; do
            opt="${opt//\"/}"
            case "$opt" in
                mangoapp) MANGOAPP="auto" ;;
                fsr) FSR="true" ;;
                fullscreen) FULLSCREEN="true" ;;
            esac
        done

        if [[ "$FSR" == "true" ]]; then
            new_fsr_level=$(show_menu "FSR Quality" "Select FSR quality level:" \
                "1" "Ultra Quality" \
                "2" "Quality" \
                "3" "Balanced" \
                "4" "Performance") || return

            if validate_integer "$new_fsr_level" "$MIN_FSR_LEVEL" "$MAX_FSR_LEVEL" "FSR level"; then
                FSR_LEVEL="$new_fsr_level"
            fi
        fi

        new_fps_limit=$(show_inputbox "FPS Limit" "Enter FPS limit (0 for unlimited):" "$FPS_LIMIT") || return
    else
        echo "Advanced Options"

        read -rp "Enable MangoHud overlay? (y/n) [$([[ "$MANGOAPP" != "false" ]] && echo "y" || echo "n")]: " mango_choice
        case "$mango_choice" in
            [Yy]*) MANGOAPP="auto" ;;
            [Nn]*) MANGOAPP="false" ;;
        esac

        read -rp "Enable AMD FSR? (y/n) [$FSR]: " fsr_choice
        case "$fsr_choice" in
            [Yy]*) FSR="true" ;;
            [Nn]*) FSR="false" ;;
        esac

        if [[ "$FSR" == "true" ]]; then
            echo "FSR Quality Levels:"
            echo "1) Ultra Quality"
            echo "2) Quality"
            echo "3) Balanced"
            echo "4) Performance"
            read -rp "Select FSR level (1-4) [$FSR_LEVEL]: " new_fsr_level
            new_fsr_level="${new_fsr_level:-$FSR_LEVEL}"

            if validate_integer "$new_fsr_level" "$MIN_FSR_LEVEL" "$MAX_FSR_LEVEL" "FSR level"; then
                FSR_LEVEL="$new_fsr_level"
            fi
        fi

        read -rp "Enable fullscreen? (y/n) [$FULLSCREEN]: " fs_choice
        case "$fs_choice" in
            [Yy]*) FULLSCREEN="true" ;;
            [Nn]*) FULLSCREEN="false" ;;
        esac

        read -rp "FPS limit (0 for unlimited) [$FPS_LIMIT]: " new_fps_limit
        new_fps_limit="${new_fps_limit:-$FPS_LIMIT}"
    fi

    if [[ -n "${new_fps_limit:-}" ]]; then
        if validate_integer "$new_fps_limit" "$MIN_FPS_LIMIT" "$MAX_FPS_LIMIT" "FPS limit"; then
            FPS_LIMIT="$new_fps_limit"
        fi
    fi
}

show_summary() {
    local summary="Configuration Summary:\n\n"
    summary+="Resolution: ${WIDTH}x${HEIGHT} @ ${REFRESH}Hz\n"
    summary+="HDR: $HDR"
    [[ "$HDR" == "true" ]] && summary+=" (${HDR_NITS} nits)"
    summary+="\n"
    summary+="MangoHud: $MANGOAPP"
    [[ "$MANGOAPP" == "auto" ]] && summary+=" (runtime detection)"
    summary+="\n"
    summary+="FSR: $FSR"
    [[ "$FSR" == "true" ]] && summary+=" (Level $FSR_LEVEL)"
    summary+="\n"
    summary+="Fullscreen: $FULLSCREEN\n"
    summary+="FPS Limit: "
    [[ "$FPS_LIMIT" == "0" ]] && summary+="Unlimited" || summary+="$FPS_LIMIT"
    summary+="\n"
    summary+="Autologin: $AUTOLOGIN"
    [[ "$AUTOLOGIN" == "true" ]] && summary+=" (User: $USERNAME)"

    if [[ -n "$UI_TOOL" ]]; then
        if [[ "$UI_TOOL" == "dialog" ]]; then
            dialog --title "Configuration Summary" --msgbox "$summary" 16 60
        else
            whiptail --title "Configuration Summary" --msgbox "$summary" 16 60
        fi
    else
        echo -e "\n$summary"
    fi
}

build_gamescope_command() {
    local -a cmd_array=()

    cmd_array+=("gamescope")

    if [[ "$MODE" == "basic" ]]; then
        if [[ "$MANGOAPP" == "true" ]] || { [[ "$MANGOAPP" == "auto" ]] && [[ "$MANGOAPP_AVAILABLE" == "true" ]]; }; then
            cmd_array+=("--mangoapp")
        fi
        cmd_array+=("-e" "--" "steam" "-steamdeck" "-steamos3")
    else
        cmd_array+=("-w" "$WIDTH" "-h" "$HEIGHT" "-r" "$REFRESH")

        if [[ "$HDR" == "true" ]]; then
            cmd_array+=("--hdr-enabled" "--hdr-itm-target-nits" "$HDR_NITS")
        fi

        if [[ "$FSR" == "true" ]]; then
            cmd_array+=("--fsr-sharpness" "$FSR_LEVEL")
        fi

        if [[ "$FPS_LIMIT" != "0" ]]; then
            cmd_array+=("--fps-limit" "$FPS_LIMIT")
        fi

        if [[ "$FULLSCREEN" == "true" ]]; then
            cmd_array+=("-f")
        fi

        if [[ "$MANGOAPP" == "true" ]]; then
            cmd_array+=("--mangoapp")
        elif [[ "$MANGOAPP" == "auto" ]] && [[ "$MANGOAPP_AVAILABLE" == "true" ]]; then
            cmd_array+=("--mangoapp")
        fi

        cmd_array+=("-e" "--" "steam" "-steamdeck" "-steamos3")
    fi

    printf '%q ' "${cmd_array[@]}"
}

select_mode() {
    if [[ -n "$UI_TOOL" ]]; then
        MODE=$(show_menu "Installation Mode" "Select configuration mode:" \
            "basic" "Basic - Simple Steam gaming session" \
            "advanced" "Advanced - Full configuration with HDR, FSR, etc.") || MODE="advanced"
    else
        echo "Installation Mode:"
        echo "1) Basic - Simple Steam gaming session"
        echo "2) Advanced - Full configuration with HDR, FSR, etc."
        read -rp "Select mode (1-2): " mode_choice
        case "$mode_choice" in
            1) MODE="basic" ;;
            2) MODE="advanced" ;;
            *) MODE="advanced" ;;
        esac
    fi
    log_message "INFO" "Mode selected: $MODE"
}

create_safe_script() {
    local script_path="$1"
    local script_content="$2"

    if [[ -f "$script_path" ]]; then
        local backup="${script_path}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$script_path" "$backup" || {
            log_message "ERROR" "Failed to backup $script_path"
            return 1
        }
        ROLLBACK_FILES+=("$script_path")
    fi

    echo "$script_content" > "$script_path" || {
        log_message "ERROR" "Failed to create $script_path"
        return 1
    }

    chmod +x "$script_path" || {
        log_message "ERROR" "Failed to set execute permissions on $script_path"
        return 1
    }

    log_message "INFO" "Created script: $script_path"
    return 0
}

install_configuration() {
    log_message "INFO" "Starting installation"

    save_config || return 1

    local gamescope_cmd
    gamescope_cmd=$(build_gamescope_command)

    local gamescope_script_content="#!/bin/bash
# Auto-generated by Steam Deck UI Configuration Tool
# Version: $SCRIPT_VERSION
# Configuration file: $CONFIG_FILE
# Mode: $MODE

set -euo pipefail

readonly CONFIG_FILE=\"$(escape_for_shell "$CONFIG_FILE")\"

if [[ -f \"\$CONFIG_FILE\" ]]; then
    while IFS='=' read -r key value; do
        value=\"\${value//\\\"/}\"
        case \"\$key\" in
            WIDTH|HEIGHT|REFRESH|HDR|HDR_NITS|MANGOAPP|FSR|FSR_LEVEL|FPS_LIMIT|FULLSCREEN)
                declare \"\$key=\$value\"
                ;;
        esac
    done < <(grep -E '^[A-Z_]+=' \"\$CONFIG_FILE\")
fi

MANGOAPP=\"\${MANGOAPP:-$MANGOAPP}\"
if [[ \"\$MANGOAPP\" == \"auto\" ]]; then
    if command -v mangoapp &>/dev/null || command -v mangohud &>/dev/null; then
        MANGOAPP_FLAG=\"--mangoapp\"
    else
        MANGOAPP_FLAG=\"\"
    fi
elif [[ \"\$MANGOAPP\" == \"true\" ]]; then
    MANGOAPP_FLAG=\"--mangoapp\"
else
    MANGOAPP_FLAG=\"\"
fi
"

    if [[ "$MODE" == "basic" ]]; then
        gamescope_script_content+="
# Basic mode - minimal configuration
exec gamescope \${MANGOAPP_FLAG} -e -- steam -steamdeck -steamos3"
    else
        gamescope_script_content+="
# Advanced mode - full configuration
WIDTH=\"\${WIDTH:-$WIDTH}\"
HEIGHT=\"\${HEIGHT:-$HEIGHT}\"
REFRESH=\"\${REFRESH:-$REFRESH}\"
HDR=\"\${HDR:-$HDR}\"
HDR_NITS=\"\${HDR_NITS:-$HDR_NITS}\"
FSR=\"\${FSR:-$FSR}\"
FSR_LEVEL=\"\${FSR_LEVEL:-$FSR_LEVEL}\"
FPS_LIMIT=\"\${FPS_LIMIT:-$FPS_LIMIT}\"
FULLSCREEN=\"\${FULLSCREEN:-$FULLSCREEN}\"

CMD=(gamescope -w \"\$WIDTH\" -h \"\$HEIGHT\" -r \"\$REFRESH\")

[[ \"\$HDR\" == \"true\" ]] && CMD+=(--hdr-enabled --hdr-itm-target-nits \"\$HDR_NITS\")
[[ \"\$FSR\" == \"true\" ]] && CMD+=(--fsr-sharpness \"\$FSR_LEVEL\")
[[ \"\$FPS_LIMIT\" != \"0\" ]] && CMD+=(--fps-limit \"\$FPS_LIMIT\")
[[ \"\$FULLSCREEN\" == \"true\" ]] && CMD+=(-f)
[[ -n \"\$MANGOAPP_FLAG\" ]] && CMD+=(\$MANGOAPP_FLAG)

CMD+=(-e -- steam -steamdeck -steamos3)

exec \"\${CMD[@]}\""
    fi

    create_safe_script "$GAMESCOPE_SCRIPT" "$gamescope_script_content" || return 1

    create_safe_script "$EXIT_STEAM_SCRIPT" "#!/bin/bash
steam -shutdown
exit 0" || return 1

    create_safe_script "$NA_OS_SCRIPT" "#!/bin/bash
echo \"Not applicable for this OS\"
exit 0" || return 1

    create_safe_script "$STEAMOS_UPDATE" "#!/bin/bash
# No updates available
exit 7" || return 1

    create_safe_script "$BIOS_UPDATE" "#!/bin/bash
# No BIOS updates
exit 0" || return 1

    create_safe_script "$TIMEZONE_SCRIPT" "#!/bin/bash
# Mock timezone setter for SteamOS compatibility
echo \"Timezone configuration not applicable on this system\"
exit 0" || return 1

    if [[ ! -d "$POLKIT_HELPERS_DIR" ]]; then
        mkdir -p "$POLKIT_HELPERS_DIR" || {
            log_message "ERROR" "Failed to create polkit helpers directory"
            return 1
        }
    fi

    local steam_desktop="$WAYLAND_SESSIONS_DIR/steam.desktop"

    if [[ ! -d "$WAYLAND_SESSIONS_DIR" ]]; then
        log_message "ERROR" "Wayland sessions directory does not exist"
        return 1
    fi

    if [[ -f "$steam_desktop" ]]; then
        cp "$steam_desktop" "${steam_desktop}.backup.$(date +%Y%m%d_%H%M%S)" || {
            log_message "ERROR" "Failed to backup steam.desktop"
            return 1
        }
        ROLLBACK_FILES+=("$steam_desktop")
    fi

    cat > "$steam_desktop" <<EOF || return 1
[Desktop Entry]
Encoding=UTF-8
Name=Steam (gamescope)
Comment=Launch Steam within Gamescope
Exec=gamescope-session
Type=WaylandSession
DesktopNames=gamescope
EOF

    log_message "INFO" "Steam Gamescope session added to $steam_desktop"

    if [[ "$AUTOLOGIN" == "true" ]]; then
        log_message "INFO" "Configuring LightDM autologin"

        local lightdm_conf="/etc/lightdm/lightdm.conf.d/50-gamescope-autologin.conf"

        if [[ -f "$lightdm_conf" ]]; then
            cp "$lightdm_conf" "${lightdm_conf}.backup.$(date +%Y%m%d_%H%M%S)" || {
                log_message "ERROR" "Failed to backup LightDM config"
                return 1
            }
            ROLLBACK_FILES+=("$lightdm_conf")
        fi

        mkdir -p "$(dirname "$lightdm_conf")" || {
            log_message "ERROR" "Failed to create LightDM config directory"
            return 1
        }

        cat > "$lightdm_conf" <<EOF || return 1
[Seat:*]
autologin-user=$(escape_for_shell "$USERNAME")
autologin-session=steam
autologin-user-timeout=0
EOF

        if getent group autologin &>/dev/null; then
            usermod -a -G autologin "$USERNAME" || {
                log_message "WARN" "Failed to add user to autologin group"
            }
        fi

        log_message "INFO" "Autologin configured for user: $USERNAME"
    fi

    log_message "INFO" "Installation completed successfully"
    return 0
}

main() {
    log_message "INFO" "Starting $SCRIPT_NAME v$SCRIPT_VERSION"

    check_root
    initialize_environment
    detect_ui_tool
    check_dependencies

    echo "Steam Deck UI Configuration Tool v$SCRIPT_VERSION"
    echo "=========================================="
    echo

    load_config

    if [[ -z "$MODE" ]]; then
        select_mode
    fi

    while true; do
        local choice

        if [[ "$MODE" == "basic" ]]; then
            if [[ -n "$UI_TOOL" ]]; then
                choice=$(show_menu "Basic Gamescope Configuration" "Simple gaming session setup:" \
                    "1" "Toggle MangoHud Overlay" \
                    "2" "Autologin Settings" \
                    "3" "Switch to Advanced Mode" \
                    "4" "Apply & Install" \
                    "5" "Exit") || choice="5"
            else
                echo
                echo "Basic Mode Menu:"
                echo "1) Toggle MangoHud Overlay (Currently: $MANGOAPP)"
                echo "2) Autologin Settings"
                echo "3) Switch to Advanced Mode"
                echo "4) Apply & Install"
                echo "5) Exit"
                read -rp "Select option (1-5): " choice
            fi

            case "$choice" in
                1)
                    if [[ "$MANGOAPP_AVAILABLE" == "true" ]]; then
                        if [[ "$MANGOAPP" == "false" ]]; then
                            MANGOAPP="auto"
                        elif [[ "$MANGOAPP" == "auto" ]]; then
                            MANGOAPP="true"
                        else
                            MANGOAPP="false"
                        fi
                        echo "MangoHud set to: $MANGOAPP"
                    else
                        echo "MangoHud is not installed"
                    fi
                    ;;
                2) configure_autologin ;;
                3)
                    MODE="advanced"
                    continue
                    ;;
                4) choice="7" ;;
                5)
                    echo "Exiting without changes."
                    exit 0
                    ;;
            esac

            if [[ "$choice" != "7" ]]; then
                continue
            fi
        else
            if [[ -n "$UI_TOOL" ]]; then
                choice=$(show_menu "Advanced Gamescope Configuration" "Configure your gaming session:" \
                    "1" "Resolution & Refresh Rate" \
                    "2" "HDR Settings" \
                    "3" "Advanced Options" \
                    "4" "Autologin Settings" \
                    "5" "View Configuration" \
                    "6" "Switch to Basic Mode" \
                    "7" "Apply & Install" \
                    "8" "Exit") || choice="8"
            else
                echo
                echo "Advanced Mode Menu:"
                echo "1) Resolution & Refresh Rate"
                echo "2) HDR Settings"
                echo "3) Advanced Options"
                echo "4) Autologin Settings"
                echo "5) View Configuration"
                echo "6) Switch to Basic Mode"
                echo "7) Apply & Install"
                echo "8) Exit"
                read -rp "Select option (1-8): " choice
            fi
        fi

        case "$choice" in
            1)
                configure_resolution
                configure_refresh
                ;;
            2) configure_hdr ;;
            3) configure_advanced ;;
            4) configure_autologin ;;
            5) show_summary ;;
            6)
                MODE="basic"
                continue
                ;;
            7)
                show_summary

                local confirm
                if [[ -n "$UI_TOOL" ]]; then
                    if ! show_yesno "Confirm Installation" "Apply this configuration and install the gaming session?"; then
                        continue
                    fi
                    confirm="y"
                else
                    read -rp "Apply this configuration? (y/n): " confirm
                fi

                if [[ "$confirm" =~ ^[Yy] ]]; then
                    if install_configuration; then
                        echo
                        echo "Installation complete! (Mode: $MODE)"
                        echo "You can now:"
                        if [[ "$AUTOLOGIN" == "true" ]]; then
                            echo "1. Reboot your system to automatically start in gaming mode"
                            echo "   OR"
                            echo "2. Log out and select 'Steam (gamescope)' from your display manager"
                        else
                            echo "1. Log out of your current session"
                            echo "2. Select 'Steam (gamescope)' from your display manager"
                        fi
                        echo "3. Your configuration is saved at: $CONFIG_FILE"
                        echo
                        echo "To reconfigure, run this script again."

                        if [[ "$AUTOLOGIN" == "true" ]]; then
                            read -rp "Would you like to reboot now? (y/n): " reboot_choice
                            if [[ "$reboot_choice" =~ ^[Yy] ]]; then
                                echo "Rebooting in 5 seconds..."
                                sleep 5
                                systemctl reboot
                            fi
                        fi
                        exit 0
                    else
                        echo "Installation failed. Check the log file: $LOG_FILE"
                    fi
                fi
                ;;
            8)
                echo "Exiting without changes."
                exit 0
                ;;
        esac
    done
}

main "$@"