# Product Direction

Date frozen: 2026-04-05

This document freezes the intended product behavior while the Swift app catches up to it.

## Product Responsibilities

The app has three distinct responsibilities:

- task system:
  - the app owns the canonical task list and all task metadata
- calendar integration:
  - Apple Calendar is used to read existing busy time
  - accepted suggested work blocks are written back into calendar
- planner:
  - the planner combines user-selected planning constraints, calendar availability, and task metadata to generate suggested work blocks

## Source Of Truth Contract

Apple Calendar is not the source of truth for tasks.

The frozen contract is:

- tasks live in the app database
- calendar events are external reality and busy-time input
- accepted suggestions become output events in calendar
- `ScheduledBlock` is the bridge object linking tasks to calendar events
- calendar writeback happens only after explicit user acceptance
- app-side linkage must remain so later edits and deletions can be reconciled

## Intended User Workflow

1. User opens the app.
2. User goes to the `Calendar` screen.
3. The screen shows a minimal calendar overview of existing events and busy time.
4. User taps `Generate Plan`.
5. A lightweight planning input flow appears so the user can choose:
   - what task types to consider
   - what date range or planning horizon to fill
   - optionally what kinds of work blocks to prefer
6. The app generates proposed scheduled blocks from the task list.
7. These proposals appear visually on the calendar as temporary suggestion blocks.
8. Each suggestion block offers:
   - `Accept`
   - `Reject / Refresh`
9. `Accept` persists the scheduled block and writes the event into the configured write calendar.
10. `Reject / Refresh` discards that proposal and generates another option.
11. Accepted suggestions remain linked to their originating tasks.

## Implementation Guidance Frozen For Now

- SwiftUI app shell + SwiftData + EventKit is the product path.
- Python remains a behavioral reference for planner logic until it is ported to Swift.
- The next implementation milestone is the planner interaction shell in SwiftUI.
- The first planner shell can use deliberately simple ranking logic as long as the end-to-end user loop works.
