# Contributing to LiquidNotch

Thanks for your interest in contributing! This document explains how to report bugs, propose features, and submit pull requests.

## Code of Conduct

A formal Code of Conduct will be added in a future release. Until then, be respectful and constructive in issues and pull requests.

## Bug Reports

Use [GitHub Issues](https://github.com/kelevo/LiquidNotch/issues) to report bugs. Include:

- macOS version and hardware (Apple Silicon model).
- Steps to reproduce.
- Expected vs. actual behavior.
- Screenshots or screen recordings when relevant (use the notch overlay itself).

## Pull Requests

### Branch naming

- `feat/<short-desc>` — new features.
- `fix/<short-desc>` — bug fixes.
- `feat/spec-<NN>-<slug>` — implementation of a spec from `specs/` (e.g. `feat/spec-04-open-source-prep`).

### Commits

- Imperative mood: "Add settings panel", not "Added settings panel".
- Keep one language per repo history — Spanish or English, consistently.

### Specs

Any new feature touching more than one file must have a spec in `specs/` before the PR. The workflow is:

1. `/spec <description>` to draft the spec.
2. Review and set the state to `Approved` manually.
3. `/spec-impl <NN-slug>` to implement it on a `feat/spec-NN-slug` branch.
4. Verify acceptance criteria, set the state to `Implemented`, and open the PR.

## Style Guide

- **Swift 5.0** with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (default actor isolation is MainActor).
- **4 spaces** of indentation (Xcode default).
- **No comments** unless the code would otherwise be unclear.
- **UserDefaults keys** are namespaced: `liquidNotch.<area>.<setting>`.
- **Do not edit `project.pbxproj` manually** — Xcode 16+ uses `PBXFileSystemSynchronizedRootGroup`, so source files are auto-synced. Create/delete files on disk instead.
- **No secrets or keys** in the repository.

## Manual Testing

Build and run before opening a PR:

```bash
xcodebuild -project LiquidNotch.xcodeproj -scheme LiquidNotch -destination 'platform=macOS' build
```

Then run from Xcode (`⌘R`) and verify:

- The capsule appears centered over the notch.
- Hover expands the capsule; leaving collapses it.
- Media controls (play/pause, next, previous) work with Apple Music and Spotify.
