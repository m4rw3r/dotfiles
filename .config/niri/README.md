# Niri

## Goal

- Touch-screen first interface
- Keyboard second
- Use hot-corners/edges for mouse

## Software

- Portal
  - xdg-desktop-portal-gnome
  - xdg-desktop-portal
- Keyring
  - gnome-keyring
- Notifications
  - Built In?
- Background
  - awww
  - And custom systemd
- Auto-idle
  - swayidle
  - And custom systemd
- App launcher
- File-browser
  - nautilus
- Steam
  - xwayland-sattellite

## On Screen Keyboard

- Z13 does not have a tablet switch built in
  - We use a custom rust service to provide the tablet switch signal
    - `~/Projects/Z13/z13-tablet-switch`
    - Managed by system-wide systemd to provide this switch all the time
- We have a user systemd service defined as `on-screen-keyboard.service`
  - It is not enabled by default since we do not want it running all the time
    - Sysboard always shows otherwise
- Niri then listens to these events and starts and stops this service
```
switch-events {
    tablet-mode-on {
        spawn "bash" "-lc" "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true; systemctl --user start on-screen-keyboard;"
    }
    tablet-mode-off {
        spawn "bash" "-lc" "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false; systemctl --user stop on-screen-keyboard;"
    }
}

