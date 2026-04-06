# Concrete Plan

Status update as of April 6, 2026.

This file is meant to answer two questions:

1. What is actually true in the repo right now?
2. What should happen next, in order?

## Current State

### Done

- the Swift app is the real product path
- app-owned tasks, calendar busy-time reads, and explicit accept-before-writeback are the frozen product contract
- SwiftData persists:
  - tasks
  - scheduled blocks
  - app settings
- repository seams exist and are used in the live app
- the planner engine exists in pure Swift
- the Calendar tab is now a planner-first UI, not a read-only diagnostic surface
- EventKit-backed services exist for:
  - permission status and access requests
  - readable calendar discovery
  - excluded-calendar-aware event reads
  - fixed write-calendar validation
  - event create / update / delete
  - reconciliation of accepted blocks against external calendar moves and deletes
- accepting a suggestion now:
  - persists an accepted `ScheduledBlock`
  - writes the linked event into the configured write calendar
  - saves linkage metadata back onto the block
  - marks the task as `scheduled`
- accepted scheduled blocks now support:
  - edit
  - reschedule to the selected slot
  - cancel
  - delete
- selected-slot transient suggestions are now cleared when the selected slot changes or is cleared
- planner refresh/load reconciles accepted blocks against external calendar drift
- Swift, Python, and smoke-test automation all pass

### Partially Done

- reconciliation exists, but it is not yet driven by a dedicated `EKEventStoreChanged` observer
- task scheduling semantics still partly live in `MyTask.status` instead of being fully derived from scheduled blocks
- rejected suggestions are still session-local only
- the planner still surfaces one best candidate per gap rather than a richer alternative set
- settings are persisted, but there is still no user-facing settings UI
- permission handling has sensible inline copy, but there is still no broader onboarding / recovery flow

### Not Done

- real manual EventKit validation of the new planner/writeback lifecycle
- dedicated settings UI
- richer planner alternatives or multi-task packing inside one selected slot
- CloudKit sync

## Architecture Snapshot

### Persistence

Done:

- `TaskRecord`
- `ScheduledBlockRecord`
- `AppSettingsRecord`
- `TaskRepository`
- `ScheduledBlockRepository`
- `SettingsRepository`
- SwiftData repository implementations for all three

Still open:

- richer persistence for diagnostics beyond the current block-level reconciliation fields
- stronger derivation rules between active scheduled blocks and task status

### Calendar Boundary

Done:

- `CalendarPermissionProviding`
- `CalendarListing`
- `CalendarReading`
- `CalendarWriting`
- `CalendarReconciling`
- a shared `EKEventStore` owner in `AppContainer`
- EventKit adapters for read/write/delete/reconcile

Still open:

- dedicated store-change observation while the app remains frontmost
- broader manual validation across real calendars and error paths

### Planner Boundary

Done:

- planner-facing value types are independent of SwiftUI, EventKit, and SwiftData
- busy-time merging, free-gap detection, and ranking exist in Swift
- the planner view model owns transient selection and suggestion state

Still open:

- richer planner behavior than "one best suggestion per gap"
- persistent suggestion history / alternative exploration

## What Changed In This Cycle

- fixed the stale selected-slot suggestion problem by clearing slot-scoped transient suggestions when the slot changes or is cleared
- finished accepted-block lifecycle operations in the planner UI and view model:
  - edit
  - reschedule
  - cancel
  - delete
- added EventKit update/delete coverage for those lifecycle operations
- added reconciliation of accepted blocks against external calendar moves and deletes
- added planner refresh points that actually run reconciliation
- updated repo docs to match the current checkout instead of the earlier pre-planner state

## Ordered Next Steps

These are the next highest-value tasks in order.

### 1. Do A Real Manual EventKit Pass

This is now the top priority. The code paths exist; live validation is the missing confidence layer.

Required checklist:

- permission states:
  - not determined
  - granted full access
  - denied
  - restricted if reproducible
  - write-only if reproducible
- excluded read calendars:
  - confirm excluded calendars do not appear as busy-time input
  - confirm non-excluded calendars still do
- write-calendar selection:
  - confirm the configured write calendar is used
  - confirm missing or ambiguous write-calendar configurations fail clearly
- accept flow:
  - create a suggestion
  - accept it
  - confirm the linked calendar event is created in the right calendar
- accepted-block lifecycle:
  - edit the block
  - reschedule the block
  - cancel the block
  - delete the block
  - confirm matching EventKit updates/deletes happen
- reconciliation:
  - move the linked event externally in Calendar.app
  - delete the linked event externally in Calendar.app
  - confirm planner refresh/app re-activation reconciles the local block state
- error handling:
  - missing write calendar
  - non-writable write calendar
  - revoked permission after launch
  - event missing at update/delete time

Definition of done:

- a real manual note exists under `docs/test_sessions/`
- README and this file can stop saying the EventKit pass is still outstanding

### 2. Add Dedicated Store-Change Observation

Current behavior is acceptable but incomplete:

- reconciliation runs on planner refresh
- reconciliation runs on planner load
- reconciliation runs when the app becomes active

Still missing:

- automatic response to `EKEventStoreChanged` while the app remains frontmost

Definition of done:

- external Calendar changes are picked up without requiring manual refresh or app re-activation
- tests cover the observation trigger path

### 3. Build The Settings UI

Persisted settings already matter to live behavior, but there is no UI for them yet.

The first settings screen should expose:

- excluded read calendars
- write calendar title
- minimum gap minutes
- default assumed duration
- planner suggestion cap

Definition of done:

- users can change these settings in-app
- changes affect the planner without editing storage manually

### 4. Improve Planner Quality

The current planner is good enough for an MVP loop, but not yet good enough for broader use.

Next improvements:

- more than one candidate per free gap
- richer alternatives within a selected slot
- better regeneration after rejection
- possible multi-task packing when the slot is large

Definition of done:

- selected-slot planning can show meaningful alternatives instead of mostly one candidate
- rejection feels like a real alternative-search path rather than a session-local blocklist

### 5. Tighten Scheduling Semantics

The model still lets task status and scheduled-block truth drift apart in some cases.

Next cleanup:

- decide what should be derived from active scheduled blocks
- reduce duplicated scheduling meaning in `MyTask.status`
- make reconciliation and block lifecycle updates the primary driver of scheduling truth

Definition of done:

- task scheduling state is predictable after accept/edit/reschedule/cancel/delete/reconcile

### 6. Keep CloudKit Out Of The Critical Path

CloudKit is still a later milestone.

Do not start sync work before:

- the manual EventKit pass is done
- store-change observation is done
- settings UI exists
- scheduling semantics are tighter

## Testing Status

### Automated

Current repo-wide checks:

- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test`
- `pytest -q`
- `python3 scripts/core_smoke_check.py`

Current automated confidence is strong for:

- Swift task models and repositories
- Swift planner engine behavior
- Swift planner view-model lifecycle behavior
- EventKit adapter behavior with mocks
- Python reference behavior and smoke surfaces

### Manual

Current manual confidence is still weak for:

- real EventKit permission prompts
- live calendar inclusion/exclusion behavior
- real write-calendar routing
- real Apple Calendar update/delete/reconcile behavior

That is why the manual EventKit pass is the top next step.

## Risks To Watch

### Risk 1: Live EventKit Reality Still Lags Automation

Current state:

- automated coverage is good
- real Calendar.app behavior is still not manually signed off

### Risk 2: Frontmost External Changes Are Not Fully Automatic Yet

Current state:

- refresh/load/app-active reconciliation exists
- dedicated live store-change observation does not

### Risk 3: Task Status Still Carries Scheduling Meaning

Current state:

- partly mitigated
- not fully normalized

### Risk 4: Planner Quality Could Stall After The MVP Loop

Current state:

- end-to-end workflow works
- suggestion richness still needs a second pass

## Bottom Line

The biggest architectural gaps from the earlier plan are no longer the problem.

The repo now has:

- a real planner UI
- real EventKit writeback
- accepted-block lifecycle operations
- reconciliation support

The next work should stop being speculative architecture and start being product hardening:

1. manually validate EventKit behavior for real
2. add dedicated store-change observation
3. expose planner/calendar settings in the UI
4. improve planner alternatives
