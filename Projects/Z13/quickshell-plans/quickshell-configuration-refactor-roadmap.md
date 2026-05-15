# Refactor Quickshell Configuration In Staged Milestones

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan is self-contained. The Quickshell configuration root is `/home/m4rw3r/.config/quickshell`, and all commands in this plan assume that directory unless another working directory is explicitly named. Existing related plans live in `/home/m4rw3r/Projects/Z13/quickshell-plans`, but this document includes enough context to implement the refactor without reading them first.

## Purpose / Big Picture

The current Quickshell configuration works, but several files now combine global state coordination, service orchestration, command execution, and UI rendering in one place. After this refactor, the shell should behave the same to the user while being easier to change safely: opening the launcher, control center, tray, notifications, and volume overlay should still work, but the logic behind them should be split into focused components with clearer ownership.

The user-visible improvement is lower regression risk. It should become straightforward to modify a Wi-Fi popover, a quick tile, a notification toast, or a launcher tile without touching unrelated session, tray, audio, or global overlay state. Success is demonstrated by the same live behavior as today, verified through `qmllint` and manual IPC checks, with less duplicated styling and fewer oversized QML files.

## Progress

- [x] (2026-05-15 00:00Z) Plan written from a read-only review of the current Quickshell configuration.
- [x] (2026-05-15 10:47Z) Captured the baseline lint state with the full `qmllint -I . *.qml controlcenter/*.qml services/*.qml ui/primitives/*.qml ui/controls/*.qml ui/patterns/*.qml theme/*.qml icons/*.qml` command; it produced no output.
- [x] (2026-05-15 10:51Z) Fixed the small behavior bugs that are independent of larger structural changes: keyboard brightness detection, brightness slider pending value, toast suspension, lighting command validation, power profile error reporting, and notification focus fallback.
- [x] (2026-05-15 10:57Z) Extracted global shell controllers from `shell.qml` into `SessionActionController.qml`, `SessionActionBanner.qml`, `VolumeOverlayController.qml`, and `TrayStateController.qml`, then centralized overlay exclusivity through `activeOverlay` while preserving IPC target names.
- [x] (2026-05-15 11:03Z) Split `ControlCenter.qml` into focused popovers and footer components: `controlcenter/BluetoothPopover.qml`, `OutputsPopover.qml`, `PowerPopover.qml`, and `NotificationFooter.qml`, while keeping `WifiPopover.qml` and `NotificationsPopover.qml` as existing extracted components.
- [x] (2026-05-15 11:05Z) Centralized control-center section transitions through `setExpandedSection`, `openSection`, `closeSection`, `toggleSection`, `closeCurrentSection`, and `returnFromNotifications`; direct `expandedSection =` assignments now remain only in the helper and panel-close reset.
- [x] (2026-05-15 11:09Z) Split `Launcher.qml` into `LauncherSearchModel.qml`, `FocusedOutputResolver.qml`, `LauncherPager.qml`, and `LauncherTile.qml` while preserving launcher IPC and entry launching behavior.
- [x] (2026-05-15 11:12Z) Consolidated UI-library styling primitives by adding semantic border and overlay tokens to `theme/Theme.qml`, migrating quick-tile/button border decisions to theme tokens, and keeping `MenuItem.qml` and `PopoverMenuAction.qml` standalone for runtime compatibility.
- [x] (2026-05-15 11:16Z) Validated the final state with full `qmllint` and live IPC smoke checks without restarting Quickshell.
- [x] (2026-05-15 13:42Z) Verified the running Quickshell instance actually hot-reloaded the fixed configuration; the journal showed `INFO: Configuration Loaded` and no new `Failed to load configuration` entries after the runtime row-component fix.

## Surprises & Discoveries

- Observation: `ControlCenter.qml` is the largest refactor target because it mixes service instances, process execution, section state, notification state, audio and brightness buffering, quick-tile layout, and popover rendering.
  Evidence: `/home/m4rw3r/.config/quickshell/ControlCenter.qml` is 1723 lines; service instances are at lines 603-628, process runners at lines 630-694, sliders at lines 869-976, quick tiles and notification footer at lines 1001-1255, and popovers at lines 1260-1721.
- Observation: `shell.qml` coordinates too many independent global systems.
  Evidence: tray state lives at lines 17-22 and 89-125, volume overlay state at lines 23-31 and 52-87, session action controller and banner at lines 208-459, IPC handlers at lines 487-575, and top-level windows at lines 586-795.
- Observation: `Launcher.qml` combines model logic, display selection, OSK lifecycle, keyboard navigation, paging, drag gestures, and tile rendering.
  Evidence: search/ranking is at lines 180-249, focused-output lookup at lines 121-158 and 251-267, navigation at lines 427-558, paging and drag state at lines 856-976, and tile rendering at lines 999-1084.
- Observation: Several small behavior bugs should be fixed before broader movement so later refactors have a stable baseline.
  Evidence: `services/BrightnessService.qml` gates the initial keyboard refresh on `keyboardAvailable`, but `keyboardAvailable` needs `keyboardMax > 0`; `ControlCenter.qml` binds brightness slider value to `brightnessService.screenPercent` while pending writes use `pendingScreenBrightness`; `NotificationToastStack.qml` accepts `suspended` but its auto-dismiss timer still runs while hidden.
- Observation: UI styling is already organized into `theme`, `ui/primitives`, `ui/controls`, and `ui/patterns`, but many controls still hard-code translucent white borders.
  Evidence: `Qt.rgba(1, 1, 1, ...)` appears in 34 QML locations, including `Button.qml`, `IconButton.qml`, `QuickTileFrame.qml`, `QuickToggleTile.qml`, `QuickSelectorTile.qml`, `QuickToggleMenuTile.qml`, `HeroSheetPopover.qml`, `TrayRail.qml`, `VolumeOverlay.qml`, and notification popovers.
- Observation: The current QML is lint-clean before this refactor plan.
  Evidence: running `qmllint -I . *.qml controlcenter/*.qml services/*.qml ui/primitives/*.qml ui/controls/*.qml ui/patterns/*.qml theme/*.qml icons/*.qml` from `/home/m4rw3r/.config/quickshell` produced no output during plan preparation.
- Observation: The final refactor remains lint-clean after adding new controller and component files.
  Evidence: running `qmllint -I . *.qml controlcenter/*.qml services/*.qml ui/primitives/*.qml ui/controls/*.qml ui/patterns/*.qml theme/*.qml icons/*.qml` from `/home/m4rw3r/.config/quickshell` at 2026-05-15 11:16Z produced no output.
- Observation: `qmlformat` defaults to four-space indentation and can create noisy diffs against this configuration's two-space style.
  Evidence: a broad formatting pass was re-run with `qmlformat -w 2 -i ...` and accidental formatting-only changes to unrelated service/control files were backed out before final validation.
- Observation: `FocusedOutputResolver.request()` must not emit `resolved` synchronously before `Launcher.qml` stores the returned request id.
  Evidence: the zero-screen fallback now uses `Qt.callLater()` and returns the local request id so `finishPendingLauncherOpen()` compares against the correct pending id.
- Observation: `qmllint` can pass a same-directory wrapper component that Quickshell fails to resolve during hot reload.
  Evidence: `MenuItem.qml` and `PopoverMenuAction.qml` as `ActionRow` wrappers linted cleanly, but the running journal reported `ActionRow is not a type`, causing `ControlCenter unavailable`; restoring both files as standalone components fixed the load failure.
- Observation: `TrayStateController.refresh()` must tolerate `SystemTray.items.count` being undefined during early evaluation.
  Evidence: after the first successful reload, the journal reported `@TrayStateController.qml[39:-1]: Error: Cannot assign [undefined] to int`; coercing the count with `Number(SystemTray.items.count || 0)` removed the warning on the next reload.

## Decision Log

- Decision: Start with behavior fixes before large file movement.
  Rationale: Small independent bugs are easier to verify in the current structure. Fixing them first reduces uncertainty when later extracting components.
  Date/Author: 2026-05-15 / OpenCode
- Decision: Preserve existing visual behavior and IPC targets during the first structural pass.
  Rationale: This is a refactor, not a redesign. Existing IPC targets such as `ui`, `tray`, `launcher`, `theme`, `gallery`, and `volume` are already used by keybinds and scripts, so changing them would create avoidable external breakage.
  Date/Author: 2026-05-15 / OpenCode
- Decision: Prefer controller components over broad singleton conversion for UI-only state.
  Rationale: Long-lived hardware state may become singletons, but transient UI state such as the active control-center section or launcher page should stay owned by the UI surface that displays it.
  Date/Author: 2026-05-15 / OpenCode
- Decision: Centralize styling through theme tokens and shared row/tile primitives rather than rewriting every control independently.
  Rationale: The biggest UI-library duplication is repeated active, pressed, hover, and border logic. Tokens and shared primitives reduce churn while keeping component names stable.
  Date/Author: 2026-05-15 / OpenCode
- Decision: Keep `ControlCenter.qml` as the first-pass controller for control-center popovers instead of introducing a separate section singleton.
  Rationale: The extracted popovers already accept a `controller` property, and keeping the existing owner avoids designing a broader interface before behavior is proven stable.
  Date/Author: 2026-05-15 / OpenCode
- Decision: Keep `MenuItem.qml` and `PopoverMenuAction.qml` as standalone components instead of thin wrappers over a new `ActionRow.qml` for this pass.
  Rationale: Quickshell's runtime loader failed to resolve the wrapper root type during hot reload even though `qmllint` accepted it. Standalone files preserve behavior and load reliably; future row unification should be tested against the live loader before replacing these files.
  Date/Author: 2026-05-15 / OpenCode

## Outcomes & Retrospective

Implemented on 2026-05-15. The refactor keeps the same public IPC targets while moving session actions, volume HUD state, tray state, launcher search, focused-output resolution, launcher paging/tile rendering, control-center popovers, and notification footer rendering into focused QML files. Shared visual constants moved into theme tokens; action rows remain standalone because the attempted wrapper extraction was rejected by the live Quickshell loader.

Validation passed with the full `qmllint` command and these live IPC smoke checks, all run from `/home/m4rw3r/.config/quickshell` without restarting Quickshell: `qs ipc call ui showControlCenter`, `qs ipc call ui hideControlCenter`, `qs ipc call tray peek`, `qs ipc call tray open`, `qs ipc call tray close`, `qs ipc call launcher open`, `qs ipc call launcher close`, `qs ipc call gallery open`, `qs ipc call gallery close`, and `qs ipc call volume flash`. The commands produced no terminal output, which is the expected success behavior for these IPC methods. The user journal was also checked after a forced hot reload; it showed `INFO: Configuration Loaded` at 2026-05-15 13:42:08 CEST and no fresh configuration-load errors.

`ControlCenter.qml`, `Launcher.qml`, and `shell.qml` are still important composition files, but they no longer own every major state machine and UI subtree directly. The remaining size in `ControlCenter.qml` is intentional for this pass because it still owns service instances and tile-level orchestration; the new popover boundaries make later narrowing of controller inputs much safer.

## Context and Orientation

The Quickshell configuration is a QML shell under `/home/m4rw3r/.config/quickshell`. QML is Qt's declarative UI language. A `PanelWindow` is a Quickshell-managed layer-shell window; in this config, top-level panel windows host the launcher, control center, tray rail, notification toasts, volume overlay, and widget gallery. An `IpcHandler` exposes methods callable from `qs ipc call ...`, which is how keybinds and scripts open or close shell surfaces.

The current top-level entry point is `shell.qml`. It creates global state properties, IPC handlers, and top-level windows. It instantiates `Launcher.qml`, `NotificationCenter.qml`, `ControlCenter.qml`, `TrayRail.qml`, `VolumeOverlay.qml`, and `WidgetGalleryWindow.qml`. The current IPC targets documented in `README.md` are `ui`, `tray`, `launcher`, `theme`, and `gallery`; `shell.qml` also exposes `volume.flash()`.

`ControlCenter.qml` is the main shade panel. A shade is the top-right control-center panel that appears over the desktop. It currently owns services from `services/*.qml`, panel-local state such as `expandedSection`, inline process runners for power profile, on-screen keyboard, and keyboard recovery, plus all quick tiles and popovers. A popover is a small temporary panel opened from a tile or button, such as Wi-Fi, Bluetooth, outputs, power, notifications, profile, and lighting.

`Launcher.qml` is a full-screen app launcher. It reads `DesktopEntries.applications.values`, ranks entries against a search query, resolves the currently focused output through `niri msg -j focused-output`, manages on-screen-keyboard fallback behavior, implements keyboard navigation and swipe paging, and renders application tiles.

The service files under `services/` wrap machine state. `WifiService.qml` currently shells out to `nmcli`, `BrightnessService.qml` shells out to `brightnessctl`, `LightingService.qml` reads state from `z13ctl`, and `BluetoothService.qml` uses Quickshell Bluetooth objects plus `/sys/class/rfkill` shell reads. Existing separate ExecPlans cover a larger Wi-Fi service rewrite and popup-window work; this plan includes only the parts needed to order the broader refactor.

The UI library is already partly layered. `theme/Theme.qml` is a singleton containing colors, spacing, sizing, and motion tokens. `ui/primitives` contains low-level display pieces such as `UiSurface`, `UiText`, `UiIcon`, `ResolvedIconImage`, and `UiScrim`. `ui/controls` contains buttons, sliders, toggles, menus, and popover rows. `ui/patterns` contains higher-level patterns such as quick tiles and hero-sheet popovers.

## Plan of Work

Begin with behavior fixes that are narrow and easy to validate. In `services/BrightnessService.qml`, split keyboard device detection from keyboard brightness availability so the first `brightnessctl -m -d <keyboardDevice>` read can run after a keyboard backlight device is detected. A suitable shape is `readonly property bool keyboardDeviceAvailable: keyboardDevice !== ""` and `readonly property bool keyboardAvailable: keyboardDeviceAvailable && keyboardMax > 0`; `refreshKeyboard()` should use the device-available check, while `applyKeyboardValue()` can keep using `keyboardAvailable` if writes need a known maximum.

In `ControlCenter.qml`, make the brightness slider mirror the audio slider's pending-write behavior. `pendingScreenBrightness` is already updated from `BrightnessService.onScreenPercentChanged` when the commit timer is not running. Change the slider value at line 965 from `brightnessService.screenPercent` to `root.pendingScreenBrightness` so dragging does not visually snap back while `brightnessctl` writes and refreshes lag.

In `NotificationToastStack.qml`, make suspension real. The `suspended` property should stop auto-dismiss timers while the toast window is hidden by `shell.qml` because the shade, gallery, or launcher is visible. The timer in `ToastCard` should run only when `!card.suspended`. If the design should preserve each toast's remaining time, move toast expiration from an absolute `toastExpiresAt` timestamp to a stored remaining-duration model, or at minimum do not call `dismissIfExpired()` on `onSuspendedChanged` when suspension just ended. The observable target is that a toast hidden behind the shade is still present when the shade closes unless its live notification was explicitly dismissed.

Still in the behavior-fix milestone, remove shell interpolation from `services/LightingService.qml`. `applyLevel(nextLevel)` accepts a public string and currently runs `zsh -lc` with interpolation. Validate `nextLevel` against `off`, `low`, `medium`, and `high`, then run `lightingWriteProcess.exec(["z13ctl", "brightness", validatedLevel])`. If the value is invalid, set `lastError` and return without running a command.

Also fix silent process failures before structural movement. In `ControlCenter.qml`, the `powerProfileWriteProcess` exit handler should inspect `exitCode` and `powerProfileWriteStderr.text`. On failure, set a visible error message or reuse an existing failure-banner pattern rather than clearing `powerProfileBusy` silently. In `NotificationCenter.qml`, `requestEntryFocus()` should not drop focus requests while `focusLookupBusy` is true; it can replace the pending request with the latest uid/window pair or queue exactly one latest request. If the niri window lookup fails or the window no longer exists, fall back to `invokePrimaryAction(entry)` when a primary action exists, or at least mark the item read only when an action actually happens.

After those fixes, extract global controllers from `shell.qml`. Create `SessionActionController.qml` and `SessionActionBanner.qml` near the top-level QML files or under a new `controllers/` and `ui/patterns/` split if preferred. Preserve the public methods `run(action)`, `retry()`, and `dismissError()` and the properties consumed by `ControlCenter.qml`: `busyAction`, `busy`, `errorVisible`, and `bannerVisible`. Move the current embedded component code from `shell.qml` lines 208-459 without changing behavior. Lint `shell.qml` after this move.

Next extract the volume overlay state machine from `shell.qml`. Keep `VolumeOverlay.qml` as the visual HUD because it is already focused and small. Add a controller component, for example `VolumeOverlayController.qml`, that accepts the current `Pipewire.defaultAudioSink` or imports Pipewire itself, tracks `value`, `muted`, and `active`, and exposes `flash()`. Move the logic now in `shell.qml` lines 23-31, 48-87, and 138-166 into that controller. `shell.qml` should instantiate the controller and bind `VolumeOverlay.value`, `muted`, and `active` to it. `IpcHandler target: "volume"` should call the controller's `flash()` method.

Then extract tray state from `shell.qml` and `TrayRail.qml` into a single source of truth. The current shell has an `Instantiator` to count attention items, and `TrayRail.qml` separately scans `SystemTray.items` for urgent, active, and passive counts. Create a `TrayStateController.qml` or `TrayModel.qml` that owns `mode`, `userPinned`, `peekForced`, `attentionCount`, `activeCount`, `passiveCount`, and `hasItems`. It should expose methods equivalent to the current shell functions: `collapseToPeekOrHidden()`, `openFromPeek()`, `openFromControlCenter()`, `toggleFromControlCenter()`, `forcePeek()`, and `close()`. Bind both standalone and companion `TrayRail` instances to this single controller. `TrayRail.qml` should receive the counts or model from the controller rather than recomputing them independently.

Once root controllers are extracted, simplify overlay exclusivity. Today `shadeOpen`, `galleryOpen`, and `launcher.launcherOpen` close each other through manual callbacks. Introduce a single string property such as `activeOverlay` in `shell.qml` or an `OverlayController.qml`. Define possible values in prose and code comments as `""`, `"controlCenter"`, `"launcher"`, and `"gallery"`. `openControlCenter()` sets `activeOverlay = "controlCenter"`, launcher opening sets it to `"launcher"`, gallery opening sets it to `"gallery"`, and closing a surface clears it only if that surface is current. Keep compatibility properties such as `readonly property bool shadeOpen: activeOverlay === "controlCenter"` if that makes the migration smaller. The acceptance behavior is that only one fullscreen overlay is open at a time, just as today, but the rules are centralized.

After `shell.qml` is smaller, split `ControlCenter.qml`. Start by extracting the already-separate `controlcenter/WifiPopover.qml` and `controlcenter/NotificationsPopover.qml` pattern further: create `controlcenter/BluetoothPopover.qml`, `controlcenter/PowerPopover.qml`, `controlcenter/OutputsPopover.qml`, and `controlcenter/NotificationFooter.qml`. Move only UI and local helper text into those files; keep service instances and high-level panel state in `ControlCenter.qml` until the popover extraction is stable. Each new component should receive a `controller` property, matching the existing `WifiPopover.qml` shape, so initial extraction does not require designing a large new interface.

Then centralize control-center section transitions. Replace direct assignments to `expandedSection` outside a few helper functions with named methods such as `openSection(section)`, `closeSection(section)`, `toggleSection(section)`, `closeCurrentSection()`, and `returnFromNotifications()`. The helper should own side effects such as clearing Wi-Fi password state, clearing `pendingPowerAction`, refreshing Wi-Fi when the Wi-Fi menu opens, refreshing Bluetooth rfkill state when Bluetooth opens, and stopping Bluetooth discovery when Bluetooth closes. After this change, grep for `expandedSection =` and expect only the section-controller helpers and panel-close reset to assign it.

Split `Launcher.qml` after the control center is stable. Create a search/ranking component or helper file first. It should own `launcherResults`, `launcherResultLimit`, `normalizeText()`, `launcherEntryKey()`, and `refreshLauncherResults()`, and it should observe `DesktopEntries.applications`. The public surface should be minimal: input `query`, output `results`, and method `refresh()`. Keep result row objects as existing DesktopEntry objects so `launchCommand(entry)` does not need to change at the same time.

Next extract focused-output resolution from `Launcher.qml`. This code currently tracks screen names and request ids and shells out to `niri msg -j focused-output`. Move it into a component such as `FocusedOutputResolver.qml` with a method `request(callback)` or properties `activeScreen`, `pendingRequestId`, and signal `resolved(screen)`. Preserve the 90ms fallback behavior initially, but document if live testing shows it is too short. This makes screen selection testable without touching tile rendering.

Then extract launcher pager navigation and tile rendering. A `LauncherPager.qml` component can own columns, rows, page, selected index, keyboard navigation, swipe drag behavior, and page arrows. A `LauncherTile.qml` component can own the visual tile with `ResolvedIconImage`, app name, generic name, pressed state, and selected animation. The launcher root should coordinate query, active screen, OSK behavior, and launching, while the pager handles movement and selection.

Finally consolidate UI-library duplication. Add semantic theme tokens in `theme/Theme.qml`, such as `borderSubtle`, `borderStrong`, `overlayHover`, `overlayPressed`, and `overlayActive`, deriving them from current palettes or helper functions. Replace repeated `Qt.rgba(1, 1, 1, 0.08)`, `0.12`, `0.14`, and `0.16` values with these tokens. Add a shared interactive surface primitive or resolver so `Button.qml`, `IconButton.qml`, `QuickToggleTile.qml`, `QuickSelectorTile.qml`, and `QuickToggleMenuTile.qml` all ask the same logic for active, pressed, open, and disabled colors.

In the same UI-library milestone, merge or unify `ui/controls/MenuItem.qml` and `ui/controls/PopoverMenuAction.qml`. They are both action rows with title, optional subtitle, optional trailing action text, optional trailing icon, active state, pressed background, and click signal. Create a single component, for example `ActionRow.qml` or `MenuRow.qml`, and migrate call sites gradually. Keep `MenuItem.qml` and `PopoverMenuAction.qml` as thin wrappers only if a one-shot migration would create too much churn; remove wrappers once call sites are migrated.

Unify the quick tile components after the shared interactive styling exists. `QuickTileFrame.qml` should become the true base visual tile or be replaced with `BaseQuickTile.qml`. `QuickToggleTile.qml`, `QuickSelectorTile.qml`, and `QuickToggleMenuTile.qml` should provide only behavior differences: simple click toggle, selector popover, and split primary/secondary click target. The shared base should own icon/title layout, implicit width and height, disabled opacity, active/open/pressed color decisions, border decisions, and optional trailing slot.

## Concrete Steps

1. From `/home/m4rw3r/.config/quickshell`, capture the current lint state before any code edits:

       qmllint -I . *.qml controlcenter/*.qml services/*.qml ui/primitives/*.qml ui/controls/*.qml ui/patterns/*.qml theme/*.qml icons/*.qml

   Expected output at plan-writing time was no output. If new warnings appear before implementation, record them in `Surprises & Discoveries` and avoid mixing unrelated fixes into the first milestone.

2. Implement and validate the behavior fixes in this order: brightness keyboard initialization, brightness slider pending value, toast suspension, lighting command argv/validation, power profile error reporting, and notification focus fallback. After each file or small group, run the relevant lint command:

       qmllint services/BrightnessService.qml ControlCenter.qml NotificationToastStack.qml services/LightingService.qml NotificationCenter.qml

3. Exercise the behavior fixes live without restarting Quickshell:

       qs ipc call ui showControlCenter
       qs ipc call volume flash

   Open the brightness slider, notifications, and lighting/profile controls manually. Do not run `systemctl --user restart quickshell`.

4. Extract `SessionActionController.qml` and `SessionActionBanner.qml` from `shell.qml`. Keep `ControlCenter.qml` bindings to `sessionActions` working. Run:

       qmlformat -i shell.qml SessionActionController.qml SessionActionBanner.qml
       qmllint shell.qml SessionActionController.qml SessionActionBanner.qml ControlCenter.qml

5. Extract `VolumeOverlayController.qml`, bind the existing `VolumeOverlay.qml` to it, and update the `volume` IPC handler to call the controller. Run:

       qmlformat -i shell.qml VolumeOverlayController.qml VolumeOverlay.qml
       qmllint shell.qml VolumeOverlayController.qml VolumeOverlay.qml
       qs ipc call volume flash

6. Extract tray state into a single controller and bind both tray rail instances to it. Run:

       qmlformat -i shell.qml TrayRail.qml TrayStateController.qml
       qmllint shell.qml TrayRail.qml TrayStateController.qml
       qs ipc call tray peek
       qs ipc call tray open
       qs ipc call tray close

7. Introduce `activeOverlay` or `OverlayController.qml` and migrate `shadeOpen`, gallery state, and launcher opening to it. Keep existing IPC names and methods. Run:

       qmlformat -i shell.qml Launcher.qml WidgetGalleryWindow.qml
       qmllint shell.qml Launcher.qml WidgetGalleryWindow.qml
       qs ipc call ui showControlCenter
       qs ipc call gallery open
       qs ipc call gallery close

8. Extract control-center popovers one by one. After each component extraction, run `qmlformat` and `qmllint` on the changed files and use `qs ipc call ui showControlCenter` for live checks. Keep `ControlCenter.qml` working after each extraction; do not perform a large all-at-once move.

9. Centralize `expandedSection` assignment in helpers. Use grep to confirm the cleanup:

       rg "expandedSection\s*=" ControlCenter.qml controlcenter

   The remaining direct assignments should be inside the section helpers and panel-close reset only. If `rg` is not available in a future environment, use any equivalent search command.

10. Split launcher search/ranking, focused-output resolution, pager navigation, and tile rendering in separate commits or stopping points. After each extraction, run:

       qmllint Launcher.qml

   Include any new launcher component files in the same lint command.

11. Add theme tokens and migrate controls in small groups: buttons first, then action rows, then quick tiles, then tray/notification/volume surfaces. After each group, run:

       qmllint theme/Theme.qml ui/primitives/*.qml ui/controls/*.qml ui/patterns/*.qml

12. At the end, run the full lint command again from `/home/m4rw3r/.config/quickshell` and update this plan's `Outcomes & Retrospective` with the final file shape and any intentionally deferred work.

## Validation and Acceptance

The first acceptance gate is linting. From `/home/m4rw3r/.config/quickshell`, run:

    qmllint -I . *.qml controlcenter/*.qml services/*.qml ui/primitives/*.qml ui/controls/*.qml ui/patterns/*.qml theme/*.qml icons/*.qml

Expect no new errors. If warnings are introduced intentionally because `qmllint` cannot understand a Quickshell dynamic property, document the exact warning and the reason it is safe in `Surprises & Discoveries`; otherwise fix it.

The second acceptance gate is live behavior through IPC. Run these commands without restarting the running Quickshell service:

    qs ipc call ui showControlCenter
    qs ipc call ui hideControlCenter
    qs ipc call tray peek
    qs ipc call tray open
    qs ipc call tray close
    qs ipc call launcher open
    qs ipc call launcher close
    qs ipc call gallery open
    qs ipc call gallery close
    qs ipc call volume flash

The control center should open and close. The tray should peek, expand, and close. The launcher should open on the focused output, search should still update results, keyboard navigation should still move selection, and launching an app should still close the launcher. The gallery should open and close. The volume HUD should flash on demand and still appear for real volume changes unless another overlay is open.

The third acceptance gate is manual control-center behavior. Open the control center, then test the top power button, output menu, Wi-Fi tile and popover, Bluetooth tile and popover, profile selector, lighting selector when available, notification footer and notification popover, audio slider, and brightness slider. Each control should behave the same as before except for explicit bug fixes: brightness dragging should not snap to stale service values, toast timers should not expire only because the toast was hidden by another overlay, lighting commands should reject invalid levels, and power profile failures should show an error.

The fourth acceptance gate is structural. `shell.qml`, `ControlCenter.qml`, and `Launcher.qml` should each be smaller and easier to scan than before. A good target is that `shell.qml` contains window composition and IPC wiring, not embedded session, tray, or volume state machines; `ControlCenter.qml` contains panel composition and state transitions, not every popover's body; and `Launcher.qml` contains launcher composition and coordination, not all ranking, screen resolution, pager navigation, and tile rendering internals.

## Idempotence and Recovery

Each milestone is safe to retry because it edits QML configuration files only. Keep changes small enough that a failed milestone can be backed out by reverting only the files touched in that milestone. Do not use `systemctl --user restart quickshell`; the project-specific instruction is that Quickshell is already running. If the live shell reports a QML error, fix the file and rely on Quickshell's reload behavior.

If a structural extraction causes behavior changes, prefer restoring the previous behavior inside the new component rather than moving code back immediately. If the new component boundary itself is wrong, document the reason in `Decision Log`, revert that extraction only, and continue with unrelated milestones.

If `activeOverlay` migration causes an overlay to get stuck open or closed, keep compatibility booleans temporarily. For example, keep `property bool galleryOpen` as a transitional alias or adapter until `WidgetGalleryWindow.qml` and the gallery IPC handler are both migrated. Remove transitional state only after live IPC checks pass.

If shared UI tokens make a theme look worse, keep the token but tune its palette values rather than reintroducing hard-coded `Qt.rgba(1, 1, 1, ...)` at call sites. The goal is to move visual decisions into `Theme.qml`, not to freeze exact numeric alpha values forever.

If a file remains large for a good reason, document that reason in `Outcomes & Retrospective`. `WidgetGallery.qml` may remain relatively large because it is a documentation and preview surface, but `ControlCenter.qml` and `Launcher.qml` should become materially smaller.

## Artifacts and Notes

Current duplicated translucent border examples to replace with theme tokens:

    Qt.rgba(1, 1, 1, 0.08)
    Qt.rgba(1, 1, 1, 0.10)
    Qt.rgba(1, 1, 1, 0.12)
    Qt.rgba(1, 1, 1, 0.14)
    Qt.rgba(1, 1, 1, 0.16)

Suggested theme token names, with final values to be chosen to preserve the current look:

    readonly property color borderSubtle
    readonly property color borderNormal
    readonly property color borderStrong
    readonly property color overlayHover
    readonly property color overlayPressed
    readonly property color overlayActive

Current `ControlCenter.qml` section keys to preserve during extraction:

    "wifi"
    "bluetooth"
    "profile"
    "lighting"
    "outputs"
    "power"
    "notifications"

Suggested section-controller method names:

    function openSection(section)
    function closeSection(section)
    function toggleSection(section)
    function closeCurrentSection()
    function dismissOverlaySection()
    function toggleNotificationsSection()

Existing IPC targets and methods that must keep working:

    qs ipc call ui toggleControlCenter
    qs ipc call ui showControlCenter
    qs ipc call ui hideControlCenter
    qs ipc call tray toggle
    qs ipc call tray open
    qs ipc call tray peek
    qs ipc call tray close
    qs ipc call launcher toggle
    qs ipc call launcher open
    qs ipc call launcher close
    qs ipc call launcher search <query>
    qs ipc call theme current
    qs ipc call theme list
    qs ipc call theme set <name>
    qs ipc call theme toggle
    qs ipc call gallery toggle
    qs ipc call gallery open
    qs ipc call gallery close
    qs ipc call volume flash

## Interfaces and Dependencies

The implementation should continue using the existing Quickshell and Qt modules already imported by the current files unless a milestone explicitly needs a new Quickshell type. Do not add broad compatibility code for other machines or old Quickshell versions; this is controlled Z13 machine/session configuration.

At the end of the shell-controller milestone, these interfaces should exist or be equivalently represented:

    SessionActionController {
      property string busyAction
      property string failedAction
      property string lastError
      readonly property bool busy
      readonly property bool errorVisible
      readonly property bool bannerVisible
      function run(action)
      function retry()
      function dismissError()
    }

    VolumeOverlayController {
      property real value
      property bool muted
      property bool active
      function flash()
    }

    TrayStateController {
      property string mode
      property bool userPinned
      property bool peekForced
      readonly property bool hasAttention
      readonly property bool hasItems
      function toggleFromControlCenter()
      function openFromControlCenter()
      function openFromPeek()
      function forcePeek()
      function close()
      function collapseToPeekOrHidden()
    }

At the end of the control-center split, popover components should accept narrow inputs. The lowest-churn first pass may use `required property var controller`, as `controlcenter/WifiPopover.qml` and `controlcenter/NotificationsPopover.qml` already do. A later cleanup may replace broad controller references with explicit properties and signals once behavior is stable.

At the end of the launcher split, launcher subcomponents should preserve the current app-entry shape from `DesktopEntries.applications.values`. The ranking component should output the same DesktopEntry objects used today, and tile rendering should continue to call `ResolvedIconImage` with `icon`, `desktopEntry`, `appName`, and fallback `application-x-executable`.

Plan revision note: Initial version created from the 2026-05-15 Quickshell configuration review. It turns the review findings into staged, verifiable refactor milestones while preserving current user-visible behavior and IPC contracts.

Plan revision note: Updated 2026-05-15 after implementation. The progress, surprises, decisions, and retrospective now record the completed refactor, validation commands, the runtime `ActionRow` wrapper rollback, and the final hot-reload confirmation from the Quickshell journal.
