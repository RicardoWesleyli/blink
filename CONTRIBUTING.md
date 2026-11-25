# Contributing

Issues are more useful than pull requests right now. If you want to change something structural, open an issue first so we don't both write the same code.

## What this project will not do

These aren't roadblocks for negotiation, they're the shape of the app:

- **No camera, no eye tracking, no screen capture.** The training is visually guided on purpose. See [PRIVACY.md](PRIVACY.md).
- **No analytics, no crash reporting, no telemetry, no network calls.** A break app should not be phoning home.
- **No force.** Blink never locks the screen, blocks apps, or refuses to close. If someone doesn't want the break, the break doesn't happen.

## Building

```bash
swift build -c release
./build.sh
```

`./build.sh` assembles the `.app`, signs it ad-hoc, and produces `build/Blink.dmg`. Only the Command Line Tools are required; full Xcode is not.

## Strings

Every user-facing string goes through `L10n.s("中文", "English")`. If you add or change copy, supply both languages in the same call — a Chinese-only string will silently show Chinese to English users.

Copy in this app leans short and spoken. "Just close them" beats "Please close your eyes and relax". Prefer verbs over adjectives.

## Layout

The panel is a fixed 340 × 560. Three places have to agree or the popover will clip:

- `Views/MenuPanel.swift` — `.frame(width:height:)`
- `StatusItemController.swift` — `popover.contentSize`
- `SnapshotTool.swift` — the render size

## Screenshots

```bash
BLINK_SNAPSHOT=1 BLINK_SNAPSHOT_LANG=en BLINK_SNAPSHOT_DIR=/tmp/shot ./.build/release/Blink
```

Renders offscreen and exits, so you don't need to give anything screen recording permission.
