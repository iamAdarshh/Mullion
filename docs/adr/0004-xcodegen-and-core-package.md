# ADR-0004: XcodeGen project with a local MullionCore package

- **Status:** Accepted
- **Date:** 2026-10-19

## Context
A menu bar app needs an app bundle (Info.plist with `LSUIElement`, entitlements, signing, an asset catalog), and `SMAppService` and the Accessibility grant both work against a real `.app`. SwiftPM alone can't produce a proper app bundle. A checked-in `.xcodeproj` causes merge conflicts, and AI agents and humans struggle to edit it by hand.

## Decision
- **XcodeGen** generates `Mullion.xcodeproj` from a readable `project.yml`. The `.xcodeproj` is **gitignored**, and `make bootstrap` regenerates it.
- All pure logic lives in a **local Swift package**, `Packages/MullionCore`, with no AppKit imports (only Foundation and CoreGraphics). It is tested with `swift test`, which is fast, doesn't need Xcode open, and works well for Claude Code.
- The app target depends on MullionCore.

## Consequences
- Fast and deterministic tests for the hardest logic (geometry).
- Contributors need `brew install xcodegen`.
- Adding a file to the app target doesn't require editing the project, because `project.yml` uses folder references.
