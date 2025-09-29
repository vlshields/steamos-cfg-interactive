# Steam Deck UI Configuration Tool

An interactive TUI/GUI for setting up a standalone desktop session with Gamescope and Steam. It can be used to configure a Steam Deck-like gaming experience on any Linux distribution (assuming it is intended for desktop use, of course).


## Configuration Options

#### Gamescope

The script provides several configuration options relating to the Valve's microcompositer [Gamescope](https://github.com/ValveSoftware/gamescope).
The gamescope options include:

- Resolution presets (Steam Deck, 720p, 1080p, 1440p, 4K) or custom
- Refresh rate configuration (30Hz to 240Hz)
- HDR support with customizable brightness targets
- Fullscreen/windowed mode selection
- AMD FidelityFX Super Resolution (FSR) with quality levels
- FPS limiting for consistent performance
- MangoHud overlay integration for performance monitoring
- Runtime detection of available features

#### Autologin

Since the goal is to *optionally* provide a couch-gaming experience, there is also an option to configure automatic login.
**Important**: For simplicity, this script assumes the user has lightdm installed. Lightdm is a popular display manager that is relatively
light on resources. Although Lightdm is prefered, any display manager that supports the Wayland Protocol should work. You can set this up by editing the configure_autologin() function. 

Please be aware that enabling autologin may not be desirable as it disables user authentication. Note that this is only true for the steam session; switching to desktop mode will still prompt the user to enter their password (unless otherwise configured).


## Requirements


- [MangoHud](https://github.com/flightlessmango/MangoHud)
- [LightDM](https://github.com/canonical/lightdm)
- Official Steam client.
- [Gamescope](https://github.com/ValveSoftware/gamescope)
- An AMD GPU and related drivers are highly recommended

## Usage


   ```bash
   git clone https://github.com/vlshields/steamos-cfg-interactive.git
   cd steamos-cfg-interactive
   chmod +x steamos_cfg_interactive.sh
   sudo ./steamos_cfg_interactive.sh
   ```

## Troubleshooting

### Common Issues

**Cannot get past SteamOS setup**

Sign into and launch Steam in your deskopt envoronment of choice and *exit steam*. Re-run the script.


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

