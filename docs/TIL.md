# TIL — Garmin Connect IQ dev environment (rootless Podman + WSL2 + Windows)

Notes from setting up Connect IQ development for a Fenix 8 inside a headless,
rootless Podman container (Fedora), hosted under WSL2 on Windows.

## Container basics

- The container has no `sudo` by default — passwordless sudo has to be enabled
  explicitly before `dnf install` works at all.
- Fedora drops old package versions fast: Fedora 44 no longer ships
  `java-17-openjdk`, only `java-25-openjdk` (current LTS) and `java-latest-openjdk`.
  Connect IQ's `monkeyc` only needs a JRE 8+, so the newer LTS is fine.
- `openssl` isn't preinstalled either — needed for generating the developer
  signing key.

## The SDK Manager GUI doesn't work on headless Linux

- Garmin's Connect IQ SDK Manager (the tool that handles the EULA, and
  downloads SDKs + per-device support files) is a GUI app.
- On modern Linux it's broken out of the box: it links against
  `libwebkit2gtk-4.0`, which Fedora/Ubuntu dropped years ago in favor of newer
  WebKitGTK versions. The actual Simulator binary is worse — it depends on
  the *ancient* WebKit1 (GTK2) library plus `libjpeg.so.8`, both long gone
  from current distro repos.
- Rather than fight that dependency chain (or wire up X11/WSLg passthrough
  into the container), it's much simpler to run the SDK Manager natively on
  the Windows host, and only compile inside the Linux container.

## The SDK is more cross-platform than it looks

- `monkeyc`/`monkeydo` on Windows are just `.bat` wrappers, but the *same SDK
  zip* also ships plain Unix shell scripts (`monkeyc`, `monkeydo`, no
  extension) that do the exact same thing: call
  `java -cp monkeybrains.jar com.garmin.monkeybrains.Monkeybrains ...`.
  `monkeybrains.jar` is plain Java bytecode — fully portable.
- Practical result: download the SDK **once** via the working Windows SDK
  Manager, copy that whole SDK folder into the container (e.g. over the
  shared Podman volume), `chmod +x` the Unix scripts, and `monkeyc` runs fine
  on Linux without a separate Linux SDK download.
- Gotcha: files copied from Windows land with CRLF line endings, which
  breaks the `#!/bin/bash` shebang (`bad interpreter: ...bash^M`). Fix with
  `sed -i 's/\r$//' monkeyc monkeydo ...` on each script before running it.

## Device support files are separate from the SDK

- The SDK zip itself does **not** contain per-device data (screen size,
  memory limits, supported features). Those are downloaded separately via
  the SDK Manager's "Devices" tab, per device variant (e.g. `fenix847mm`,
  `fenix8solar47mm`, `fenix8pro47mm`, ...).
- `monkeyc` resolves devices by looking for a `Devices/<device_id>/` folder.
  On Linux, the default lookup path is `$HOME/.Garmin/ConnectIQ/Devices/`
  (found by decompiling `Monkeybrains.class` — the `os.name` check falls
  through to `user.home + "/.Garmin/ConnectIQ/"` on non-Mac/Windows).
  Case matters: `.Garmin`, not `.garmin`.
- Copy (or symlink) the device folders you need from the Windows
  `%APPDATA%\Garmin\ConnectIQ\Devices\` into `~/.Garmin/ConnectIQ/Devices/`
  inside the container.

## Signing key

- Connect IQ apps need a developer key to compile:
  ```
  openssl genrsa -out developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
  ```
- Treat this like any other private key — keep it out of git.

## The `minSdkVersion` gotcha

- A too-low `minSdkVersion` in `manifest.xml` compiles cleanly but can crash
  at runtime with a cryptic `Symbol Not Found Error: Failed invoking
  <symbol>` — the compiler resolves symbols against an old/incompatible API
  snapshot. Set `minSdkVersion` to what the target device actually requires
  (e.g. `5.0.1` for `fenix847mm`), not an arbitrary low baseline.

## Simulator: run it on Windows, not in the container

- Compile in the Linux container, but run the graphical Simulator natively
  on Windows against the same `.prg` (reachable via the shared Podman
  volume) — sidesteps the whole legacy WebKit/X11 problem entirely.
- `monkeydo` doesn't talk to the simulator directly — it shells out to a
  small bridge tool (`shell.exe` in the Windows SDK) that connects over TCP
  (`--transport=tcp --transport_args=127.0.0.1:<port>`) to the running
  simulator. That bridge tool is Windows-only in this SDK download and the
  wire protocol is undocumented, so pushing a build from inside the
  container straight into a Windows-hosted simulator isn't practical —
  just run `monkeydo` from a Windows terminal instead.

## Setting up a clean Connect IQ project — quick summary

A minimal project needs just:

```
manifest.xml                     # app id, type, target devices, permissions
monkey.jungle                    # points at manifest + source/resource paths
source/
  MyApp.mc                       # extends Application.AppBase, getInitialView()
  MyView.mc                      # extends WatchUi.View, onUpdate() draws the screen
  MyDelegate.mc                  # extends WatchUi.BehaviorDelegate, handles input
resources/
  strings/strings.xml            # @Strings.* references used in manifest/code
  drawables/drawables.xml        # @Drawables.* (e.g. launcher icon)
keys/developer_key.der           # private signing key (gitignore this)
```

Compile:
```
monkeyc -d <device_id> -f monkey.jungle -o MyApp.prg -y keys/developer_key.der
```

`.gitignore` should exclude: the downloaded `sdk/` folder (large, proprietary,
not your code), `keys/` (private signing key), and build output (`*.prg`,
`*.prg.debug.xml`, `gen/`, `internal-mir/`, `external-mir/`).

## Debugging with `System.println()` via `monkeydo`

- When the Simulator is launched via `monkeydo.bat <prg> <device>` from a
  terminal (e.g. a VS Code task), `System.println()` output prints directly
  to *that* terminal — no separate log viewer needed. This makes
  `System.println` tracing a fast, low-ceremony way to see exactly which
  delegate/lifecycle methods fire, in what order, for a given input.

## Simulator input events don't all funnel through `onKey()`

Building a button-press proof-of-concept (toast on key press) surfaced a few
non-obvious things about how the Simulator delivers input, discovered by
instrumenting every `BehaviorDelegate`/`InputDelegate` override
(`onKey`, `onSelect`, `onBack`, `onTap`, `onSwipe`) with `System.println`:

- **`onKey()` is not a reliable single choke point.** On this device/SDK
  combo, the Simulator's Enter keyboard shortcut calls `onSelect()`
  *directly* — it never emits a `KEY_ENTER` event through `onKey()` at all.
  A feature that only hooks `onKey()` (as ours initially did) will silently
  never fire for that button. Full coverage means instrumenting the
  behavior-level overrides (`onSelect`, `onBack`, ...) too, not just the raw
  key path.
- **Esc double-fires and can crash the app.** Pressing Esc triggered
  `onBack()` directly (same direct-shortcut path as Enter/`onSelect`), *and
  then* a second, genuine `onKey(KEY_ESC)` hardware event arrived
  afterward. Our `onKey()` override forwarded that to
  `BehaviorDelegate.onKey()`'s default translation, which called `onBack()`
  a second time. The default `onBack()`'s pop-the-view-stack/exit logic
  isn't idempotent under that double call on a root view — it crashed the
  process outright (visible as the `monkeydo` terminal task just ending,
  with a leftover rendering artifact on the simulated screen). Fix: don't
  rely on the default `onBack()` behavior for a root view's Back button —
  override it to call `System.exit()` directly, which is safe to call more
  than once.
- **Not every physical button has a keyboard shortcut in the Simulator.**
  Pressing "L" for the Light button (`KEY_LIGHT`) produced *zero* console
  output — not even an unrecognized-key log — meaning the event never
  reached `onKey`, `onTap`, `onSwipe`, `onSelect`, or `onBack` at all. This
  looks like a Simulator-side gap (Light likely isn't bound to a key at
  all and needs to be clicked on the rendered device bezel instead), not
  an app bug — confirmed by the fact that every *other* key produces
  console output the moment it's pressed.
- **The actual numeric `KEY_*` values aren't worth guessing** — they're
  Garmin/device-internal and not obviously documented per-value. Printing
  `WatchUi.KEY_UP`, `KEY_DOWN`, etc. directly at startup gave the ground
  truth for `fenix847mm`: `UP=13 DOWN=8 ENTER=4 ESC=5 MENU=7 LIGHT=1
  START=18`.
- **The bottom-right Back button is dual-purpose.** It reports as
  `KEY_ESC` ("Back") in a plain UI/menu context, but as `KEY_LAP` while an
  activity/recording session is active on the device — same physical
  button, different code depending on app state.
