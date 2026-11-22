# asuskeysd + asusbl

User-space half of the F-row solution on the VivoBook K3605ZF.

- `asuskeysd` — CGEvent tap daemon. Maps F4–F12 keycodes to actions
  (brightness, display mirroring, mic mute, screenshot, MyASUS).
  F7 (keycode 98) runs `kbd-backlight.sh`.
- `asusbl` — CLI that talks to the patched `AsusSMC` kext through its
  `IOUserClient` (selector 0 = set level, selector 1 = get level).
- `kbd-backlight.sh` — hook executed by the daemon: `asusbl +`.

## Build

```sh
./build.sh
```

Requires Xcode command line tools (`swiftc`, `clang`).

## Install

```sh
./install.sh
```

Then grant **Accessibility** to `~/Applications/AsusKeys/asuskeysd`
(System Settings → Privacy & Security → Accessibility). The permission is
bound to the binary; every rebuild needs it again.

## How F7 works

Two independent paths, both end at the kext:

| Key | Path |
|---|---|
| `Fn+F7` | EC query `_Q78` → `IANE(0xC7)` → `AsusSMC` steps the level |
| `F7` (Fn-lock on) | EC query `_Q16/_Q17` → `IANE(0xC4/0xC5)` → `AsusSMC` steps the level |
| `F7` raw event | `asuskeysd` keycode 98 → `kbd-backlight.sh` → `asusbl +` → `IOUserClient` |

The daemon swallows the raw `Fn+F7` event (`code == 98` with
`.maskSecondaryFn`) so the kext does not step twice.

Cycle: off → 1 → 2 → 3 → off.

## Notes

- If the daemon logs `event tap denied`, Accessibility is missing.
- `asusbl` needs the patched kext from this repository; the stock AsusSMC
  1.4.1 has no `IOUserClient`.
