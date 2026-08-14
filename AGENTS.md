# AGENTS.md

## Project

LiquidNotch — multi-platform SwiftUI app (iOS, macOS, visionOS). Bundle ID: `kelevo.LiquidNotch`.

## Build & Run

```bash
# Build for macOS
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS'

# Build for iOS Simulator
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=iOS Simulator,name=iPhone 16'

# Build for visionOS Simulator
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=visionOS Simulator'
```

No tests, linting, or CI are configured yet.

## Key Facts

- **Xcode 16+ with `PBXFileSystemSynchronizedRootGroup`**: source files auto-sync to the project. Do NOT edit `project.pbxproj` to add/remove files — just create or delete them on disk.
- **Swift 5.0**, deployment targets: iOS/macOS/visionOS 26.5.
- **Entry point**: `LiquidNotch/LiquidNotchApp.swift` (`@main`).
- **All app code** lives under `LiquidNotch/`.
