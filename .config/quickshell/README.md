# Quickshell Config

Small Quickshell setup with two overlays: an app launcher and a top control panel.

## What it does

- Full-screen app launcher with search and ranked matching
- Multi-screen launcher windows (one per detected screen)
- Theme-aware control panel with runtime theme switching
- Hidden-on-demand system tray rail with attention peek + control-center companion mode
- Widget gallery overlay for previewing reusable controls and patterns
- Shared styling primitives for consistent surfaces and text
- IPC handlers so keybinds/scripts can open, close, or toggle UI pieces

## Files

- `shell.qml` - Main shell definition (UI windows + IPC wiring)
- `Launcher.qml` - Launcher logic and UI
- `ControlCenter.qml` - Shade/control panel content
- `TrayRail.qml` - Vertical tray rail used as a top-right peek or beside the control center
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
- `toggleControlCenter()`
- `showControlCenter()`
- `hideControlCenter()`

`tray`
- `toggle()`
- `open()`
- `peek()`
- `close()`

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

## Tray behavior

- The tray is hidden by default and only peeks into the top-right corner when attention is needed or when forced through IPC.
- Tapping the peek opens the tray rail by itself; it does not open the control center.
- If the control center opens while the tray is visible, the tray shifts left and becomes a companion rail beside it.
- If the tray was opened from the peek, closing the control center leaves the tray expanded in the top-right corner.
- If the tray was opened only from the control-center button, closing the control center collapses it back to a peek or hides it.
- In expanded mode, menu-capable tray items expose a separate menu affordance so the default action and the context menu are both reachable.

From a shell, you can exercise the tray directly:

```bash
qs ipc call tray peek
qs ipc call tray open
qs ipc call tray close
qs ipc call tray toggle
```

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
