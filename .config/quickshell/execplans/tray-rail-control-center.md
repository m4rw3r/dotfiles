# Implement a top-right tray rail that cooperates with the control center

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

After this change, the shell will have a Quickshell-backed system tray that does not spend permanent screen space. When no tray content needs attention, nothing new is visible. When an application publishes an urgent tray item, a narrow vertical peek rail appears in the top-right corner. Tapping that peek opens a larger tray rail in the same corner. If the user then opens the control center, the tray rail shifts left and becomes a companion surface to the existing top-right control center. The user can verify the feature by causing a tray item to demand attention, observing the peek rail appear, tapping it to expand the tray, and then opening the control center to watch the tray move left without losing state.

## Progress

- [x] (2026-03-10 15:35Z) Read the current shell, control center, README, and theme files to capture the existing overlay structure and constraints.
- [x] (2026-03-10 15:35Z) Recorded the UX decisions already made for the tray rail: separate panel, vertical layout, peek owns the top-right corner while the control center is closed, and tapping the peek opens the tray only.
- [x] (2026-03-10 15:35Z) Saved this initial ExecPlan at `quickshell/execplans/tray-rail-control-center.md`.
- [x] (2026-03-10 15:51Z) Added shell-level tray state, tray IPC helpers, and separate top-right plus companion tray hosts in `quickshell/shell.qml`.
- [x] (2026-03-10 15:51Z) Added `quickshell/TrayRail.qml` with peek and expanded modes, touch-sized tray buttons, passive-item reveal, and native menu activation.
- [x] (2026-03-10 15:51Z) Added a tray toggle button to the top action row in `quickshell/ControlCenter.qml` and wired it to shell-level tray state.
- [x] (2026-03-10 15:51Z) Added tray IPC documentation and behavior notes to `quickshell/README.md`.
- [x] (2026-03-10 15:51Z) Ran `qmllint shell.qml ControlCenter.qml TrayRail.qml` and exercised tray/control-center IPC with `qs ipc call tray ...` and `qs ipc call ui ...` smoke tests.

## Surprises & Discoveries

- Observation: the current control center is not a standalone anchored panel window. It is rendered inside a full-screen overlay `PanelWindow` that also owns outside-click dismissal.
  Evidence: `quickshell/shell.qml` defines a scrim window at lines 366-383 and a second full-screen overlay window at lines 387-420, with `ControlCenter` anchored inside that overlay at lines 408-418.

- Observation: `ControlCenter.qml` already has an internal notion of nested overlays such as Wi-Fi, Bluetooth, power, and profile popovers, and outside clicks dismiss those nested overlays before closing the control center itself.
  Evidence: `overlayDismissActive` is defined in `quickshell/ControlCenter.qml:55`, `dismissOverlaySection()` is defined at `quickshell/ControlCenter.qml:150`, and the shell-level outside click handler checks `controlCenter.overlayDismissActive` before closing the panel in `quickshell/shell.qml:402-405`.

- Observation: this repository already exposes shell UI actions through Quickshell IPC, which makes a tray IPC target the safest way to test the new behavior without depending on compositor-specific gesture wiring.
  Evidence: `quickshell/shell.qml:274-331` already defines IPC targets for `ui`, `gallery`, and `theme`, and `quickshell/README.md:33-55` documents them.

- Observation: `SystemTray.items` behaves well at runtime but is treated as an untyped object model by `qmllint`, so lint-clean code needs explicit suppression or lightweight tracker objects around count/get access.
  Evidence: initial `qmllint shell.qml ControlCenter.qml TrayRail.qml` runs reported `missing-property` warnings for `SystemTray.items.count` and `SystemTray.items.get(i)` until the implementation wrapped those accesses carefully.

- Observation: a tray-only top-right `PanelWindow` plus a separate companion tray inside the control-center overlay is simpler than trying to use one large transparent window for both modes.
  Evidence: the final implementation keeps pointer input local to the tray when the control center is closed and avoids a full-width invisible click target.

- Observation: `SystemTrayItem.icon` is an image source string, not the local glyph name format used by `UiIcon`.
  Evidence: the first tray implementation rendered local glyph placeholders instead of real application icons until `TrayRail.qml` switched real tray items to `Quickshell.Widgets.IconImage`.

- Observation: relying on long-press or right-click alone is not enough for tray menus on this touch-first shell.
  Evidence: after initial implementation, the tray could technically open menus, but there was no obvious explicit affordance for menu-capable items that also expose a default action.

## Decision Log

- Decision: the tray will be a separate vertical rail rather than another section inside `ControlCenter.qml`.
  Rationale: the device behaves more like a tablet than a laptop, so persistent horizontal chrome is too expensive. A separate rail allows urgent information to appear without forcing the full control center open.
  Date/Author: 2026-03-10 / user and OpenCode

- Decision: while the control center is closed, the tray peek or expanded tray owns the top-right corner of the screen.
  Rationale: the user explicitly wants the attention peek to live in the top-right corner and does not want space reserved for the control center until the control center actually opens.
  Date/Author: 2026-03-10 / user and OpenCode

- Decision: opening the control center while the tray is visible shifts the tray left so the control center can appear on its right.
  Rationale: this creates a single composed cluster in the top-right corner and preserves the current control-center anchor at `quickshell/shell.qml:408-418`.
  Date/Author: 2026-03-10 / user and OpenCode

- Decision: tapping the attention peek opens the tray only; it does not automatically open the control center.
  Rationale: the peek is a tray affordance, not a hidden shortcut for the entire control center.
  Date/Author: 2026-03-10 / user and OpenCode

- Decision: if the tray was opened from the peek, closing the control center later must not collapse that tray. If the tray was opened as a companion to the control center, closing the control center should collapse the tray back to a peek or hide it.
  Rationale: the user chose behavior where tray intent is preserved only when the user explicitly opened the tray itself.
  Date/Author: 2026-03-10 / user and OpenCode

- Decision: use two tray hosts instead of one migrating tray window.
  Rationale: a dedicated top-right `PanelWindow` for tray-only mode and a second companion tray inside the existing control-center overlay avoid pointer-event issues and make the layout easier to reason about.
  Date/Author: 2026-03-10 / OpenCode

- Decision: use native tray menus first through `SystemTrayItem.display(...)` rather than a custom DBus menu renderer.
  Rationale: native menus are already exposed by Quickshell and are sufficient for a first pass; custom menu rendering remains a fallback only if the native menus prove unusable on this machine.
  Date/Author: 2026-03-10 / OpenCode

- Decision: expanded tray items with menus should expose a dedicated secondary menu hit target instead of overloading the primary tap gesture.
  Rationale: the user needs both the default action and the context menu to be reachable without hidden gestures, especially on a tablet-style device.
  Date/Author: 2026-03-10 / user and OpenCode

## Outcomes & Retrospective

The implementation now exists in `quickshell/shell.qml`, `quickshell/TrayRail.qml`, `quickshell/ControlCenter.qml`, and `quickshell/README.md`. The tray can peek in the top-right corner, expand without opening the control center, and shift left when the control center opens. The main remaining gap is deeper manual validation with real tray items over longer use, especially for applications that expose unusual tray menus or rapidly changing item state.

## Context and Orientation

This repository is a Quickshell configuration rooted at `quickshell/`. Quickshell is a QML-based shell framework that provides special window types such as `PanelWindow` and service singletons such as `SystemTray`. In this repository, `quickshell/shell.qml` is the entry point. It defines the launcher, the control-center overlay, the session action banner, and several IPC targets. `quickshell/ControlCenter.qml` contains the actual control-center panel content. It is a `FocusScope` with a `UiSurface` named `panel` beginning at `quickshell/ControlCenter.qml:1497`, and it exposes `closeRequested()` so the parent shell can close it.

In this plan, a “tray rail” means a narrow vertical panel that shows system tray items. A “peek” means the compact urgent-only form of that tray rail. An “expanded tray” means the larger tray panel that still lives without the control center. A “companion tray” means the same tray content shown to the left of the control center while the control center is open. A “tray item” means one `SystemTrayItem` from `Quickshell.Services.SystemTray`. These items provide `icon`, `status`, `tooltipTitle`, `tooltipDescription`, `hasMenu`, `onlyMenu`, `activate()`, `secondaryActivate()`, `scroll(delta, horizontal)`, and `display(parentWindow, x, y)`.

The existing control center is currently opened through shell IPC and through compositor-level gesture or keybind wiring outside this repository. The user said there is no visible trigger for it on screen. That means the tray cannot assume the control center is open. The tray must be useful by itself.

The repository also has a reusable design system in `quickshell/theme/Theme.qml` and `quickshell/ui/`. Use those tokens rather than inventing ad hoc spacing or sizes. Relevant theme values already present include `Theme.gapXs`, `Theme.gapSm`, `Theme.gapMd`, `Theme.overlayMargin`, `Theme.radiusLg`, and `Theme.controlMd` in `quickshell/theme/Theme.qml:102-132`.

Because `quickshell/AGENTS.md` says not to restart Quickshell, this work must rely on live reload or the normal non-destructive reload path already used on this machine. Do not stop and restart the shell process as part of implementation or validation.

## Plan of Work

Start in `quickshell/shell.qml`. Introduce shell-level tray state so the shell, not `ControlCenter.qml`, remains the source of truth for whether the tray is hidden, peeking, or expanded. Use a simple explicit state rather than inferred booleans. Add `property string trayMode: "hidden"`, where the allowed values are `"hidden"`, `"peek"`, and `"expanded"`. Add `property bool trayUserPinned: false` to remember whether the user explicitly expanded the tray from the peek. Add helper functions such as `hasTrayAttention()`, `collapseTrayToPeekOrHidden()`, `openTrayFromPeek()`, `toggleTrayFromControlCenter()`, and `closeTray()`. Update the existing `ui` IPC handler so `toggleControlCenter()`, `showControlCenter()`, and `hideControlCenter()` call helper functions rather than mutating `root.shadeOpen` directly, because opening and closing the control center now affects tray placement.

Still in `quickshell/shell.qml`, add a new IPC handler `target: "tray"` with `toggle()`, `open()`, `peek()`, and `close()` methods. `open()` should open the expanded tray and mark `trayUserPinned = true`. `peek()` should force `trayMode = "peek"` even when there is no current attention, because that makes manual testing possible. `toggle()` should toggle expanded tray-only mode when the control center is closed and should toggle the companion tray when the control center is open. Document these semantics in `quickshell/README.md` after implementation.

The tray needs two visual hosts, both driven by the same shell-level state. Add a new reusable component `quickshell/TrayRail.qml`. This file should not create its own `PanelWindow`; it should only render content inside a parent host. Give it properties `mode`, `controlCenterOpen`, `showPassive`, and `panelWindow`. `mode` is either `"peek"` or `"expanded"`. `controlCenterOpen` is true when the rail is acting as a companion to the control center. `showPassive` is a local toggle that expands the lower-priority items. `panelWindow` is the parent window object needed to call `SystemTrayItem.display(...)` when opening native menus.

Inside `TrayRail.qml`, import `Quickshell.Services.SystemTray`. Define derived models or filtered arrays for three buckets: urgent items (`status === Status.NeedsAttention`), active items (`status === Status.Active`), and passive items (`status === Status.Passive`). The peek mode renders only urgent items and, if there are no urgent items but the tray was manually forced into peek mode for testing, the first one or two active items. The expanded mode renders urgent items first, then active items, and exposes a `More` or `Passive` toggle that reveals passive items below a divider. Each tray button should use large touch-friendly hit targets based on `Theme.controlMd` plus padding, not tiny desktop-sized icons.

Handle tray-item interaction inside `TrayRail.qml`. If `item.onlyMenu` is true, tapping the item should open its menu immediately. Otherwise tapping should call `item.activate()`. Long-press, a small companion action button, or a secondary target inside the delegate should open `item.display(panelWindow, x, y)` for items that expose menus. The plan does not require full custom DBus menu rendering unless native menus fail badly on this machine; start with native menus because the tray service already exposes them. Hide passive items from the peek entirely. Give urgent items a visible badge or stronger surface tone so the peek clearly communicates that something needs attention.

Back in `quickshell/shell.qml`, render `TrayRail.qml` in two places. First, add a standalone top-right `PanelWindow` that is visible when `trayMode !== "hidden"` and `!root.shadeOpen`. Anchor it to the top-right of the screen and render `TrayRail` inside it in either peek or expanded mode. Second, render a companion `TrayRail` inside the existing full-screen overlay `PanelWindow` that already hosts `ControlCenter`. Anchor the companion tray to the left of `ControlCenter` with `Theme.gapSm` or `Theme.gapMd` between them, and make it visible only when `root.shadeOpen` and `trayMode !== "hidden"`. This two-host arrangement avoids having a wide transparent top-level tray window intercept pointer input across empty space while the control center is closed.

Update `quickshell/ControlCenter.qml` so it can reflect and control tray state without owning that state. Add `property bool trayVisible`, `property bool trayExpanded`, and `property bool trayNeedsAttention`. Add `signal trayToggleRequested()`. In the top action row starting at `quickshell/ControlCenter.qml:1524`, insert a new tray icon button before the lock and power controls or between the battery chip and the system buttons if spacing works better. The button should show an active state when `trayExpanded` is true and should show a subtle badge or stronger tone when `trayNeedsAttention` is true. On click, emit `trayToggleRequested()`; the parent shell will decide whether that means open, close, or collapse.

When the control center opens, do not forcibly change `trayMode`. Instead, switch visual hosts: hide the standalone top-right tray host and show the companion tray beside the control center. Preserve `trayUserPinned`. When the control center closes, use `trayUserPinned` to decide what happens next. If `trayUserPinned` is true, keep the tray expanded in the top-right corner. If `trayUserPinned` is false, call `collapseTrayToPeekOrHidden()`, which should leave a peek visible only when urgent items remain. This preserves the exact user decision already made for this feature.

Animation should be simple and deliberate. The peek rail should slide in from the right edge with a small opacity fade. The expanded tray-only rail should grow or slide out from the same top-right position. The companion tray beside the control center should animate as if it shifted left to make room for the control center, even though the implementation uses two hosts. Matching implicit widths, top margins, and surface styling between the two hosts is more important than reproducing a mathematically perfect single-window translation. Use `Behavior on opacity`, `Behavior on x`, or equivalent property animations in the local components, and keep the duration in the 160-220ms range.

Finally, update `quickshell/README.md` to document the new tray feature and its IPC target. The README should explain that the tray is intentionally hidden until needed, can peek in the top-right corner, and moves left of the control center when both are visible. Add the exact `qs ipc call tray ...` commands used for testing.

## Concrete Steps

Work from `/home/m4rw3r/.config/quickshell`.

1. Read the files named in this plan before editing them again so that the final implementation matches the current working tree:

       read shell.qml
       read ControlCenter.qml
       read README.md
       read theme/Theme.qml

2. Implement shell-level tray state, tray helper functions, and a new `tray` IPC target in `shell.qml`.

3. Create `TrayRail.qml` and, if needed for clarity, one small delegate component under `quickshell/ui/controls/` for repeated tray item buttons. Keep any new helper components tightly scoped; do not create a deep component tree unless duplication demands it.

4. Add the tray button wiring to `ControlCenter.qml` and bind the new properties and signal from `shell.qml`.

5. Update `README.md` with the new tray behavior and IPC commands.

6. Run QML lint on every touched QML file:

       qmllint shell.qml ControlCenter.qml TrayRail.qml

   If additional QML files were added under `ui/controls/`, lint them too:

       qmllint shell.qml ControlCenter.qml TrayRail.qml ui/controls/<new-file>.qml

7. Manually exercise the feature with IPC and with the existing control-center gesture or keybind. The exact commands to use after the files are reloaded are:

       qs ipc call tray peek
       qs ipc call tray open
       qs ipc call tray close
       qs ipc call ui showControlCenter
       qs ipc call ui hideControlCenter

   If the shell is already showing a real tray item that needs attention, also validate the automatic peek path by provoking that item rather than relying only on the forced `peek` IPC.

Expected manual-testing transcript after implementation should look roughly like this:

       $ qs ipc call tray peek
       ok
       # a narrow tray rail appears in the top-right corner

       $ qs ipc call tray open
       ok
       # the rail expands in the top-right corner without opening the control center

       $ qs ipc call ui showControlCenter
       ok
       # the control center appears on the right and the tray shifts to its left

       $ qs ipc call ui hideControlCenter
       ok
       # if the tray was opened via the peek, it stays expanded at the top-right

## Validation and Acceptance

Validation is complete only when both linting and manual behavior checks pass.

Run `qmllint` on the changed QML files and expect it to exit successfully with no fatal errors. Resolve warnings when they indicate broken bindings, unknown properties, or unreachable imports.

Manually verify these user-visible behaviors in the running shell:

1. With the control center closed and no forced tray IPC active, no tray rail is visible unless a tray item has urgent status.

2. Running `qs ipc call tray peek` shows a narrow vertical tray rail in the top-right corner. Tapping that peek expands the tray but does not open the control center.

3. Running `qs ipc call tray open` with the control center closed shows the expanded tray in the top-right corner.

4. Opening the control center while the tray is visible produces a composed top-right cluster where the tray sits to the left of the control center with a small gap between them.

5. If the tray was opened directly from the peek or by `qs ipc call tray open`, closing the control center leaves the tray expanded in the top-right corner.

6. If the tray was opened only from the control-center tray button, closing the control center collapses the tray to a peek when urgent items remain or hides it when there is no urgent item.

7. Tapping a normal tray item activates it. Tapping a menu-only tray item opens its menu instead of doing nothing.

8. Passive tray items never appear in the attention peek and only appear in expanded mode after the user reveals them.

Acceptance is behavioral, not structural. The implementation is done only when a human can see the tray appear, expand, shift beside the control center, preserve or collapse state correctly based on how it was opened, and interact with real tray items.

## Idempotence and Recovery

These changes are additive and safe to repeat. Re-running `qmllint` is always safe. Re-applying the same IPC commands is also safe; they are intended to drive visible shell state and should not mutate persistent configuration.

If a QML edit leaves the tray or control center broken, fix the file and save again; do not restart the Quickshell process. If the tray IPC target loads before the rail renders correctly, use `qs ipc call tray close` to reset the tray state and then continue iterating. If native tray menus prove unusable on this machine, keep the rest of the tray implementation and add a follow-up milestone in this plan for custom `QsMenuOpener` rendering rather than blocking the whole feature.

## Artifacts and Notes

The target interaction model is:

    Hidden
      -> attention -> Peek at top-right
      -> tap peek -> Expanded tray at top-right
      -> open control center -> Companion tray left of control center
      -> close control center -> Expanded tray if user-pinned, otherwise Peek or Hidden

The top-right composition when both surfaces are visible should read like this:

    +---------------+  gap  +-------------+
    | Tray Rail     |       | Control     |
    | vertical      |       | Center      |
    +---------------+       +-------------+

Keep the tray visually consistent with the control center. Use the same surface tone family, border treatment, and corner radius so the pair looks intentional rather than like two unrelated floating panels.

## Interfaces and Dependencies

In `quickshell/shell.qml`, define or update the following shell-level interface:

    property bool shadeOpen
    property string trayMode            // "hidden", "peek", "expanded"
    property bool trayUserPinned
    function hasTrayAttention(): bool
    function collapseTrayToPeekOrHidden(): void
    function openTrayFromPeek(): void
    function openTrayFromControlCenter(): void
    function toggleTrayFromControlCenter(): void
    function closeTray(): void

In `quickshell/shell.qml`, add a new IPC target with this external interface:

    target: "tray"
    function toggle(): void
    function open(): void
    function peek(): void
    function close(): void

In `quickshell/ControlCenter.qml`, add this component interface so the shell can wire the tray button cleanly:

    property bool trayVisible
    property bool trayExpanded
    property bool trayNeedsAttention
    signal trayToggleRequested()

In `quickshell/TrayRail.qml`, define a reusable content component with this interface:

    property string mode                // "peek" or "expanded"
    property bool controlCenterOpen
    property var panelWindow
    readonly property bool hasAttention
    readonly property bool hasAnyItems
    signal dismissRequested()
    signal expandRequested()

`TrayRail.qml` must import `Quickshell.Services.SystemTray` and use `SystemTray.items` as the single source of tray data. Use `Status.NeedsAttention`, `Status.Active`, and `Status.Passive` to sort items into urgent, active, and passive groups. Use existing theme tokens from `quickshell/theme/Theme.qml` for spacing, corner radius, and touch-target sizing. Do not add a permanent tray strip to the launcher or to the main shell edge.

Revision note: updated on 2026-03-10 after implementation to record the final two-host tray approach, lint constraints around `SystemTray.items`, the real tray-icon rendering fix via `IconImage`, the split default-action/menu tray interaction, and the completed smoke-test steps.
