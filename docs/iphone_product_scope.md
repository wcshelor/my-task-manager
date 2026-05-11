# iPhone Migration Scope

Status: frozen for the first migration pass on April 6, 2026.

The app remains work in progress. This document is historical scope for the first iPhone migration pass, not a complete inventory of newer modules.

## Product Scope

- Supported platforms: macOS and iPhone only.
- Supported sync scope: one user, one Apple ID, personal-device sync only.
- App-owned data that should eventually sync across devices:
  - tasks
  - scheduled blocks
  - app settings that affect planner behavior
- External data that does not sync through the app:
  - Apple Calendar events themselves

## Product Priorities

- Make task capture fast enough to feel native on iPhone.
- Keep task review and edit flows available on both Mac and iPhone.
- Keep planner and calendar workflows available on both devices without rewriting the domain stack.
- Preserve the existing architecture boundaries:
  - SwiftData owns app data.
  - EventKit owns calendar permissions, reads, writes, and reconciliation.
  - planner logic stays pure Swift and UI-independent.

## Explicit Deferrals

- collaboration or multi-user sync
- task sharing with other people
- web or non-Apple clients
- iPad-specific polish
- widgets, Live Activities, Apple Watch, or complications
- CloudKit implementation before the local app model and iPhone shell are stable

## Success Criteria For This Migration Stage

- The shared Swift app builds for macOS and iPhone.
- The app launches in the iPhone simulator.
- Shared models, repositories, planner code, and EventKit abstractions remain unified.
- Platform differences stay isolated to app shell and view composition, not persistence or planner logic.
