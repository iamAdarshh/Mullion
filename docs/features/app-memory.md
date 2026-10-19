# Feature spec: App memory

**Milestone:** M7. **Status:** Draft. **Inspired by:** FancyZones "Move newly created windows to their last known zone"

## Summary
When enabled for an app, a newly opened window of that app is placed in the zone (or snapped action) where the user last put one of its windows.

## Behaviour
- Off by default. Turn it on globally in *Settings → Zones → Remember app positions*, and override it per app in a list.
- Mullion records, per bundle ID and display UUID, the **last zone index and layout ID** or the **last action ID**. It does not record raw frames, so the data survives resolution changes.
- On `kAXWindowCreatedNotification` (via one `AXObserver` per running app that has memory enabled), wait for the window to settle (≤ 300 ms, or until its frame stops changing), then place it.
- Skip dialogs, sheets and panels: only act on `kAXStandardWindowSubrole`.
- Skip the window if the user starts moving it before it has been placed.

## Storage
`~/Library/Application Support/Mullion/app-memory.json`, versioned.
```json
{ "schemaVersion": 1,
  "entries": [ { "bundleID": "com.apple.Terminal", "displayUUID": "…", "layoutID": "…", "zoneIndex": 2 } ] }
```

## Limitations (to document in the README)
- Mullion can't tell which document a window shows, so it remembers per app, not per document.
- Apps that restore their own window frames on launch (many document-based apps) may fight Mullion. Users can turn memory off for those apps.

## Acceptance criteria
- AM-1: Terminal, with memory on, opens a new window into the remembered zone within 500 ms.
- AM-2: Save and Open panels are never moved.
- AM-3: Turning the feature off stops all `AXObserver`s.
