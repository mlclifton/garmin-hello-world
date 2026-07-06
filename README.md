# garmin-hello-world

A minimal "Hello World" watch app for the Garmin Fenix 8, built with the
Connect IQ SDK (Monkey C). This started as a proof that the dev environment
— a rootless Podman container (Fedora), hosted under WSL2 on Windows — can
actually build and run Connect IQ apps.

## What's here

```
manifest.xml                  # app id, type, target device(s), permissions
monkey.jungle                 # build file: points at manifest + source/resources
source/
  HelloWorldApp.mc             # app entry point
  HelloWorldView.mc            # draws "Hello World!" on screen
  HelloWorldDelegate.mc         # input handling
resources/
  strings/strings.xml          # app name string
  drawables/drawables.xml      # launcher icon
docs/
  TIL.md                        # notes on setting up the dev environment
```

Not tracked in git (see `.gitignore`): the downloaded Connect IQ SDK (`sdk/`,
large and proprietary) and the private developer signing key (`keys/`).

## Building

Targets device id `fenix847mm` (Fenix 8, 47mm/51mm). With the Connect IQ SDK's
`bin/` on your `PATH` and a developer key generated at `keys/developer_key.der`:

```
monkeyc -d fenix847mm -f monkey.jungle -o HelloWorld.prg -y keys/developer_key.der
```

See [`docs/TIL.md`](docs/TIL.md) for the full environment setup story,
including gotchas around headless Linux, device support files, and the
`minSdkVersion` setting.

## License

MIT — see [LICENSE](LICENSE).
