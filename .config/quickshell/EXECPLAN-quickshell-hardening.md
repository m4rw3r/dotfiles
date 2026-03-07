# Quickshell reliability and interaction hardening

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

This plan hardens the running Quickshell configuration so the control center always opens with useful content, Wi-Fi state is trustworthy, launcher input behaves correctly for keyboard and touch users, and the shared widget library stops hiding important state. After this work, a user should be able to open the shade with `qs ipc call ui openShade`, open the gallery with `qs ipc call gallery open`, and use the launcher with `qs ipc call launcher open` without seeing blank panels, missing tile subtitles, misleading Wi-Fi labels, or focus glitches that dismiss the on-screen keyboard.

The repository already contains a running Quickshell configuration, and `AGENTS.md` in this repository says not to restart Quickshell itself. Validation in this plan therefore relies on `qmllint`, the existing IPC entry points exposed from `shell.qml`, and direct interaction with the already-running overlays.

## Progress

- [x] (2026-03-06 23:10Z) Reviewed the current repository state, re-checked `ControlCenter.qml`, `Launcher.qml`, `ui/patterns/QuickTile.qml`, shared controls, and the widget gallery, and grouped the remaining issues into implementation bundles.
- [x] (2026-03-06 23:10Z) Authored this ExecPlan in `EXECPLAN-quickshell-hardening.md`.
- [x] (2026-03-06 23:20Z) Implemented Milestone 1 in `ControlCenter.qml` by replacing the panel readiness gate with `brightnessService.settled`, allowing the panel to render when brightness detection finishes even if no readable screen backlight exists.
- [x] (2026-03-06 23:20Z) Implemented Milestone 2 in `ControlCenter.qml` by mapping saved Wi-Fi state from `802-11-wireless.ssid`, requesting BSSID in scans, deduplicating by BSSID instead of SSID, and adding `set -e` to the refresh shell pipeline so earlier `nmcli` failures are no longer masked.
- [x] (2026-03-06 23:20Z) Implemented Milestone 3 in `Launcher.qml` by adding row-aware vertical navigation, forwarding non-grid text entry toward the search field, and keeping the clear button from kicking focus to the grid or dismissing the touch keyboard.
- [x] (2026-03-06 23:20Z) Implemented Milestone 4 in `ControlCenter.qml` by splitting audio and Wi-Fi stderr collectors per process and clearing action errors before issuing new commands.
- [x] (2026-03-06 23:20Z) Implemented Milestone 5 in `ui/patterns/QuickTile.qml` by rendering subtitle text and increasing tile height only when subtitle content exists.
- [x] (2026-03-06 23:20Z) Implemented Milestone 6 in `ControlCenter.qml` by computing Bluetooth transient busy state and disabling rows that are already pairing or connecting.
- [x] (2026-03-06 23:20Z) Implemented Milestone 7 in `ControlCenter.qml` by adding a `loginctl show-user ... -p Display` fallback when `XDG_SESSION_ID` is absent.
- [x] (2026-03-07 00:06Z) Completed final validation: `qmllint` remained at the known warning baseline, `qs ipc call gallery open`, `qs ipc call ui openShade`, and `qs ipc call launcher open` all succeeded, and live manual verification confirmed the expected control center, Wi-Fi, launcher, QuickTile, Bluetooth, and session-action behaviors.
- [x] (2026-03-06 23:36Z) Fixed a post-implementation Wi-Fi regression after live validation: `nmcli connection show` does not accept `802-11-wireless.ssid` in the bulk field list, so saved-network lookup now enumerates wireless profile UUIDs and queries each profile's SSID separately.
- [x] (2026-03-07 00:00Z) Fixed a post-validation launcher regression in `Launcher.qml` by keeping the search field's `text` property at the current bound value when focus disables the binding, so reopening the launcher no longer revives a stale query.
- [x] (2026-03-07 00:12Z) Fixed a second post-validation launcher regression in `Launcher.qml` by deduplicating `DesktopEntries.applications.values` before ranking, so package removals no longer leave repeated app tiles in the launcher.

## Surprises & Discoveries

- Observation: The repository is not only the live shell configuration; it also contains `WidgetGallery.qml`, which is a design sandbox for the same shared widgets. A broken shared widget therefore appears twice: once in the control center and once in the gallery.
  Evidence: `README.md` describes `WidgetGallery.qml` as a live preview surface, and `WidgetGallery.qml` passes `subtitle` into `Patterns.QuickTile` while `ui/patterns/QuickTile.qml` does not render `subtitle`.

- Observation: The control center still gates initial visibility on a successful screen brightness read instead of on the broader availability of useful panel data.
  Evidence: `ControlCenter.qml` defines `panelDataReady` as `audioService.ready && brightnessService.screenLoaded && wifiService.ready`, while `screenLoaded` only changes inside `BrightnessController.parseBrightness(..., false)`.

- Observation: The Wi-Fi parser is safer than the first version because it now uses `splitEscaped`, but the core identity bug remains because saved NetworkManager connection names are still treated as SSIDs.
  Evidence: `ControlCenter.qml` parses `NAME,TYPE` into `savedNetworks`, then computes `known: savedNetworks[ssid] === true` inside `parseWifiList`.

- Observation: `qs ipc call ...` succeeds silently in this environment, so command success proves the IPC target responded but does not itself prove the final visual layout without a human looking at the running desktop.
  Evidence: `qs ipc call gallery open`, `qs ipc call ui openShade`, and `qs ipc call launcher open` all returned with no stderr and no stdout.

- Observation: `nmcli connection show` accepts `802-11-wireless.ssid` only when targeting a specific connection profile, not when requesting the bulk connection table with `-f`.
  Evidence: Live UI validation surfaced `Error: invalid field '802-11-wireless.ssid'`; querying `nmcli -g 802-11-wireless.ssid connection show uuid <uuid>` works, while `nmcli -f ... connection show` rejects that field.

- Observation: The launcher's `Binding on text` looked correct while unfocused but restored an older explicit value as soon as the field regained focus, which made a closed launcher appear reset until the user clicked into the field.
  Evidence: The search field used `Binding on text` with a focus-dependent `when` clause and the default restore behavior, so reopening the launcher with `root.launcherQuery === ""` still allowed the previously typed `TextInput.text` value to come back on focus.

- Observation: `DesktopEntries.applications.values` can transiently contain repeated application records after package removals, and the launcher currently trusts that list as canonical.
  Evidence: After uninstalling GNOME applications, the launcher rendered repeated copies of each remaining app tile until the result list was deduplicated before ranking.

## Decision Log

- Decision: Keep the work in seven milestones that match the grouped bug bundles rather than scattering one-off fixes across files.
  Rationale: The remaining issues cluster around shared state models. Fixing them together reduces churn and prevents one patch from reintroducing another bug.
  Date/Author: 2026-03-06 / OpenCode

- Decision: Use the already-running Quickshell instance plus `qs ipc call ...` commands for validation instead of restarting the shell.
  Rationale: `AGENTS.md` in this repository explicitly says not to restart Quickshell itself, and the repository already exposes IPC handlers in `shell.qml` and documents them in `README.md`.
  Date/Author: 2026-03-06 / OpenCode

- Decision: Treat `WidgetGallery.qml` as part of the acceptance surface for shared widgets, not as optional demo code.
  Rationale: The gallery is the fastest place to verify widget layout and state changes before relying on the heavier control center surface.
  Date/Author: 2026-03-06 / OpenCode

- Decision: Keep the Wi-Fi refresh in one shell pipeline for now, but add `set -e` and improve the parsed fields instead of immediately refactoring into three separate `Process` objects.
  Rationale: The immediate correctness issues were saved-network identity, SSID-only deduplication, and masked failures. `set -e` fixes the masked-failure bug with much lower churn, while separate stderr collectors already remove the concurrent error-reporting race.
  Date/Author: 2026-03-06 / OpenCode

- Decision: Resolve saved-network SSID lookup by enumerating wireless connection UUIDs and querying each profile's SSID individually.
  Rationale: This preserves correct SSID detection for renamed profiles without depending on an unsupported bulk `nmcli` field selection.
  Date/Author: 2026-03-06 / OpenCode

- Decision: Deduplicate launcher entries inside `refreshLauncherResults()` using normalized desktop-entry identity instead of assuming the `DesktopEntries` feed is already unique.
  Rationale: This keeps the launcher stable when the desktop-entry cache emits duplicates after package churn, while preserving ranking and pagination behavior.
  Date/Author: 2026-03-07 / OpenCode

## Outcomes & Retrospective

The main implementation pass is complete. `ControlCenter.qml` now treats brightness availability as optional for initial render, Wi-Fi parsing now uses SSID and BSSID-aware data instead of profile-name guesses, launcher navigation is row-aware, the launcher search field no longer resurrects stale text after reopen, launcher results now deduplicate repeated desktop entries after package churn, shared subprocess stderr collectors no longer overlap, `QuickTile` now renders subtitle text, Bluetooth rows stop accepting repeated transitional clicks, and logout has a non-`XDG_SESSION_ID` fallback.

Final validation also passed on the live desktop. Static validation succeeded with the existing Quickshell-specific `qmllint` warnings only, the IPC entry points remained callable, and manual verification confirmed the launcher, control center, shared tiles, Bluetooth busy-state handling, and session actions all behaved as intended. The main lesson from implementation is that most of the bugs were contract bugs between state and presentation, so the fixes landed best as grouped state-model changes rather than isolated line edits.

## Context and Orientation

The repository root for this work is `/home/m4rw3r/.config/quickshell`. The runtime entry point is `shell.qml`. That file creates the launcher overlay, the control center overlay, and a widget gallery overlay, and it exposes IPC targets named `ui`, `launcher`, `theme`, and `gallery`. An IPC target is a named command surface that `qs ipc call ...` can invoke while Quickshell is already running.

`ControlCenter.qml` is the highest-risk file. It is a large `FocusScope` that contains both UI layout and several embedded controller objects: `audioService` for `wpctl`, `BrightnessController` for `brightnessctl`, `WifiController` for `nmcli`, and `SessionActions` for lock, sleep, restart, shutdown, and logout. A `StdioCollector` is Quickshell's object for capturing a process stream such as standard error. A race in this file usually means two `Process` instances share one collector or one busy flag and overwrite each other's state.

`Launcher.qml` is the second major behavior surface. It renders a `PanelWindow` per screen, tracks one active screen, owns the search field, grid selection, and fallback on-screen keyboard process, and exposes IPC commands under the `launcher` target. An input method is Qt's text entry system for complex input such as compose sequences and East Asian input. The on-screen keyboard, abbreviated OSK in this plan, is the fallback process launched when Qt's own input panel does not appear.

The shared widget library lives under `ui/`. `ui/primitives/` contains the low-level building blocks, `ui/controls/` contains reusable interactive controls, and `ui/patterns/` contains higher-level composed widgets such as `QuickTile`. `WidgetGallery.qml` exercises those shared widgets directly, which makes it the quickest manual validation surface for shared layout changes.

The specific known defects this plan addresses are these. First, `ControlCenter.qml` can remain invisible forever when there is no readable screen backlight device, because `panelDataReady` waits on `brightnessService.screenLoaded`. Second, the Wi-Fi code in `ControlCenter.qml` still confuses NetworkManager connection names with SSIDs and still merges all access points with the same SSID into one row. In this plan, an access point means one visible Wi-Fi radio entry from `nmcli`, and BSSID means the unique hardware identifier for one access point. Third, `Launcher.qml` still has split ownership of query state between `root.launcherQuery` and `searchInput.text`, which causes clear-button, focus, touch keyboard, and input-method edge cases. Fourth, shared subprocess stderr capture still races in both audio and Wi-Fi code. Fifth, `ui/patterns/QuickTile.qml` still drops the subtitle that callers provide. Sixth, Bluetooth rows are still clickable while they already show `Working`. Seventh, logout still relies on `XDG_SESSION_ID` even though some compositor-launched sessions do not export it.

## Plan of Work

Milestone 1 fixes control center readiness in `ControlCenter.qml`. Replace the current "all services must succeed" gate with a readiness model that treats brightness as optional data. The panel should become visible once audio and Wi-Fi are loaded and brightness detection has either succeeded, failed, or concluded that no screen backlight exists. The easiest safe implementation is to add an explicit brightness completion state, set it when device detection finishes even if no screen device exists, and use that state instead of `screenLoaded` in `panelDataReady`. While doing this, keep the brightness slider disabled when there is no screen backlight and preserve existing keyboard-backlight behavior. Update any error or empty-state text needed so a user can tell the panel is usable even without brightness control.

Milestone 2 repairs the Wi-Fi data model inside `ControlCenter.qml`. Stop using `nmcli -t --escape yes -f NAME,TYPE connection show` as if the first field were an SSID. Replace it with a query that gives enough information to map saved wireless profiles to the SSIDs they are actually configured for. One acceptable approach is to query `NAME,TYPE,802-11-wireless.ssid` and build the known-network set from the SSID field, not the profile name. At the same time, stop deduplicating by SSID alone. Parse enough information from `nmcli device wifi list` to distinguish multiple access points that share the same SSID but differ in security or hardware identity. Prefer a stable key such as BSSID if available; if BSSID is not included today, extend the command to request it. Keep the sort order friendly by still grouping the active row first, then known networks, then strongest signal. Finally, make refresh behavior report partial failures clearly instead of silently trusting a chained `sh -lc` command where only the last subcommand's exit status matters. Splitting the refresh into multiple `Process` calls is acceptable if it keeps state transitions clearer.

Milestone 3 unifies launcher query and focus behavior in `Launcher.qml`. Make `root.launcherQuery` the single source of truth for the current query, and make the `TextInput` reflect that state consistently. Remove the pattern where the grid intercepts printable keys and manually assigns `searchInput.text`; instead, moving focus into the field should allow Qt's normal text-entry path to handle input methods and preedit text. Adjust the clear button so it clears the query without kicking focus to the grid or dismissing the on-screen keyboard when the user tapped inside the search flow. Rework vertical navigation so a move down into a short final row picks the nearest sensible item rather than clamping to the last entry in the entire result set.

Milestone 4 cleans up subprocess error handling in `ControlCenter.qml`. Give each long-lived `Process` instance its own stderr collector, or otherwise guarantee that concurrent commands cannot overwrite one another's error text. Keep busy-state and refresh behavior explicit: volume writes, mute writes, Wi-Fi toggle, Wi-Fi scan, and Wi-Fi connect should each update the relevant state and clear or preserve `lastError` predictably. The acceptance target is that two quick user actions in a row cannot cause the wrong error to appear.

Milestone 5 fixes the shared `QuickTile` contract in `ui/patterns/QuickTile.qml`. Render `subtitle` in a way that fits the current compact layout, supports both active and inactive colors, and does not break the split-action affordance. Because this component is reused, validate it in both `WidgetGallery.qml` and `ControlCenter.qml`. If the current tile height is too small once subtitle text exists, adjust the implicit height and spacing in the pattern itself rather than trying to special-case callers.

Milestone 6 hardens Bluetooth interactions in `ControlCenter.qml`. For connected devices and available devices, compute whether the row is in a transient state such as pairing, connecting, or disconnecting, surface that state through `actionText`, and disable the row while that transient state is active. The point is not visual polish alone; it is to prevent duplicate `connect()`, `pair()`, or `disconnect()` calls from being triggered before the previous action settles.

Milestone 7 makes logout resilient inside `SessionActions` in `ControlCenter.qml`. Replace the current shell snippet that requires `XDG_SESSION_ID` with a safer fallback path that can still discover the current session or at least fail with a clearly actionable error. Keep the other power actions unchanged.

After all milestones, update this document's `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` sections with real implementation notes and validation evidence.

## Concrete Steps

Work from `/home/m4rw3r/.config/quickshell` unless a different directory is stated.

For Milestone 1, edit `ControlCenter.qml` and change the readiness gate and brightness controller completion model. Then run:

    qmllint shell.qml Launcher.qml ControlCenter.qml theme/Theme.qml ui/primitives/*.qml ui/controls/*.qml ui/patterns/*.qml WidgetGallery.qml WidgetGalleryWindow.qml

Open the shade on the running shell:

    qs ipc call ui openShade

Observe that the control center becomes visible immediately even on a system where screen brightness is unavailable. The brightness slider may be disabled, but the rest of the panel must render.

For Milestone 2, edit the Wi-Fi refresh and parsing functions in `ControlCenter.qml`. After the edit, run the same `qmllint` command, then open the shade and expand Wi-Fi. Use:

    qs ipc call ui openShade

Observe that saved networks are labeled according to their real SSIDs, the active network appears first, and duplicate SSIDs no longer collapse incorrectly when multiple access points are available.

For Milestone 3, edit `Launcher.qml`. After linting, open the launcher:

    qs ipc call launcher open

Verify three behaviors manually. Typing from the grid should move focus into the field and preserve normal text entry. Tapping the clear button should leave the field ready for more typing instead of moving focus to the grid. Moving down from a partially filled page row should land on the nearest sensible item.

For Milestone 4, edit `ControlCenter.qml` again to isolate stderr collectors and busy-state transitions. Lint the QML and then use the running shade to click mute, drag volume, refresh Wi-Fi, and connect to a network in quick succession. The acceptance target is that the visible error text always matches the command that actually failed.

For Milestone 5, edit `ui/patterns/QuickTile.qml`, then use the gallery as the fast visual check:

    qs ipc call gallery open

The Wi-Fi, Bluetooth, power-mode, and keyboard tiles in both the gallery and control center must show subtitle text without clipping into the chevron region.

For Milestone 6, edit the Bluetooth menu rows in `ControlCenter.qml`, lint again, and open the shade. Expand Bluetooth and attempt to click a device that is already mid-transition. The row should show `Working` and reject repeated clicks until the state changes.

For Milestone 7, edit `SessionActions` in `ControlCenter.qml`, lint again, and test the power popover through the running shade. Do not trigger destructive actions such as shutdown or reboot during development unless you explicitly intend to. For logout logic, prefer a dry-run helper or temporary logging while implementing, then remove it before finalizing. The final user-facing behavior should either log out successfully or show a clear error that does not depend on `XDG_SESSION_ID` being set.

At the end, rerun:

    qmllint shell.qml Launcher.qml ControlCenter.qml theme/Theme.qml ui/primitives/*.qml ui/controls/*.qml ui/patterns/*.qml WidgetGallery.qml WidgetGalleryWindow.qml

Then exercise the three overlay surfaces one last time:

    qs ipc call gallery open
    qs ipc call ui openShade
    qs ipc call launcher open

The latest implementation pass did this. `qmllint` completed with the same expected Quickshell-specific warnings as before, and all three IPC commands returned successfully with no stderr. A human still needs to look at the live overlays to confirm the visual behaviors end-to-end.

## Validation and Acceptance

Acceptance is behavior-first.

For the control center, a user opens the shade and sees content immediately. Audio and Wi-Fi data should render even if brightness control is unavailable. The brightness slider may be disabled, but the panel must not stay blank.

For Wi-Fi, a user opens the Wi-Fi section and sees an active network row, trustworthy "saved" labeling, and separate entries when multiple access points share one SSID but are not actually the same choice. Error text must correspond to the command that failed.

For the launcher, a user can start typing with normal keyboard input or through an input method, clear the query without losing the text-entry context, and navigate the result grid without strange jumps on short rows.

For shared widgets, the gallery must visibly show `QuickTile` subtitles, and the same subtitle text must appear in the control center tiles.

For Bluetooth, a row that says `Working` must be non-interactive until the state changes.

For session actions, logout must not fail only because `XDG_SESSION_ID` is missing.

Static validation must include a successful `qmllint` pass with no new warnings beyond the existing Quickshell-specific type-resolution noise already seen during review. Manual validation must use the already-running Quickshell instance through `qs ipc call gallery open`, `qs ipc call ui openShade`, and `qs ipc call launcher open`.

## Idempotence and Recovery

All edits in this plan are source-only and can be applied incrementally. The `qmllint` command is safe to rerun at any point. The IPC open commands are also safe to rerun because they only request that a currently running overlay become visible.

Avoid restarting Quickshell during this work. If a change causes one overlay to misbehave, revert only the affected source file or comment out the in-progress block and rely on the still-running shell plus `qmllint` to regain a known state. For risky session-action work, do not trigger `shutdown` or `reboot` as part of validation; prefer implementing a fallback path first and validating the final logout path only when the code is ready.

If Milestone 2 proves too invasive for one pass, it is safe to land it in two internal steps: first fix saved-network identity, then extend deduplication to use BSSID. If that happens, update `Progress` immediately so the document matches the working tree.

## Artifacts and Notes

The review that motivated this plan found these concrete defects and should be treated as the starting evidence set:

    QuickTile subtitle is passed by callers but not rendered in ui/patterns/QuickTile.qml.
    ControlCenter panelDataReady still depends on brightnessService.screenLoaded.
    WifiController still computes known: savedNetworks[ssid] === true after parsing NAME,TYPE.
    Launcher clear button only writes root.launcherQuery = "" and can kick focus back to the grid.

The repository already documents the gallery IPC flow:

    qs ipc call gallery open
    qs ipc call gallery toggle
    qs ipc call gallery close

The existing lint baseline includes Quickshell-specific type-resolution warnings for `PanelWindow` and some process signal parameter types. Do not treat those existing warnings as new regressions unless the warning set grows.

## Interfaces and Dependencies

This work stays inside the existing QML architecture and external command dependencies already used by the repository.

In `ControlCenter.qml`, the following objects must continue to exist after the refactor: the root `FocusScope`, `audioService`, `BrightnessController`, `WifiController`, and `SessionActions`. It is acceptable to add helper properties and helper functions inside those objects if the resulting names remain descriptive.

In `Launcher.qml`, keep `root.launcherQuery` as the canonical query property and ensure the search field and result ranking derive from it. Do not introduce a second independent query property.

In `ui/patterns/QuickTile.qml`, preserve the existing public interface at minimum:

    property string iconName
    property string title
    property string subtitle
    property bool active
    property bool expanded
    property bool expandable
    property bool highlightExpanded
    signal primaryClicked()
    signal secondaryClicked()

The external tools assumed by this plan are the same ones already used by the repository: `wpctl` for audio, `brightnessctl` for brightness, `nmcli` for Wi-Fi, `qs` for IPC calls, and `qmllint` for static checking. If any environment lacks one of these tools, record that fact in `Surprises & Discoveries` and adapt validation accordingly.

Revision note: Created this ExecPlan to turn the grouped second-pass review findings into an ordered, self-contained implementation path that can be executed without prior context.
