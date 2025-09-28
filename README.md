# Steam Deck UI Configuration Tool

A comprehensive configuration tool for setting up a Steam gaming session with Gamescope on Linux systems, providing a Steam Deck-like gaming experience on regular desktop Linux distributions.

## Overview

This tool automates the setup of a dedicated Steam gaming session using Gamescope compositor, allowing you to transform your Linux desktop into a console-like gaming experience similar to the Steam Deck. It provides both basic and advanced configuration modes to suit different user needs.

## Features

### Two Configuration Modes

- **Basic Mode**: Simple, quick setup with minimal configuration for users who want to get gaming fast
- **Advanced Mode**: Full control over display settings, performance features, and visual enhancements

### Display Configuration
- Custom resolution settings with presets (Steam Deck, 720p, 1080p, 1440p, 4K)
- Refresh rate configuration (30Hz to 240Hz)
- HDR support with customizable brightness targets
- Fullscreen/windowed mode selection

### Performance Features
- AMD FidelityFX Super Resolution (FSR) with quality levels
- FPS limiting for consistent performance
- MangoHud overlay integration for performance monitoring
- Runtime detection of available features

### System Integration
- Automatic session creation for display managers
- LightDM autologin configuration
- SteamOS compatibility layer for Steam Deck features
- Configuration persistence and management

## Requirements

### Essential Dependencies
- Linux-based operating system
- Root/sudo access for installation
- Steam client installed
- Gamescope compositor
- Wayland session support

### Optional Dependencies
- **MangoHud**: For performance overlay (automatically detected)
- **LightDM**: For autologin functionality
- **dialog or whiptail**: For enhanced UI (falls back to text mode if not available)

## Installation

1. Download the script to your system
2. Make it executable:
   ```bash
   chmod +x steamdeck-ui-config.sh
   ```
3. Run with sudo:
   ```bash
   sudo ./steamdeck-ui-config.sh
   ```

## Usage

### First Run

On first run, the tool will:
1. Check for required dependencies
2. Detect available optional components
3. Present you with a mode selection (Basic or Advanced)
4. Guide you through configuration
5. Install the gaming session

### Basic Mode

Basic mode provides a streamlined setup process with just essential options:
- Toggle MangoHud overlay (if available)
- Configure autologin
- Quick apply and install

Perfect for users who want a "just works" gaming experience.

### Advanced Mode

Advanced mode offers complete control over:
- **Resolution & Refresh**: Set custom display parameters
- **HDR Settings**: Enable HDR with target brightness configuration
- **Performance Options**: FSR, FPS limits, MangoHud
- **System Settings**: Autologin, fullscreen mode

### Configuration Files

The tool saves your configuration to:
```
~/.config/gamescope/gamescope.conf
```

This allows you to:
- Re-run the tool to modify settings
- Manually edit configuration if needed
- Maintain consistent settings across updates

## Post-Installation

After successful installation:

### With Autologin Enabled
- Reboot your system to automatically start in gaming mode
- OR log out and select "Steam (gamescope)" from your display manager

### Without Autologin
1. Log out of your current session
2. Select "Steam (gamescope)" from your display manager's session menu
3. Log in to start your gaming session

## Configuration Options

### Display Settings
- **Resolution**: Common presets or custom values
- **Refresh Rate**: 30-240Hz with custom option
- **HDR**: Enable/disable with brightness targets (400-1500 nits)

### Performance Settings
- **FSR Levels**:
  - Ultra Quality (Level 1)
  - Quality (Level 2)
  - Balanced (Level 3)
  - Performance (Level 4)
- **FPS Limit**: Set target framerate or unlimited
- **MangoHud**: Off, Auto-detect, or Always on

### System Settings
- **Fullscreen**: Toggle fullscreen/windowed mode
- **Autologin**: Automatic session start on boot
- **Session Type**: Wayland-based Gamescope session

## Troubleshooting

### Common Issues

**Steam doesn't launch**
- Ensure Steam is installed: `sudo apt install steam`
- Check if Steam runs normally in desktop mode first

**Black screen on session start**
- Verify Gamescope is installed: `sudo apt install gamescope`
- Try Basic mode first for minimal configuration
- Check system logs: `journalctl -xe`

**MangoHud not showing**
- Install MangoHud: `sudo apt install mangohud`
- Set MangoHud to "true" instead of "auto" in configuration

**Autologin not working**
- Ensure LightDM is installed and set as display manager
- Check `/etc/lightdm/lightdm.conf.d/50-gamescope-autologin.conf`
- Verify user is in autologin group: `groups $USER`

### Getting Help

- Re-run the configuration tool to adjust settings
- Check configuration file: `~/.config/gamescope/gamescope.conf`
- View session script: `/usr/bin/gamescope-session`
- System logs: `journalctl -u lightdm` (for autologin issues)

## Uninstallation

To remove the gaming session:

1. Remove session files:
   ```bash
   sudo rm /usr/bin/gamescope-session
   sudo rm /usr/bin/steamos-*
   sudo rm /usr/bin/jupiter-biosupdate
   sudo rm -rf /usr/bin/steamos-polkit-helpers
   sudo rm /usr/share/wayland-sessions/steam.desktop
   ```

2. Remove autologin configuration (if enabled):
   ```bash
   sudo rm /etc/lightdm/lightdm.conf.d/50-gamescope-autologin.conf
   ```

3. Remove user configuration:
   ```bash
   rm ~/.config/gamescope/gamescope.conf
   ```

## Compatibility

### Tested Distributions
- Ubuntu 22.04/24.04
- Debian 11/12
- Fedora 38+
- Arch Linux
- Pop!_OS 22.04

### Display Managers
- LightDM (full support with autologin)
- GDM (session selection only)
- SDDM (session selection only)

## Contributing

This tool is designed to be distribution-agnostic. When reporting issues, please include:
- Linux distribution and version
- Display manager in use
- Output of dependency check (shown at script start)
- Any error messages encountered

## License

This tool is provided as-is for the Linux gaming community. Feel free to modify and distribute according to your needs.

## Acknowledgments

- Valve for Steam and the Steam Deck gaming experience
- Gamescope developers for the excellent compositor
- MangoHud team for the performance overlay
- The Linux gaming community for continued support and feedback