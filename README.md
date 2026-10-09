# LiquidNotch

> **Spanish:** LiquidNotch trae la Dynamic Island del iPhone a tu Mac: un overlay flotante sobre el notch con reproductor de música, notificaciones y temas configurables.

A lightweight macOS overlay that lives in your notch, built with SwiftUI and Apple's Liquid Glass.

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![macOS 26.5+](https://img.shields.io/badge/macos-26.5%2B-blue.svg)](#requirements)
[![Apple Silicon](https://img.shields.io/badge/platform-Apple%20Silicon-black.svg)](#requirements)

![LiquidNotch screenshot](docs/screenshot.png)

> Screenshot placeholder — contributions with captures are welcome (see [Contributing](#contributing)).

## Features

- **Dynamic Island behavior** — spring animations, shape morphing, tap and long-press gestures (spec 08).
- **Settings panel** — accessible via `Cmd+,`, right-click on the capsule, or the gear button (spec 05).
- **Two themes** — Liquid Glass (translucent with animated Apple Intelligence gradient) and Solid Black (classic Dynamic Island look), switchable in Settings (spec 06).
- **Real Liquid Glass** — powered by Apple's official `glassEffect` and `GlassEffectContainer` APIs (spec 07).
- **System notifications mirrored** — incoming notifications appear inside the island with auto-dismiss (spec 09).
- **Global audio capture** — shows whatever is playing on your Mac: browsers, players, and music apps (spec 10).
- **Media controls** — play/pause, next, previous, and a seekable progress bar for Apple Music and Spotify.

## Why

The iPhone's Dynamic Island is one of the most elegant UI patterns in recent years, and macOS has nothing like it — the notch is just empty space. LiquidNotch turns it into a living widget: music controls when you listen, notifications when they arrive, and a beautiful Liquid Glass surface in between.

It is distributed outside the App Store because it relies on a private framework to read system-wide "now playing" information (see [Known Limitations](#known-limitations)).

## Requirements

- macOS 26.5 or later
- Apple Silicon (M-series)
- Xcode 16+ (to build from source)

## Build

```bash
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS'
```

## Run

```bash
open LiquidNotch.xcodeproj
```

Then press `⌘R` in Xcode.

## Install (Release)

Download the latest build from [GitHub Releases](https://github.com/kelevo/LiquidNotch/releases).

The app is **not signed or notarized**. On first launch, macOS Gatekeeper will block it — right-click the app and choose *Open*, or run:

```bash
xattr -dr com.apple.quarantine /Applications/LiquidNotch.app
```

## Configuration

Open Settings with `Cmd+,`, by right-clicking the capsule, or with the gear button in the expanded view. See [spec 05](specs/05-settings-panel-no-menubar.md) for details.

## Project Status

| Spec | Description | State |
|---|---|---|
| [01](specs/01-island-notch-overlay-base-liquid-glass-music-player.md) | Island notch overlay base & Liquid Glass music player | Implemented |
| [02](specs/02-visual-adjustments-app-icon-ai-gradient.md) | Visual adjustments: app icon, AI gradient | Implemented |
| [03](specs/03-media-controls-seek-collapse-glow.md) | Media controls, seek, collapse glow | Implemented |
| [04](specs/04-open-source-prep.md) | Open source prep | Approved |
| [05](specs/05-settings-panel-no-menubar.md) | Settings panel, no menu bar | Draft |
| [06](specs/06-theme-system-liquid-glass-solid-black.md) | Theme system: Liquid Glass / Solid Black | Draft |
| [07](specs/07-liquid-glass-real-apple-api.md) | Real Liquid Glass (`glassEffect`) | Draft |
| [08](specs/08-dynamic-island-behavior.md) | Dynamic Island behavior | Draft |
| [09](specs/09-system-notifications-mirror.md) | System notifications mirror | Draft |
| [10](specs/10-global-audio-mediarremote.md) | Global audio via MediaRemote | Draft |

## Known Limitations

- **Private API**: reading system-wide "now playing" information uses Apple's private `MediaRemote.framework`. Apple can change or break this API in any macOS update.
- **Not App Store compatible**: because of the private framework, this app can never be submitted to the Mac App Store.
- **Unsigned**: no Developer ID signature or notarization yet (see *Install* above for the Gatekeeper workaround).
- **Apple Silicon only**: the deployment target is macOS 26.5 on Apple Silicon.

## Contributing

Contributions are welcome! Read [CONTRIBUTING.md](./CONTRIBUTING.md) first — features need a spec in [`specs/`](./specs/) before a PR.

## License

MIT — see [LICENSE](./LICENSE).

## Acknowledgments

- Apple, for the Liquid Glass material and the Dynamic Island design language.
- The SwiftUI community for samples and experiments that inspired the gradient effects.
