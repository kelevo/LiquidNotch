# AGENTS.md

## Project

LiquidNotch — macOS-only SwiftUI overlay app (Apple Silicon). Bundle ID: `kelevo.LiquidNotch`. Deployment target: macOS 26.5.

## Build & Run

```bash
# Build for macOS
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS'
```

Run from Xcode (`open LiquidNotch.xcodeproj` → `⌘R`).

No tests, linting, or CI are configured yet (GitHub Actions build workflow added in `specs/04-open-source-prep.md`).

## Key Facts

- **Xcode 16+ with `PBXFileSystemSynchronizedRootGroup`**: source files auto-sync to the project. Do NOT edit `project.pbxproj` to add/remove files — just create or delete them on disk.
- **Swift 5.0**, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- **Entry point**: `LiquidNotch/LiquidNotchApp.swift` (`@main`).
- **All app code** lives under `LiquidNotch/`.
- **Specs**: features are defined in `specs/` following the spec-driven workflow (`/spec`, `/spec-impl`).
