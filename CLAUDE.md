# DiskHorizon - Claude Code Guide

DaisyDisk-style disk usage dashboard for macOS: the `DiskUsageFeature` Swift package (embedded by Bridge Commander as its Disk section) plus a standalone app in `App/`. SwiftUI + TCA (Composable Architecture).

## Tech Stack
- Swift 6.2+ toolchain (`swift-tools-version: 6.2`; Swift 6 language mode)
- SwiftUI, Composable Architecture (TCA), swift-sharing
- macOS 26.0+, Xcode 26.2+

## Structure

How a host embeds the section, the app, and the design notes and gotchas are in `README.md` — **read it before editing**, and record new non-obvious decisions there.

- `Sources/DiskUsageFeature/` — the one module: scanner, tree, reducer, views, sunburst; `DesignSystem/` holds the text-scaling and header helpers
- `Tests/DiskUsageFeatureTests/` — Swift Testing
- `App/` — the standalone app; `DiskHorizon.xcodeproj` is generated from `App/project.yml` by `xcodegen` (run in `App/`), never edited by hand
- `scripts/make-icon.swift` draws `AppIcon` and `AppIconDebug` (`swift scripts/make-icon.swift`)

## Access control
- `DiskUsageFeature` is the only product. `public` is only for the section's API to a host (`DiskUsageReducer`, `DiskUsageView`, `DiskUsageClient`, `diskUsageUIFontScale(_:)`) and the types its public state and actions expose
- `DesignSystem/` stays internal: public extension members named like the host's own (`scaledFont`, `scaledBordered`, `onMouseBackButton`, …) would make every call in Bridge Commander ambiguous
- The library logs nothing: Bridge Commander wraps `DiskUsageClient`'s removals with its activity log. Keep it free of host-specific dependencies

## Patterns
- Reducers hold state and effects; state is mutated only in reducers; async work in `Effect.run`, sending result actions
- Text scaling in every view: `.scaledFont(.caption)` / `.scaledFont(size: 12)` instead of `.font(...)`, `.scaledGlass` on glass buttons
- Indent with tabs

## Build & Test
- `swift build`, `swift test`
- Warnings are errors: every target, tests included (the loop at the end of `Package.swift`)
- Imports are explicit: the same loop enables `MemberImportVisibility`, so a file imports every module whose members it uses
- In `TestStore` assertions, mutate `@Shared` state as `$0.$x.withLock { $0 = … }`
- TCA is built with Bridge Commander's traits (`ComposableArchitecture2Deprecations`, `ComposableArchitecture2DeprecationOverloads`), so deprecated TCA APIs are errors here as there — keep the lists the same
- App: `xcodebuild -project App/DiskHorizon.xcodeproj -scheme DiskHorizon -destination 'platform=macOS' -skipMacroValidation build`
- Timing-sensitive tests (the scanner's descriptor count) can fail under heavy load; rerun them alone

## Release
- `make release` then `make publish` (RELEASE.md): Developer ID build, notarization, DMG, GitHub release with the Sparkle `appcast.xml`. The tag it creates is also the package's SwiftPM version — bump `MARKETING_VERSION` in `App/project.yml` (then `xcodegen`), never move a tag
- Sparkle (updates) is in the app target only (`App/DiskHorizon/`), never in the package: Bridge Commander has its own updater
