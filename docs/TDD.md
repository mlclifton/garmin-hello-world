# Technical Design Document — Garmin Hello World

A from-scratch reference for this codebase: what it is, how it's put
together, and why each piece exists. Read this before making changes so you
don't have to rediscover the architecture from the source files alone. For
environment setup (SDK, keys, device files) see `AGENTS.md`. For the
narrative of *how specific quirks were discovered* (dead ends, failed
approaches, debugging steps) see `docs/TIL.md` — this document only states
the current design, not how it was arrived at.

## 1. What this app is

A Garmin Connect IQ **watch-app** (`manifest.xml` `type="watch-app"`) for
the **Fenix 8** (device id `fenix847mm`), written in Monkey C. It exists as
a testbed for exploring Connect IQ capabilities incrementally — it is not a
product. Three pages, each a self-contained proof point:

| # | Page               | Proof point                                                   |
|---|--------------------|----------------------------------------------------------------|
| 0 | Hello World        | Baseline: text rendering, input event wiring, on-screen version label |
| 1 | Compass Face       | Static-ish 2D drawing (`Dc.drawCircle`/`drawText`/`drawLine`) plus a timer-driven animation |
| 2 | Compass Bearing    | Reading a hardware sensor (`Toybox.Sensor`) and rendering live data |

App id: `b945cb81-e654-48ee-aaec-2c0a788f25d2` (manifest, arbitrary GUID,
don't regenerate it — changing it would be treated as a different app for
sideload/pairing purposes). Entry class: `HelloWorldApp` (source of truth:
`manifest.xml`'s `entry=` attribute).

## 2. High-level architecture

Every page is a standard Connect IQ `[View, InputDelegate]` pair. What
makes this codebase's structure worth explaining is the **shared paging
framework** the three pages sit on top of, built from two small files:

- **`source/Pages.mc`** — a `module` holding the ordered list of pages
  (index 0/1/2 ↔ Hello World / Compass Face / Compass Bearing) and a
  `goTo(index, transition)` helper that constructs the requested page's
  `[View, Delegate]` and calls `WatchUi.switchToView()`. This is the *only*
  place that references all three pages by name — individual pages never
  import each other, they only know their own index.
- **`source/PagedDelegate.mc`** — an abstract-ish base class every page's
  delegate extends. It stores the page's own index and implements:
  - `onNextPage()` / `onPreviousPage()` — advance/retreat the index
    (wrapping at both ends via modulo) and call `Pages.goTo()`.
  - `onKey()` — explicitly checks for `KEY_UP`/`KEY_DOWN` and routes to
    `onPreviousPage()`/`onNextPage()` (see §7 for *why* this is needed
    instead of relying on the SDK's documented automatic key-to-behavior
    translation).
  - `onBack()` — logs + shows a toast, does **not** exit or pop the view
    (see §7 for why).

Each page then is just:
- `<Page>View.mc` — `WatchUi.View` subclass, owns all drawing/sensor logic
  for that page.
- `<Page>Delegate.mc` — a near-empty `PagedDelegate` subclass whose only
  job is to call `PagedDelegate.initialize(<its own index>)`. Page 0
  (`HelloWorldDelegate`) additionally overrides `onSelect`/`onBack`/`onKey`
  /`onTap`/`onSwipe` to log + toast every input type, since it was also the
  original "what does this device send us" instrumentation point (see §8
  and `docs/TIL.md`).

Navigation is **not** a growing view stack: `WatchUi.switchToView()` pops
the current view and pushes the new one, so stack depth is always 1
regardless of how many times you page back and forth. This is why
`onBack()` can't rely on the default pop behavior (there's nothing
meaningful under the current view to pop back to) and instead is
overridden on every page via `PagedDelegate`.

## 3. App entry point

`source/HelloWorldApp.mc` — `HelloWorldApp extends Application.AppBase`.
`getInitialView()` returns `[ new HelloWorldView(), new HelloWorldDelegate() ]`
directly (page 0), rather than going through `Pages.build(0)` — this is the
one spot that's slightly redundant with `Pages.mc`, kept this way because
`getInitialView()`'s return type (`[Views] or [Views, InputDelegates]`) is
fixed by the `AppBase` contract and it reads more clearly as a literal
here. `onStart()`/`onStop()` are empty (nothing to persist across app
launches for this app).

A package-level helper `getApp() as HelloWorldApp` wraps
`Application.getApp()` with a cast — present but currently unused by any
page; kept as the idiomatic way to reach the app singleton if a future page
needs app-level state.

## 4. Pages in detail

### Page 0 — Hello World (`HelloWorldView.mc` / `HelloWorldDelegate.mc`)

The baseline page and the original input-instrumentation point.

- `HelloWorldView`: draws "Hello World!" centered (`FONT_MEDIUM`), plus a
  small version label (`"v" + APP_VERSION`, `FONT_XTINY`) near the bottom.
  `APP_VERSION` is a hand-maintained string constant — **bump it on every
  clean build** (see §9). No `onLayout` logic (static layout, nothing to
  compute from screen dimensions ahead of time).
- `HelloWorldDelegate extends PagedDelegate`: on top of the inherited
  paging/back behavior, overrides:
  - `onSelect()` — logs, shows a toast via `ButtonPressToast`, requests a
    redraw. Fires on Enter.
  - `onBack()` — overridden again here (not just inherited from
    `PagedDelegate`) purely to log a page-specific message; behavior is
    otherwise identical to the base class (log + toast + `return true`, no
    exit).
  - `onKey()` — logs every raw key event + shows a toast naming it, then
    chains to `PagedDelegate.onKey(keyEvent)` so UP/DOWN paging still
    happens after the logging/toast.
  - `onTap()` / `onSwipe()` — logged only, delegate to the default
    `BehaviorDelegate` implementation.
  - `initialize()` also `System.println`s the actual numeric `KEY_*`
    values for this device at startup (ground truth values recorded in
    `docs/TIL.md`).

### Page 1 — Compass Face (`CompassFaceView.mc` / `CompassFaceDelegate.mc`)

Static-drawing + animation proof point. No sensor input at all.

- Draws a ring (`dc.drawCircle`) sized to `min(width, height)/2 - 24`, with
  "N"/"S"/"E"/"W" labels (`FONT_MEDIUM`) at the four cardinal points on
  that ring, plus a bottom label ("Compass Face", `FONT_XTINY`).
- **Radar-sweep "hand"**: a red line from center to the ring edge that
  continuously rotates at a fixed **10 RPM** (one revolution every 6
  seconds), clockwise starting from north. This is *not* tied to the real
  compass — it's a pure animation proof point, separate from Page 2's live
  sensor reading.
  - Driven by a `Timer.Timer` (`_sweepTimer`), started in `onShow()` and
    stopped in `onHide()` — the timer only runs while this page is the
    visible one. Interval: `SWEEP_REDRAW_MS = 50` (~20 fps).
  - The angle is computed from **elapsed wall-clock time**
    (`System.getTimer() - _sweepStartMs`), not incremented per tick, so a
    delayed or dropped redraw can't slow the sweep down — it jumps to
    wherever it should currently be instead of drifting.
  - Angle math: `phaseMs = elapsedMs % SWEEP_PERIOD_MS` (integer modulo on
    the millisecond count — **Monkey C has no float `%` operator**, doing
    the modulo here before converting to radians is a hard requirement,
    not a style choice — see `docs/TIL.md`). Then
    `angle = phaseMs * SWEEP_RADIANS_PER_MS`, and endpoint
    `(cx + r·sin(angle), cy − r·cos(angle))` (0 rad = straight up = north;
    increasing angle sweeps clockwise, matching normal compass-bearing
    convention).
- `CompassFaceDelegate` is a bare `PagedDelegate` subclass with
  `initialize()` calling `PagedDelegate.initialize(1)` — no overrides, no
  page-specific input handling.

### Page 2 — Compass Bearing (`CompassBearingView.mc` / `CompassBearingDelegate.mc`)

Live-sensor proof point.

- Reads `Toybox.Sensor`'s compass heading (`Sensor.Info.heading`, a
  `Float?` in radians, true-north referenced). Requires the `Sensor`
  permission in `manifest.xml` (`<iq:uses-permission id="Sensor"/>`) — this
  isn't obvious from the field's own docs, only from the module-level
  "Requires Permission" tag in the SDK reference
  (`sdk/doc/Toybox/Sensor.html`).
- Subscribes via `Sensor.enableSensorEvents(method(:onSensor))` in
  `onShow()`, unsubscribes via `Sensor.enableSensorEvents(null)` in
  `onHide()` — sensor callbacks only run while this page is visible, same
  visibility-gated lifecycle pattern as Page 1's timer.
- `onSensor(info)` stores `info.heading` and calls
  `WatchUi.requestUpdate()`; `_headingRadians` starts `null` and stays
  `null` until the first callback fires. **Expect `null` until the
  watch's compass is calibrated** (may require the figure-8 calibration
  motion on a real device) — the view shows placeholder text ("---°" /
  "no heading") for the null case rather than crashing or showing stale
  data.
- Rendering: converts radians → degrees (`* 180.0 / Math.PI`, truncated
  via `.toNumber()`, negative-wrapped via `+= 360` if needed since
  `.toNumber()` truncation could otherwise leave a small negative value
  depending on the source angle), formats as `%03d°` (`FONT_NUMBER_MEDIUM`),
  and separately resolves a 16-point cardinal direction (N/NNE/NE/.../NNW)
  via `((degrees + 11.25) / 22.5).toNumber() % 16` indexing into a
  16-entry `DIRECTIONS` array — this is plain `Number` modulo (legal in
  Monkey C, unlike the float case in Page 1) since `degrees` is already an
  `Integer` by this point.
- `CompassBearingDelegate` is a bare `PagedDelegate` subclass,
  `initialize()` calling `PagedDelegate.initialize(2)` — no overrides.

## 5. Input handling — key/behavior semantics specific to this device

This section is the condensed, current-state version of findings narrated
in `docs/TIL.md`. Treat the SDK's documented default behaviors as
**unverified for `fenix847mm` on this Simulator** until confirmed by
`System.println` instrumentation — several documented defaults don't hold:

- **`onSelect`/`onBack` fire directly** as behavior-shortcut dispatches for
  Enter/Back, *not* via `onKey()`. Confirmed: `onKey()` never sees
  `KEY_ENTER` at all. `KEY_ESC` (Back) is different: it **double-fires** —
  once via the direct behavior shortcut, once again as a genuine
  `onKey(KEY_ESC)` hardware event shortly after. Both land on `onBack()`
  (since `onKey`'s default translation calls `onBack()` too). This is why
  `onBack()` across this codebase is written to be safe to call twice in a
  row — currently that just means "log + toast twice," since it no longer
  pops or exits (see below).
- **`onNextPage()`/`onPreviousPage()` do *not* auto-fire for UP/DOWN** on
  this device, despite SDK docs saying physical UP/DOWN buttons trigger
  them automatically (and that a `true`-returning behavior method
  suppresses the corresponding `onKey()` event). Instrumentation showed
  `onKey()` firing directly for `KEY_UP`/`KEY_DOWN` with no preceding
  behavior-method call. This is why `PagedDelegate.onKey()` explicitly
  checks for these two keys and calls `onPreviousPage()`/`onNextPage()`
  itself rather than trusting the translation.
- **`KEY_LIGHT` produces no event at all** through any override (`onKey`,
  `onTap`, `onSwipe`, `onSelect`, `onBack`) in the Simulator — likely
  needs a bezel click rather than a key, not an app bug.
  - Ground-truth numeric key codes on `fenix847mm` (`System.println`'d at
    startup from `HelloWorldDelegate.initialize()`): `UP=13 DOWN=8
    ENTER=4 ESC=5 MENU=7 LIGHT=1 START=18`.
- **The bottom-right Back button is dual-purpose**: reports `KEY_ESC` in a
  plain UI context, `KEY_LAP` during an active recording session — same
  physical button.
- **`onBack()` deliberately never exits or pops.** Originally it called
  `System.exit()` (safe to call twice, unlike the default `popView`
  behavior which crashed under the double-fire described above on a
  single-view-stack root view) — that was changed on request so BACK is
  now purely diagnostic (log + toast) and does not exit the app. There is
  currently **no in-app way to exit** other than external means (the
  Simulator's stop button, or the physical device's own app-exit gesture
  outside this app's own key handling).

## 6. Feature modules (`source/features/`)

`features/` holds small, self-contained hardware proof points that are
wired in via a single call from a delegate/view, and are **not touched
once working** (treat as stable, low-churn utility code):

- **`ButtonPressToast.mc`** — `module` with `show(key as Number)`.
  Maps a raw `WatchUi.KEY_*` value to a human-readable name (`UP`, `DOWN`,
  `ENTER`, `BACK`, `MENU`, `LIGHT`, `START`, `LAP`, `MODE`) via
  `nameForKey()`, and if recognized, calls `WatchUi.showToast(name + "
  pressed", {})` and logs to console; unrecognized keys are logged but
  produce no toast. Called from every delegate's input overrides across
  all three pages (via `PagedDelegate.onBack()` and each page's own
  `onSelect`/`onKey` overrides where present) to give consistent on-device
  visual feedback for whatever input just happened.

## 7. Resources

- `resources/strings/strings.xml` — one entry, `@Strings.AppName` =
  `"HelloWorld"`, referenced from `manifest.xml`'s `name=` attribute.
- `resources/drawables/drawables.xml` — one entry, `@Drawables.LauncherIcon`
  → `launcher_icon.png`, referenced from `manifest.xml`'s
  `launcherIcon=` attribute.
  - **Known cosmetic issue**: `launcher_icon.png` is a 40×40 placeholder;
    `fenix847mm` wants 65×65, so every build emits a harmless "will be
    scaled" warning. Replace with a properly-sized real icon before any
    real distribution.

## 8. Manifest & permissions (`manifest.xml`)

- `type="watch-app"`, `entry="HelloWorldApp"`, `minSdkVersion="5.0.1"`
  (must match what `fenix847mm` actually requires — setting it lower
  compiles fine but crashes at runtime with a cryptic `Symbol Not Found
  Error`, per `AGENTS.md`).
- `<iq:products>` lists only `fenix847mm` — single-device target, add more
  `<iq:product id="..."/>` entries here (plus their device support files,
  see `AGENTS.md`) to broaden device support.
- `<iq:permissions>` currently declares just `Sensor` (required for
  `Toybox.Sensor`/`Sensor.Info.heading` on Page 2). Any future page reading
  another restricted API (GPS/`Position`, `UserProfile`, etc.) will need
  its own `<iq:uses-permission>` entry here — check the SDK's per-module
  HTML doc's "Requires Permission" tag, since it's not always mentioned in
  the specific field/function-level docs.

## 9. Build system

- `monkey.jungle` — trivial: points at `manifest.xml`,
  `base.sourcePath = source`, `base.resourcePath = resources`. `monkeyc`
  scans `source/` recursively, so subdirectories like `source/features/`
  are picked up automatically — no per-file registration needed.
- Compile command (see `AGENTS.md` for full environment setup):
  ```
  monkeyc -d fenix847mm -f monkey.jungle -o HelloWorld.prg -y keys/developer_key.der -w
  ```
- **Versioning discipline**: `HelloWorldView.APP_VERSION` is a plain string
  constant with no automation behind it — bump it by hand on every clean
  build, following SemVer (patch/minor/major). It exists specifically so a
  build can be visually confirmed as loaded on the watch/Simulator: if you
  make a change, rebuild, and the on-screen version doesn't change, **the
  Simulator is not running your new build** (it caches the last-loaded
  `.prg` until `monkeydo` is rerun or the Simulator process is restarted —
  this is a stronger and faster signal than re-reading the Monkey C for a
  phantom bug). `strings HelloWorld.prg | grep <version>` from inside the
  container confirms the *compiled* binary is current, narrowing the
  problem to the container→Simulator hand-off if the on-screen label still
  disagrees.
- Gitignored build artifacts: `*.prg`, `*.prg.debug.xml`, `/gen/`,
  `/internal-mir/`, `/external-mir/` — all regenerated by `monkeyc`, never
  hand-edited.
- `.vscode/tasks.json` (gitignored, machine-local) holds a "Load Podman
  Build to Windows Sim" task that runs the Windows-native `monkeydo.bat`
  against the `.prg` on the shared Podman volume path, targeting
  `fenix847mm` — the concrete Windows-side invocation for whoever's
  machine that is. Not portable as-is to a different dev machine; treat it
  as a local convenience shortcut, not something to commit.

## 10. Full file reference

```
manifest.xml                  # app id/type/device/permissions/entry point
monkey.jungle                 # build file: manifest + source/resources paths
source/
  HelloWorldApp.mc             # Application.AppBase; getInitialView -> page 0
  Pages.mc                     # ordered [View,Delegate] list + switchToView helper
  PagedDelegate.mc              # shared base delegate: UP/DOWN paging, BACK logs-only
  HelloWorldView.mc            # page 0: "Hello World!" + on-screen APP_VERSION
  HelloWorldDelegate.mc         # page 0 delegate; also the input-instrumentation point
  CompassFaceView.mc           # page 1: static N/S/E/W ring + 10 RPM radar-sweep hand
  CompassFaceDelegate.mc        # page 1 delegate (no overrides beyond index)
  CompassBearingView.mc        # page 2: live Sensor.Info.heading -> degrees + cardinal
  CompassBearingDelegate.mc     # page 2 delegate (no overrides beyond index)
  features/
    ButtonPressToast.mc         # KEY_* -> human name -> toast + console log
resources/
  strings/strings.xml          # @Strings.AppName
  drawables/drawables.xml      # @Drawables.LauncherIcon
  drawables/launcher_icon.png  # placeholder 40x40 (device wants 65x65)
docs/
  TDD.md                       # this file — current-state architecture reference
  TIL.md                       # narrative dev-environment + debugging discoveries
AGENTS.md                      # environment setup / build+run instructions for a fresh session
keys/                          # gitignored: developer_key.{pem,der} signing key
sdk/                            # gitignored: Connect IQ SDK (downloaded separately)
```

## 11. Things a future session should NOT need to rediscover

- Why `onBack()` doesn't just use the default pop/exit behavior (§5).
- Why UP/DOWN paging is handled in `onKey()` instead of
  `onNextPage()`/`onPreviousPage()`'s automatic translation (§5).
- Why the sweep-hand animation math does its modulo on integer
  milliseconds rather than float radians (§4, Page 1).
- Why the on-screen version number exists and what it means if it doesn't
  change after a rebuild (§9).
- That `Toybox.Sensor` needs an explicit manifest permission, and that
  `Sensor.Info.heading` can legitimately be `null` (§4, Page 2 / §8).
- That the Simulator can't produce real orientation changes — sensor data
  there is necessarily synthetic (`Simulation → Fit Data → Simulate Data`)
  or played back from a recorded `.FIT` file (`→ Playback File`); real
  live-rotation testing needs the physical watch (see `docs/TIL.md` for
  the full explanation).
