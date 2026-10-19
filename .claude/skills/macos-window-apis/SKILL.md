---
name: macos-window-apis
description: Reference for the macOS Accessibility (AXUIElement), NSScreen, event monitor/CGEventTap, ScreenCaptureKit and SMAppService patterns used in Mullion, with known pitfalls. Load when writing or debugging code in App/Sources/Accessibility, Input, Overlay or System.
user-invocable: false
paths:
  - "App/Sources/Accessibility/**"
  - "App/Sources/Input/**"
  - "App/Sources/Overlay/**"
  - "App/Sources/System/**"
---

# macOS window APIs: patterns and pitfalls

## Accessibility trust
```swift
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
let trusted = AXIsProcessTrustedWithOptions(opts)   // shows prompt once; returns current state
```
- Poll `AXIsProcessTrusted()` once per second while onboarding is visible. There's no notification for it.
- The grant is tied to the code signature and bundle ID. Debug and release use different bundle IDs on purpose.

## Focused window
```swift
guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
let axApp = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(axApp, 0.25)
var value: CFTypeRef?
let err = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value)
guard err == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
// swiftlint:disable:next force_cast
let window = value as! AXUIElement   // safe only after the CFGetTypeID check above
```
- Skip the window if `kAXSubroleAttribute` ≠ `kAXStandardWindowSubrole`, or if `"AXFullScreen"` is true.
- Don't act on Mullion's own windows (compare the pid with `ProcessInfo.processInfo.processIdentifier`).

## Position and size are AXValues
```swift
var point = CGPoint(x: 100, y: 50)
guard let axPoint = AXValueCreate(.cgPoint, &point) else { throw AXWindowError.valueEncoding }
try AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPoint).check()

var out = CGPoint.zero
guard CFGetTypeID(value) == AXValueGetTypeID() else { throw AXWindowError.unexpectedType }
// swiftlint:disable:next force_cast
AXValueGetValue(value as! AXValue, .cgPoint, &out)  // as! is safe: type checked on the line above
```
- The order is **size → position → size** (see ARCHITECTURE §5).
- `AXEnhancedUserInterface` on the *application* element: read it, set it to false, move the window, then restore the original value.

## Screens
- `NSScreen.screens.first` is the primary screen (the one with the menu bar). Its height is the reference for flipping coordinates.
- `visibleFrame` excludes the menu bar and Dock. Recompute it on `NSApplication.didChangeScreenParametersNotification`.
- Display UUID: `CGDisplayCreateUUIDFromDisplayID(id)`, using the `NSScreenNumber` key from `screen.deviceDescription`.

## Mouse monitoring
- Passive: `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged])`. It never sees Mullion's own events (add a local monitor for those if needed).
- `NSEvent.mouseLocation` is in **AppKit** space. `CGEvent.location` is in **AX/Quartz** space.
- Active tap (Grab & Move only): `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, …)`. Return `nil` to swallow an event. Handle the `.tapDisabledByTimeout` and `.tapDisabledByUserInput` event types by calling `CGEvent.tapEnable(tap:enable:true)`.

## Overlay panel
```swift
let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
panel.level = .statusBar
panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
panel.ignoresMouseEvents = true
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
```
Check `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` and fade instead of animating the frame when it's set.

## Login item
`try SMAppService.mainApp.register()` / `unregister()`. Read `.status` for the UI. If the status is `.requiresApproval`, open `SMAppService.openSystemSettingsLoginItems()`.

## System tiling check (macOS 15+)
Read only: `UserDefaults(suiteName: "com.apple.WindowManager")?.object(forKey: "EnableTilingByEdgeDrag")`. A nil value means the system default, which is on. **Never write it.**

## Never use
`_AXUIElementGetWindow`, `CGSSetWindowLevel`, `SLS*`, `CGSMoveWindow`, or anything found via `dlsym`. See ADR-0003.
