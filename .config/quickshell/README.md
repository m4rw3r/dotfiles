# Quickshell Config

Small Quickshell setup with two overlays: an app launcher and a top "shade" panel.

## What it does

- Full-screen app launcher with search and ranked matching
- Multi-screen launcher windows (one per detected screen)
- Simple shade overlay with click-outside-to-close behavior
- IPC handlers so keybinds/scripts can open, close, or toggle UI pieces

## Files

- `shell.qml` - Main shell definition (UI, state, IPC, launcher ranking)

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

## Status

The launcher is functional. The shade is currently a placeholder panel intended for quick controls (battery, performance, volume, brightness, etc.).
