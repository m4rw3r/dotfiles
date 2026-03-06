# Quickshell Config

Small Quickshell setup with two overlays: an app launcher and a top control panel.

## What it does

- Full-screen app launcher with search and ranked matching
- Multi-screen launcher windows (one per detected screen)
- Theme-aware control panel with runtime theme switching
- Shared styling primitives for consistent surfaces and text
- IPC handlers so keybinds/scripts can open, close, or toggle UI pieces

## Files

- `shell.qml` - Main shell definition (UI windows + IPC wiring)
- `Launcher.qml` - Launcher logic and UI
- `ControlCenter.qml` - Shade/control panel content
- `theme/Theme.qml` - Singleton design tokens + theme persistence
- `ui/primitives/*.qml` - Reusable styled widgets

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

## Status

Launcher and control panel are functional. Theme state persists across Quickshell reloads and can be changed from IPC or the control panel chips.
