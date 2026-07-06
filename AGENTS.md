# AGENTS.md

Everything a fresh session needs to keep developing this Garmin Connect IQ
project without re-deriving the environment setup. See
[`docs/TIL.md`](docs/TIL.md) for the full narrative/why; this file is the
condensed, actionable version.

## What this is

A "Hello World" Connect IQ watch app for the Garmin Fenix 8
(device id `fenix847mm`), written in Monkey C.

## Environment

- Working inside a **rootless Podman container** running Fedora, itself
  hosted under **WSL2 on Windows**. The container is headless — no X11,
  no GUI.
- Passwordless `sudo` is available for `dnf install`.
- `java` (OpenJDK 25) and `openssl` are already installed system-wide via
  `dnf`. `gh` (GitHub CLI) is installed and authenticated as `mlclifton`
  (`gh auth setup-git` has been run, so plain `git push`/`pull` work).
- The project directory is on a **Podman named volume**
  (`w4w_build-project`), which is reachable from the Windows host directly
  (no WSL `\\wsl$` bridge needed) — this is how files get exchanged with
  Windows-side tools.

## Things that are gitignored and may be MISSING in a fresh checkout

These are real directories used during development but intentionally not in
git (see `.gitignore`). If they're missing, dev work (compiling, signing)
will not work until they're restored:

- **`sdk/`** — the Connect IQ SDK (currently version `9.2.0`). Not
  redistributable/too large for git. To restore: download it again via the
  Connect IQ SDK Manager running **natively on the Windows host** (the SDK
  Manager GUI does not work inside this Linux container — see TIL.md for
  why), then copy the whole SDK folder into `sdk/` here. Its Unix scripts
  (`sdk/bin/monkeyc`, `sdk/bin/monkeydo`, etc.) need `chmod +x` and CRLF
  stripped before they'll run:
  ```
  sed -i 's/\r$//' sdk/bin/monkeyc sdk/bin/monkeydo
  chmod +x sdk/bin/monkeyc sdk/bin/monkeydo
  ```
- **`keys/developer_key.der`** (and `.pem`) — the private signing key. If
  missing, regenerate (this invalidates any prior signed builds/pairing,
  so prefer restoring the original file from backup if it exists):
  ```
  mkdir -p keys
  openssl genrsa -out keys/developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in keys/developer_key.pem -out keys/developer_key.der -nocrypt
  ```
- **Device support files** — not part of `sdk/` at all; downloaded
  separately via the SDK Manager's "Devices" tab on Windows. This
  container currently has them at `/home/dev/project/.Garmin/ConnectIQ/Devices/`
  (containing `fenix847mm`, `fenix8pro47mm`, `fenix8solar47mm`,
  `fenix8solar51mm`), symlinked from the path `monkeyc` actually looks up
  by default on Linux:
  ```
  ~/.Garmin/ConnectIQ/Devices -> /home/dev/project/.Garmin/ConnectIQ/Devices
  ```
  (Note the capital `.Garmin` — case-sensitive.) If this symlink or target
  is missing, recreate it, copying device folders from the Windows
  `%APPDATA%\Garmin\ConnectIQ\Devices\` if needed.

## Build

```
cd hello_world   # this repo
export PATH="$PWD/sdk/bin:$PATH"
monkeyc -d fenix847mm -f monkey.jungle -o HelloWorld.prg -y keys/developer_key.der -w
```

`-w` shows warnings. Add `-r` to strip debug info for a release build, `-e`
to package as a distributable `.iq`.

## Versioning

- The on-screen version label ("v2.0" etc., drawn near the bottom of the
  screen in `source/HelloWorldView.mc`, `APP_VERSION` constant) exists so a
  build can be visually confirmed as loaded on the watch/simulator. **Bump
  it every time you make a clean build**, following
  [SemVer](https://semver.org) (`MAJOR.MINOR.PATCH`): patch for fixes,
  minor for backwards-compatible features, major for breaking changes.

## Known gotchas

- **`minSdkVersion` in `manifest.xml` must match what the target device
  actually requires** (`fenix847mm` needs `5.0.1`+). Setting it too low
  compiles fine but crashes at runtime with a cryptic
  `Symbol Not Found Error: Failed invoking <symbol>`.
- The launcher icon (`resources/drawables/launcher_icon.png`) is currently
  a placeholder 40x40 solid-color PNG — `fenix847mm` actually wants 65x65,
  so builds emit a (harmless) scaling warning. Replace with a real icon at
  the correct size if this becomes a published/distributed app.

## Running/testing the app

There's no way to run the graphical Simulator inside this container (would
require legacy WebKit1/GTK2 libs Fedora no longer ships, plus X11/WSLg
passthrough). Instead:

1. Compile here in the container (above).
2. On the **Windows host**, with the Connect IQ Simulator running
   (`sdk/bin/simulator.exe`, or the Windows-native SDK's copy of it), run:
   ```
   monkeydo.bat "<path-to-this-repo-on-the-shared-volume>\HelloWorld.prg" fenix847mm
   ```
   The `.prg` built in the container is directly reachable from Windows via
   the shared Podman volume — no copying needed.
3. Alternatively, sideload `HelloWorld.prg` to a physical Fenix 8 by copying
   it to `GARMIN/APPS/` on the watch when connected over USB (from Windows).

There is no way to push a build from inside this container straight to a
Windows-hosted Simulator process — the `monkeydo` → Simulator link is a
Windows-only TCP bridge tool (`shell.exe`) with an undocumented protocol.

## Git / GitHub

- Repo: https://github.com/mlclifton/garmin-hello-world (public, MIT
  licensed).
- Remote `origin` already configured over HTTPS; `gh auth setup-git` makes
  plain `git push`/`git pull` work without extra credential prompts.
- Local git identity is set (`mike clifton` / `mike.l.clifton@gmail.com`).

## Project layout

```
manifest.xml                  # app id, type, target device(s), permissions
monkey.jungle                 # build file: points at manifest + source/resources
source/
  HelloWorldApp.mc             # app entry point (getInitialView -> page 0)
  Pages.mc                     # ordered page list + switchToView navigation helper
  PagedDelegate.mc              # shared base delegate: UP/DOWN page, BACK exits
  HelloWorldView.mc            # page 0: onUpdate() draws "Hello World!"
  HelloWorldDelegate.mc         # page 0 delegate (extends PagedDelegate)
  CompassFaceView.mc           # page 1: static compass face (N/S/E/W ring)
  CompassFaceDelegate.mc        # page 1 delegate (extends PagedDelegate)
  CompassBearingView.mc        # page 2: live Sensor.Info.heading readout
  CompassBearingDelegate.mc     # page 2 delegate (extends PagedDelegate)
  features/                    # self-contained hardware proof points, each
                                # wired in via one line from a delegate/view
                                # lifecycle method; not touched once working
    ButtonPressToast.mc         # shows a toast naming the button pressed
resources/
  strings/strings.xml          # @Strings.AppName
  drawables/drawables.xml      # @Drawables.LauncherIcon
docs/TIL.md                    # narrative notes on the environment setup
```

## Page navigation

The app is 3 pages, switched with `WatchUi.switchToView()` (no view stack
growth) via `PagedDelegate`'s `onNextPage()`/`onPreviousPage()`, which any
delegate can call directly by index. Pages loop at both ends. `Pages.mc`
holds the ordered `[View, Delegate]` list so a delegate can move to the
next/previous page without importing the others by name. `BACK` exits the
app directly (`System.exit()`) from any page — see the Known gotchas
section below for why the default `popView` behavior isn't used.

`BehaviorDelegate` is documented as auto-translating physical UP/DOWN keys
into `onPreviousPage()`/`onNextPage()` before `onKey()` ever runs (and
skipping `onKey()` entirely if the behavior method returns `true`) — but on
`fenix847mm` in this Simulator, that translation doesn't fire: `onKey()`
was observed firing directly for UP/DOWN with no preceding
`onNextPage`/`onPreviousPage` call. So `PagedDelegate.onKey()` checks
`WatchUi.KEY_UP`/`KEY_DOWN` explicitly and calls
`onPreviousPage()`/`onNextPage()` itself rather than relying on that
translation. Same category of gap as the `KEY_LIGHT` finding below —
don't assume a documented default key/behavior mapping holds on this
device without checking `onKey()` output first.

The compass bearing page (page 2) reads `Toybox.Sensor.Info.heading`, which
requires the `Sensor` permission in `manifest.xml` (already added).
