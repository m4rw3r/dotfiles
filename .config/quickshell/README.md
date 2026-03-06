# Quickshell Config

Small Quickshell setup with two overlays: an app launcher and a top control panel.

## What it does

- Full-screen app launcher with search and ranked matching
- Multi-screen launcher windows (one per detected screen)
- Theme-aware control panel with runtime theme switching
- Widget gallery overlay for previewing reusable controls and patterns
- Shared styling primitives for consistent surfaces and text
- IPC handlers so keybinds/scripts can open, close, or toggle UI pieces

## Files

- `shell.qml` - Main shell definition (UI windows + IPC wiring)
- `Launcher.qml` - Launcher logic and UI
- `ControlCenter.qml` - Shade/control panel content
- `WidgetGallery.qml` - Scrollable gallery for the shared widget library
- `WidgetGalleryWindow.qml` - Overlay window wrapper for the gallery
- `theme/Theme.qml` - Singleton design tokens + theme persistence
- `ui/primitives/*.qml` - Reusable styled widgets
- `ui/controls/*.qml` - Shared interactive controls
- `ui/patterns/*.qml` - Reusable higher-level UI patterns

## Widget library

- `ui/primitives/` holds low-level styling pieces like text, surfaces, scrims, and icons.
- `ui/controls/` holds reusable interactive widgets like buttons, sliders, menus, toggles, and icon buttons.
- `ui/patterns/` holds higher-level composed widgets like quick tiles.
- `WidgetGallery.qml` is the design sandbox for checking states, spacing, tones, and behavior without opening the full control center.

## IPC targets

`ui`
- `toggleShade()`
- `openShade()`
- `closeShade()`

`launcher`
- `toggle()`
- `open()`
- `close()`
- `search(query: string)`

`theme`
- `current()`
- `list()`
- `set(name)`
- `toggle()`

`gallery`
- `toggle()`
- `open()`
- `close()`

## Previewing the gallery

From a shell, you can open or toggle the gallery directly:

```bash
qs ipc call gallery open
qs ipc call gallery toggle
qs ipc call gallery close
```

The gallery opens as its own overlay and automatically closes the launcher or shade if either is visible.

## Niri bind example

Add a bind like this to `~/.config/niri/config.kdl`:

```kdl
binds {
    Mod+Shift+G { spawn "qs" "ipc" "call" "gallery" "toggle"; }
}
```

Then reload Niri:

```bash
niri msg action reload-config
```

## Gallery contents

- Theme tone swatches and core typography samples
- Shared button and icon-button states
- Toggle states with live interaction
- Slider variants for media, brightness, and stepped values
- Menu and menu-item examples for popovers and selection lists
- Quick-tile patterns that mirror the control center split-action layout

## Status

Launcher, control panel, and widget gallery are functional. Theme state persists across Quickshell reloads and can be changed from IPC, the control panel, or the gallery.
