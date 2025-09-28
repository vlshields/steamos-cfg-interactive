#!/bin/bash
set -e  

WAYLAND_SESSIONS_DIR="/usr/share/wayland-sessions/"
GAMESCOPE_SCRIPT="/usr/bin/gamescope-session"
EXIT_STEAM_SCRIPT="/usr/bin/steamos-session-select"
NA_OS_SCRIPT="/usr/bin/steamos-select-branch"
STEAMOS_UPDATE="/usr/bin/steamos-update"
BIOS_UPDATE="/usr/bin/jupiter-biosupdate"
TIMEZONE_SCRIPT="/usr/bin/steamos-set-timezone"
POLKIT_HELPERS_DIR="/usr/bin/steamos-polkit-helpers"
USERNAME=$(logname)
CONFIG_FILE="/home/$USERNAME/.config/gamescope/gamescope.conf"

# Default values
DEFAULT_WIDTH="1920"
DEFAULT_HEIGHT="1080"
DEFAULT_REFRESH="60"
DEFAULT_HDR="false"
DEFAULT_HDR_NITS="400"
DEFAULT_MANGOAPP="auto"
DEFAULT_FSR="false"
DEFAULT_FSR_LEVEL="1"
DEFAULT_FPS_LIMIT="0"
DEFAULT_FULLSCREEN="true"
DEFAULT_AUTOLOGIN="false"
DEFAULT_MODE="advanced"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo."
    exit 1
fi
# 
# # Check dependencies
# if [ ! -d "$WAYLAND_SESSIONS_DIR" ]; then
#     echo "Error: $WAYLAND_SESSIONS_DIR does not exist. Is Wayland installed?"
#     exit 1
# fi

# if ! command -v steam &> /dev/null; then
#     echo "Error: Steam is not installed. Please install Steam before running this script."
#     exit 1
# fi

# Check for MangoHud (optional)
MANGOAPP_AVAILABLE="false"
if command -v mangoapp &> /dev/null || command -v mangohud &> /dev/null; then
    MANGOAPP_AVAILABLE="true"
else
    echo "Note: MangoHud is not installed. Performance overlay will be unavailable."
    echo "To install: sudo apt install mangohud"
    MANGOAPP_AVAILABLE="false"
fi

# if ! command -v gamescope &> /dev/null; then
#     echo "Error: gamescope is not installed. Please install gamescope before running this script."
#     exit 1
# fi

# Detect available UI tools
UI_TOOL=""
if command -v dialog &> /dev/null; then
    UI_TOOL="dialog"
elif command -v whiptail &> /dev/null; then
    UI_TOOL="whiptail"
fi

# Function to show menu using dialog/whiptail
show_menu() {
    local title="$1"
    local text="$2"
    shift 2
    if [ "$UI_TOOL" = "dialog" ]; then
        dialog --title "$title" --menu "$text" 20 70 12 "$@" 2>&1 >/dev/tty
    elif [ "$UI_TOOL" = "whiptail" ]; then
        whiptail --title "$title" --menu "$text" 20 70 12 "$@" 3>&1 1>&2 2>&3
    fi
}

# Function to show input box
show_inputbox() {
    local title="$1"
    local text="$2"
    local default="$3"
    if [ "$UI_TOOL" = "dialog" ]; then
        dialog --title "$title" --inputbox "$text" 10 70 "$default" 2>&1 >/dev/tty
    elif [ "$UI_TOOL" = "whiptail" ]; then
        whiptail --title "$title" --inputbox "$text" 10 70 "$default" 3>&1 1>&2 2>&3
    fi
}

# Function to show yes/no dialog
show_yesno() {
    local title="$1"
    local text="$2"
    if [ "$UI_TOOL" = "dialog" ]; then
        dialog --title "$title" --yesno "$text" 10 70
    elif [ "$UI_TOOL" = "whiptail" ]; then
        whiptail --title "$title" --yesno "$text" 10 70
    fi
    return $?
}

# Function to show checklist
show_checklist() {
    local title="$1"
    local text="$2"
    shift 2
    if [ "$UI_TOOL" = "dialog" ]; then
        dialog --title "$title" --checklist "$text" 20 70 12 "$@" 2>&1 >/dev/tty
    elif [ "$UI_TOOL" = "whiptail" ]; then
        whiptail --title "$title" --checklist "$text" 20 70 12 "$@" 3>&1 1>&2 2>&3
    fi
}

# Load existing configuration if available
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        WIDTH="${WIDTH:-$DEFAULT_WIDTH}"
        HEIGHT="${HEIGHT:-$DEFAULT_HEIGHT}"
        REFRESH="${REFRESH:-$DEFAULT_REFRESH}"
        HDR="${HDR:-$DEFAULT_HDR}"
        HDR_NITS="${HDR_NITS:-$DEFAULT_HDR_NITS}"
        MANGOAPP="${MANGOAPP:-$DEFAULT_MANGOAPP}"
        MODE="${MODE:-$DEFAULT_MODE}"
        FSR="${FSR:-$DEFAULT_FSR}"
        FSR_LEVEL="${FSR_LEVEL:-$DEFAULT_FSR_LEVEL}"
        FPS_LIMIT="${FPS_LIMIT:-$DEFAULT_FPS_LIMIT}"
        FULLSCREEN="${FULLSCREEN:-$DEFAULT_FULLSCREEN}"
        AUTOLOGIN="${AUTOLOGIN:-$DEFAULT_AUTOLOGIN}"
    else
        WIDTH="$DEFAULT_WIDTH"
        HEIGHT="$DEFAULT_HEIGHT"
        REFRESH="$DEFAULT_REFRESH"
        HDR="$DEFAULT_HDR"
        HDR_NITS="$DEFAULT_HDR_NITS"
        MANGOAPP="$DEFAULT_MANGOAPP"
        FSR="$DEFAULT_FSR"
        FSR_LEVEL="$DEFAULT_FSR_LEVEL"
        FPS_LIMIT="$DEFAULT_FPS_LIMIT"
        FULLSCREEN="$DEFAULT_FULLSCREEN"
        AUTOLOGIN="$DEFAULT_AUTOLOGIN"
        MODE="$DEFAULT_MODE"
    fi
}

# Save configuration
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
# Gamescope Configuration
WIDTH="$WIDTH"
HEIGHT="$HEIGHT"
REFRESH="$REFRESH"
HDR="$HDR"
HDR_NITS="$HDR_NITS"
MANGOAPP="$MANGOAPP"
FSR="$FSR"
FSR_LEVEL="$FSR_LEVEL"
FPS_LIMIT="$FPS_LIMIT"
FULLSCREEN="$FULLSCREEN"
AUTOLOGIN="$AUTOLOGIN"
MODE="$MODE"
EOF
    chown $USERNAME:$USERNAME "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE"
}

# Configure resolution
configure_resolution() {
    if [ -n "$UI_TOOL" ]; then
        local choice=$(show_menu "Resolution Configuration" "Select a resolution preset or choose custom:" \
            "1" "Steam Deck (1280x800)" \
            "2" "720p (1280x720)" \
            "3" "1080p (1920x1080)" \
            "4" "1440p (2560x1440)" \
            "5" "4K (3840x2160)" \
            "6" "Custom")
        
        case $choice in
            1) WIDTH="1280"; HEIGHT="800" ;;
            2) WIDTH="1280"; HEIGHT="720" ;;
            3) WIDTH="1920"; HEIGHT="1080" ;;
            4) WIDTH="2560"; HEIGHT="1440" ;;
            5) WIDTH="3840"; HEIGHT="2160" ;;
            6) 
                WIDTH=$(show_inputbox "Custom Resolution" "Enter width:" "$WIDTH")
                HEIGHT=$(show_inputbox "Custom Resolution" "Enter height:" "$HEIGHT")
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
        read -p "Select option (1-6): " choice
        
        case $choice in
            1) WIDTH="1280"; HEIGHT="800" ;;
            2) WIDTH="1280"; HEIGHT="720" ;;
            3) WIDTH="1920"; HEIGHT="1080" ;;
            4) WIDTH="2560"; HEIGHT="1440" ;;
            5) WIDTH="3840"; HEIGHT="2160" ;;
            6) 
                read -p "Enter width [$WIDTH]: " new_width
                WIDTH="${new_width:-$WIDTH}"
                read -p "Enter height [$HEIGHT]: " new_height
                HEIGHT="${new_height:-$HEIGHT}"
                ;;
        esac
    fi
}

# Configure refresh rate
configure_refresh() {
    if [ -n "$UI_TOOL" ]; then
        local choice=$(show_menu "Refresh Rate" "Select refresh rate:" \
            "30" "30 Hz" \
            "60" "60 Hz" \
            "90" "90 Hz" \
            "100" "100 Hz" \
            "120" "120 Hz" \
            "144" "144 Hz" \
            "165" "165 Hz" \
            "240" "240 Hz" \
            "custom" "Custom")
        
        if [ "$choice" = "custom" ]; then
            REFRESH=$(show_inputbox "Custom Refresh Rate" "Enter refresh rate (Hz):" "$REFRESH")
        else
            REFRESH="$choice"
        fi
    else
        echo "Refresh Rate Configuration"
        echo "Common rates: 30, 60, 90, 100, 120, 144, 165, 240"
        read -p "Enter refresh rate [$REFRESH]: " new_refresh
        REFRESH="${new_refresh:-$REFRESH}"
    fi
}

# Configure HDR
configure_hdr() {
    if [ -n "$UI_TOOL" ]; then
        if show_yesno "HDR Configuration" "Enable HDR support?"; then
            HDR="true"
            HDR_NITS=$(show_inputbox "HDR Brightness" "Enter HDR target brightness (nits):\n\nCommon values:\n- 400: Standard HDR\n- 600: Mid-range HDR\n- 1000: HDR10\n- 1500: High-end HDR" "$HDR_NITS")
        else
            HDR="false"
        fi
    else
        read -p "Enable HDR support? (y/n) [$HDR]: " hdr_choice
        case $hdr_choice in
            [Yy]) HDR="true" ;;
            [Nn]) HDR="false" ;;
        esac
        
        if [ "$HDR" = "true" ]; then
            echo "HDR Target Brightness (nits)"
            echo "Common values: 400 (standard), 600 (mid), 1000 (HDR10), 1500 (high-end)"
            read -p "Enter HDR nits [$HDR_NITS]: " new_nits
            HDR_NITS="${new_nits:-$HDR_NITS}"
        fi
    fi
}

# Configure autologin
configure_autologin() {
    # Check if LightDM is installed
    if ! command -v lightdm &> /dev/null && [ ! -f /etc/lightdm/lightdm.conf ]; then
        if [ -n "$UI_TOOL" ]; then
            if [ "$UI_TOOL" = "dialog" ]; then
                dialog --title "LightDM Not Found" --msgbox "LightDM is not installed. Autologin configuration requires LightDM.\n\nInstall with: sudo apt install lightdm" 10 60
            else
                whiptail --title "LightDM Not Found" --msgbox "LightDM is not installed. Autologin configuration requires LightDM.\n\nInstall with: sudo apt install lightdm" 10 60
            fi
        else
            echo "Warning: LightDM is not installed. Autologin requires LightDM."
            echo "Install with: sudo apt install lightdm"
        fi
        AUTOLOGIN="false"
        return
    fi
    
    if [ -n "$UI_TOOL" ]; then
        if show_yesno "Autologin Configuration" "Enable autologin to Steam gamescope session?\n\nThis will automatically log in user '$USERNAME' and start the Steam gaming session on boot."; then
            AUTOLOGIN="true"
        else
            AUTOLOGIN="false"
        fi
    else
        echo "Autologin Configuration"
        echo "This will automatically log in user '$USERNAME' to the Steam session on boot."
        read -p "Enable autologin? (y/n) [$AUTOLOGIN]: " autologin_choice
        case $autologin_choice in
            [Yy]) AUTOLOGIN="true" ;;
            [Nn]) AUTOLOGIN="false" ;;
        esac
    fi
}

# Configure advanced options
configure_advanced() {
    if [ -n "$UI_TOOL" ]; then
        local options=$(show_checklist "Advanced Options" "Select features to enable:" \
            "mangoapp" "MangoHud Performance Overlay" $([ "$MANGOAPP" = "true" ] && echo "ON" || echo "OFF") \
            "fsr" "AMD FidelityFX Super Resolution" $([ "$FSR" = "true" ] && echo "ON" || echo "OFF") \
            "fullscreen" "Fullscreen Mode" $([ "$FULLSCREEN" = "true" ] && echo "ON" || echo "OFF"))
        
        # Reset all to false first
        MANGOAPP="false"
        FSR="false"
        FULLSCREEN="false"
        
        # Enable selected options
        for opt in $options; do
            case $opt in
                "\"mangoapp\"") MANGOAPP="true" ;;
                "\"fsr\"") FSR="true" ;;
                "\"fullscreen\"") FULLSCREEN="true" ;;
            esac
        done
        
        # Configure FSR if enabled
        if [ "$FSR" = "true" ]; then
            FSR_LEVEL=$(show_menu "FSR Quality" "Select FSR quality level:" \
                "1" "Ultra Quality" \
                "2" "Quality" \
                "3" "Balanced" \
                "4" "Performance")
        fi
        
        # Configure FPS limit
        FPS_LIMIT=$(show_inputbox "FPS Limit" "Enter FPS limit (0 for unlimited):" "$FPS_LIMIT")
    else
        echo "Advanced Options"
        
        read -p "Enable MangoHud overlay? (y/n) [$MANGOAPP]: " mango_choice
        case $mango_choice in
            [Yy]) MANGOAPP="true" ;;
            [Nn]) MANGOAPP="false" ;;
            *) ;; # Keep current value if no input
        esac
        
        read -p "Enable AMD FSR? (y/n) [$FSR]: " fsr_choice
        case $fsr_choice in
            [Yy]) FSR="true" ;;
            [Nn]) FSR="false" ;;
        esac
        
        if [ "$FSR" = "true" ]; then
            echo "FSR Quality Levels:"
            echo "1) Ultra Quality"
            echo "2) Quality"
            echo "3) Balanced"
            echo "4) Performance"
            read -p "Select FSR level (1-4) [$FSR_LEVEL]: " new_fsr
            FSR_LEVEL="${new_fsr:-$FSR_LEVEL}"
        fi
        
        read -p "Enable fullscreen? (y/n) [$FULLSCREEN]: " fs_choice
        case $fs_choice in
            [Yy]) FULLSCREEN="true" ;;
            [Nn]) FULLSCREEN="false" ;;
        esac
        
        read -p "FPS limit (0 for unlimited) [$FPS_LIMIT]: " new_fps
        FPS_LIMIT="${new_fps:-$FPS_LIMIT}"
    fi
}

# Show configuration summary
show_summary() {
    local summary="Configuration Summary:\n\n"
    summary+="Resolution: ${WIDTH}x${HEIGHT} @ ${REFRESH}Hz\n"
    summary+="HDR: $HDR"
    [ "$HDR" = "true" ] && summary+=" (${HDR_NITS} nits)"
    summary+="\n"
    summary+="MangoHud: $MANGOAPP"
    [ "$MANGOAPP" = "auto" ] && summary+=" (runtime detection)"
    summary+="\n"
    summary+="FSR: $FSR"
    [ "$FSR" = "true" ] && summary+=" (Level $FSR_LEVEL)"
    summary+="\n"
    summary+="Fullscreen: $FULLSCREEN\n"
    summary+="FPS Limit: "
    [ "$FPS_LIMIT" = "0" ] && summary+="Unlimited" || summary+="$FPS_LIMIT"
    summary+="\n"
    summary+="Autologin: $AUTOLOGIN"
    [ "$AUTOLOGIN" = "true" ] && summary+=" (User: $USERNAME)"
    
    if [ -n "$UI_TOOL" ]; then
        if [ "$UI_TOOL" = "dialog" ]; then
            dialog --title "Configuration Summary" --msgbox "$summary" 16 60
        else
            whiptail --title "Configuration Summary" --msgbox "$summary" 16 60
        fi
    else
        echo -e "\n$summary"
    fi
}

# Build gamescope command
build_gamescope_command() {
    local cmd="gamescope"
    
    # Check mode - basic uses minimal configuration
    if [ "$MODE" = "basic" ]; then
        # Basic mode - minimal flags
        if [ "$MANGOAPP" = "true" ] || [ "$MANGOAPP" = "auto" -a "$MANGOAPP_AVAILABLE" = "true" ]; then
            cmd+=" --mangoapp"
        fi
        cmd+=" -e -- steam -steamdeck -steamos3"
        echo "$cmd"
        return
    fi
    
    # Advanced mode - full configuration
    # Resolution and refresh
    cmd+=" -w $WIDTH -h $HEIGHT -r $REFRESH"
    
    # HDR options
    if [ "$HDR" = "true" ]; then
        cmd+=" --hdr-enabled --hdr-itm-target-nits $HDR_NITS"
    fi
    
    # FSR options
    if [ "$FSR" = "true" ]; then
        cmd+=" --fsr-sharpness $FSR_LEVEL"
    fi
    
    # FPS limit
    if [ "$FPS_LIMIT" != "0" ]; then
        cmd+=" --fps-limit $FPS_LIMIT"
    fi
    
    # Fullscreen
    if [ "$FULLSCREEN" = "true" ]; then
        cmd+=" -f"
    fi
    
    # MangoApp (runtime detection for auto mode)
    if [ "$MANGOAPP" = "true" ]; then
        cmd+=" --mangoapp"
    elif [ "$MANGOAPP" = "auto" ] && [ "$MANGOAPP_AVAILABLE" = "true" ]; then
        cmd+=" --mangoapp"
    fi
    
    # Add Steam launch - use simplified flags
    cmd+=" -e -- steam -steamdeck -steamos3"
    
    echo "$cmd"
}

# Mode selection function
select_mode() {
    if [ -n "$UI_TOOL" ]; then
        MODE=$(show_menu "Installation Mode" "Select configuration mode:" \
            "basic" "Basic - Simple Steam gaming session" \
            "advanced" "Advanced - Full configuration with HDR, FSR, etc.")
    else
        echo "Installation Mode:"
        echo "1) Basic - Simple Steam gaming session"
        echo "2) Advanced - Full configuration with HDR, FSR, etc."
        read -p "Select mode (1-2): " mode_choice
        case $mode_choice in
            1) MODE="basic" ;;
            2) MODE="advanced" ;;
            *) MODE="advanced" ;;
        esac
    fi
}

# Main configuration flow
echo "Steam Deck UI Configuration Tool"
echo "================================="
echo

# Load existing config
load_config

# Select mode if not already set
if [ -z "$MODE" ] || [ "$MODE" = "" ]; then
    select_mode
fi

# Main menu loop
while true; do
    # Basic mode has simplified menu
    if [ "$MODE" = "basic" ]; then
        if [ -n "$UI_TOOL" ]; then
            choice=$(show_menu "Basic Gamescope Configuration" "Simple gaming session setup:" \
                "1" "Toggle MangoHud Overlay" \
                "2" "Autologin Settings" \
                "3" "Switch to Advanced Mode" \
                "4" "Apply & Install" \
                "5" "Exit")
        else
            echo
            echo "Basic Mode Menu:"
            echo "1) Toggle MangoHud Overlay (Currently: $MANGOAPP)"
            echo "2) Autologin Settings"
            echo "3) Switch to Advanced Mode"
            echo "4) Apply & Install"
            echo "5) Exit"
            read -p "Select option (1-5): " choice
        fi
        
        case $choice in
            1)
                if [ "$MANGOAPP_AVAILABLE" = "true" ]; then
                    # Toggle between false -> auto -> true -> false
                    if [ "$MANGOAPP" = "false" ]; then
                        MANGOAPP="auto"
                    elif [ "$MANGOAPP" = "auto" ]; then
                        MANGOAPP="true"
                    else
                        MANGOAPP="false"
                    fi
                    echo "MangoHud set to: $MANGOAPP"
                else
                    echo "MangoHud is not installed"
                fi
                ;;
            2)
                configure_autologin
                ;;
            3)
                MODE="advanced"
                continue
                ;;
            4)
                # Jump to installation - will be handled below
                choice="7"
                ;;
            5)
                echo "Exiting without changes."
                exit 0
                ;;
        esac
        
        # Skip rest of loop unless installing
        if [ "$choice" != "7" ]; then
            continue
        fi
    else
        # Advanced mode - full menu
        if [ -n "$UI_TOOL" ]; then
            choice=$(show_menu "Advanced Gamescope Configuration" "Configure your gaming session:" \
                "1" "Resolution & Refresh Rate" \
                "2" "HDR Settings" \
                "3" "Advanced Options" \
                "4" "Autologin Settings" \
                "5" "View Configuration" \
                "6" "Switch to Basic Mode" \
                "7" "Apply & Install" \
                "8" "Exit")
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
            read -p "Select option (1-8): " choice
        fi
    fi
    
    case $choice in
        1)
            configure_resolution
            configure_refresh
            ;;
        2)
            configure_hdr
            ;;
        3)
            configure_advanced
            ;;
        4)
            configure_autologin
            ;;
        5)
            show_summary
            ;;
        6)
            MODE="basic"
            continue
            ;;
        7)
            show_summary
            
            # Confirm installation
            if [ -n "$UI_TOOL" ]; then
                if ! show_yesno "Confirm Installation" "Apply this configuration and install the gaming session?"; then
                    continue
                fi
            else
                read -p "Apply this configuration? (y/n): " confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            
            # Save configuration
            save_config
            
            # Generate gamescope command
            GAMESCOPE_CMD=$(build_gamescope_command)
            
            # Create gamescope script with runtime MangoHud detection
            cat > "$GAMESCOPE_SCRIPT" <<EOF
#!/bin/bash
# Auto-generated by Steam Deck UI Configuration Tool
# Configuration file: $CONFIG_FILE
# Mode: $MODE

# Source configuration for runtime values
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Runtime MangoHud detection for auto mode
MANGOAPP="\${MANGOAPP:-$MANGOAPP}"
if [ "\$MANGOAPP" = "auto" ]; then
    if command -v mangoapp &> /dev/null || command -v mangohud &> /dev/null; then
        MANGOAPP_FLAG="--mangoapp"
    else
        MANGOAPP_FLAG=""
    fi
elif [ "\$MANGOAPP" = "true" ]; then
    MANGOAPP_FLAG="--mangoapp"
else
    MANGOAPP_FLAG=""
fi

EOF
            
            # Generate mode-specific command
            if [ "$MODE" = "basic" ]; then
                cat >> "$GAMESCOPE_SCRIPT" <<'EOF'
# Basic mode - minimal configuration
gamescope ${MANGOAPP_FLAG} -e -- steam -steamdeck -steamos3
EOF
            else
                # Build advanced command with variable substitution
                adv_cmd="gamescope -w $WIDTH -h $HEIGHT -r $REFRESH"
                [ "$HDR" = "true" ] && adv_cmd+=" --hdr-enabled --hdr-itm-target-nits $HDR_NITS"
                [ "$FSR" = "true" ] && adv_cmd+=" --fsr-sharpness $FSR_LEVEL"
                [ "$FPS_LIMIT" != "0" ] && adv_cmd+=" --fps-limit $FPS_LIMIT"
                [ "$FULLSCREEN" = "true" ] && adv_cmd+=" -f"
                
                cat >> "$GAMESCOPE_SCRIPT" <<EOF
# Advanced mode - full configuration
$adv_cmd \${MANGOAPP_FLAG} -e -- steam -steamdeck -steamos3
EOF
            fi
            
            chmod +x "$GAMESCOPE_SCRIPT"
            echo "Gamescope session script installed to $GAMESCOPE_SCRIPT"
            
            # Create other required scripts
            cat > "$EXIT_STEAM_SCRIPT" <<EOF
#!/bin/bash
steam -shutdown
EOF
            chmod +x "$EXIT_STEAM_SCRIPT"
            
            cat > "$NA_OS_SCRIPT" <<EOF
#!/bin/bash
echo "Not applicable for this OS"
EOF
            chmod +x "$NA_OS_SCRIPT"
            
            cat > "$STEAMOS_UPDATE" <<EOF
#!/bin/bash
# No updates available
exit 7
EOF
            chmod +x "$STEAMOS_UPDATE"
            
            cat > "$BIOS_UPDATE" <<EOF
#!/bin/bash
# No BIOS updates
exit 0
EOF
            chmod +x "$BIOS_UPDATE"
            
            # Create timezone script
            cat > "$TIMEZONE_SCRIPT" <<EOF
#!/bin/bash
# Mock timezone setter for SteamOS compatibility
echo "Timezone configuration not applicable on this system"
exit 0
EOF
            chmod +x "$TIMEZONE_SCRIPT"
            
            # Create polkit helpers directory and wrapper scripts
            mkdir -p "$POLKIT_HELPERS_DIR"
            
            # Create wrapper scripts in polkit helpers
            cat > "$POLKIT_HELPERS_DIR/steamos-select-branch" <<EOF
#!/bin/bash
exec /usr/bin/steamos-select-branch "\$@"
EOF
            chmod +x "$POLKIT_HELPERS_DIR/steamos-select-branch"
            
            cat > "$POLKIT_HELPERS_DIR/steamos-update" <<EOF
#!/bin/bash
exec /usr/bin/steamos-update "\$@"
EOF
            chmod +x "$POLKIT_HELPERS_DIR/steamos-update"
            
            cat > "$POLKIT_HELPERS_DIR/jupiter-biosupdate" <<EOF
#!/bin/bash
exec /usr/bin/jupiter-biosupdate "\$@"
EOF
            chmod +x "$POLKIT_HELPERS_DIR/jupiter-biosupdate"
            
            cat > "$POLKIT_HELPERS_DIR/steamos-set-timezone" <<EOF
#!/bin/bash
exec /usr/bin/steamos-set-timezone "\$@"
EOF
            chmod +x "$POLKIT_HELPERS_DIR/steamos-set-timezone"
            
            echo "SteamOS compatibility scripts installed"
            
            # Create steam.desktop session file
            STEAM_DESKTOP="$WAYLAND_SESSIONS_DIR/steam.desktop"
            cat > "$STEAM_DESKTOP" <<EOF
[Desktop Entry]
Encoding=UTF-8
Name=Steam (gamescope)
Comment=Launch Steam within Gamescope
Exec=gamescope-session
Type=WaylandSession
DesktopNames=gamescope
EOF
            
            echo "Steam Gamescope session added to $STEAM_DESKTOP"
            
            # Configure LightDM autologin if requested
            if [ "$AUTOLOGIN" = "true" ]; then
                echo
                echo "Configuring LightDM autologin..."
                
                # Backup existing LightDM configuration
                if [ -f /etc/lightdm/lightdm.conf ]; then
                    cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup.$(date +%Y%m%d_%H%M%S)
                fi
                
                # Create or update LightDM configuration
                mkdir -p /etc/lightdm/lightdm.conf.d/
                cat > /etc/lightdm/lightdm.conf.d/50-gamescope-autologin.conf <<EOF
[Seat:*]
autologin-user=${USERNAME}
autologin-session=steam
autologin-user-timeout=0
EOF
                
                # Ensure user is in autologin group (if it exists)
                if getent group autologin > /dev/null 2>&1; then
                    usermod -a -G autologin $USERNAME
                fi
                
                echo "Autologin configured for user: $USERNAME"
                echo "Session: steam (gamescope)"
                
                # Optional: disable screen lock/screensaver for gaming session
                if [ -d "/home/$USERNAME/.config" ]; then
                    mkdir -p "/home/$USERNAME/.config/autostart"
                    cat > "/home/$USERNAME/.config/autostart/disable-screen-lock.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Disable Screen Lock
Exec=sh -c "xset s off; xset -dpms; xset s noblank"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
                    chown -R $USERNAME:$USERNAME "/home/$USERNAME/.config/autostart"
                fi
            fi
            
            echo
            echo "Installation complete! (Mode: $MODE)"
            echo "You can now:"
            if [ "$AUTOLOGIN" = "true" ]; then
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
            
            if [ "$AUTOLOGIN" = "true" ]; then
                read -p "Would you like to reboot now? (y/n): " reboot_choice
                if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
                    echo "Rebooting..."
                    systemctl reboot
                fi
            fi
            
            exit 0
            ;;
        8)
            echo "Exiting without changes."
            exit 0
            ;;
    esac
done
