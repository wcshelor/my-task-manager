# Concrete Plan

Status update as of April 10, 2026.

This file answers three questions:

1. What is actually true in the repo right now?
2. What should happen next, in execution order?
3. What is the longer-term plan after the immediate hardening work?

## Verified Snapshot

Automated checks were re-run against this checkout on April 10, 2026:

- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test` -> passed
- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build` -> passed
- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing` -> passed
- `pytest -q` -> `27 passed`
- `python3 scripts/core_smoke_check.py` -> `8 passed, 0 failed`

Additional runtime checks:

- `xcrun simctl list runtimes` -> `iOS 26.3 (26.3.1 - 23D8133)`
- `xcrun simctl list devices available` -> multiple available devices, including `iPhone 17`
- `xcrun simctl boot D015EDAE-E08D-4EA4-9178-80164B787D70` -> passed
- `xcrun simctl install D015EDAE-E08D-4EA4-9178-80164B787D70 .../task-manager.app` -> passed
- `xcrun simctl launch D015EDAE-E08D-4EA4-9178-80164B787D70 camp.task-manager` -> launched with pid `71725`

## Current State

### Done

- the Swift app is the real product path
- the Python code remains a tested reference surface, not the product UI
- app-owned tasks, calendar busy-time reads, and explicit accept-before-writeback are still the frozen product contract
- SwiftData persists:
  - tasks
  - scheduled blocks
  - app settings
- repository seams exist and are used in the live app
- the shared Swift app builds for macOS and iPhone simulator SDKs
- the live app shell is a two-tab SwiftUI app:
  - `Tasks`
  - `Calendar`
- the `Tasks` tab supports:
  - create
  - edit
  - delete
  - search
  - sort
  - grouping
- new tasks default to `Inbox` with neutral defaults
- the iPhone task flow now includes a dedicated quick-add capture path
- the machine now has an installed iPhone simulator runtime and available simulator devices
- the app has been installed and launched successfully on a live `iPhone 17` simulator
- the `Calendar` tab is now a planner-first surface, not a read-only diagnostic screen
- the planner engine exists in pure Swift
- EventKit-backed services exist for:
  - permission status and access requests
  - readable calendar discovery
  - excluded-calendar-aware event reads
  - fixed write-calendar validation
  - event create / update / delete
  - reconciliation of accepted blocks against external calendar moves and deletes
- frontmost `EKEventStoreChanged` observation now triggers planner refresh without waiting for app re-activation
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
- selected-slot transient suggestions are cleared when the selected slot changes or is cleared
- planner refresh, planner load, and app activation reconcile accepted blocks against external calendar drift
- the testing workflow, session template, and manual-session helper now reflect the planner-first Swift app and reusable EventKit / simulator checklists
- Swift, Python, and smoke-test automation all pass

### Partially Done

- task scheduling semantics still partly live in `MyTask.status` instead of being fully derived from scheduled blocks
- rejected suggestions are still session-local only
- the planner still surfaces one best candidate per gap rather than a richer alternative set
- settings are persisted, but there is still no user-facing settings UI
- permission handling has sensible inline copy, but there is still no broader onboarding / recovery flow
- the new iPhone quick-add flow now has simulator launch confidence on this machine, but not yet a full manual narrow-width workflow pass
- the iPhone full editor still uses the same detailed form as macOS, so more narrow-width tightening is still likely after live phone use

### Still Not Done

- a real manual EventKit validation pass against live calendars
- a broader manual iPhone simulator or device workflow pass covering quick add, swipe actions, planner layout, and permission copy
- dedicated settings UI
- richer planner alternatives or multi-task packing inside one selected slot
- persistent rejected-suggestion history
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

- stronger derivation rules between active scheduled blocks and task status
- richer persistence for diagnostics beyond the current block-level reconciliation fields

### Calendar Boundary

Done:

- `CalendarPermissionProviding`
- `CalendarListing`
- `CalendarReading`
- `CalendarWriting`
- `CalendarReconciling`
- `CalendarChangeObserving`
- a shared `EKEventStore` owner in `AppContainer`
- EventKit adapters for read / write / delete / reconcile / observe

Still open:

- broader manual validation across real calendars and error paths

### Planner Boundary

Done:

- planner-facing value types are independent of SwiftUI, EventKit, and SwiftData
- busy-time merging, free-gap detection, and ranking exist in Swift
- the planner view model owns transient selection and suggestion state

Still open:

- richer planner behavior than "one best suggestion per gap"
- persistent suggestion history / alternative exploration
- tighter derivation between planner outcomes and task scheduling state

## Completed In This Pass

- refreshed `docs/testing_workflow.md`, `docs/manual_test_session_template.md`, and `scripts/manual_test_session.sh` to match the current Swift planner, EventKit, and iPhone validation workflow
- added frontmost `EKEventStoreChanged` observation to the planner flow and covered the trigger path in `PlannerViewModelTests`
- verified simulator runtime availability, booted `iPhone 17`, installed and launched the app, and logged the result in `docs/test_sessions/2026-04-10_iphone_simulator_launch_smoke.md`

## Immediate Execution Queue

These are the next steps that should happen before broader feature expansion or sync work.

### 1. Do A Real Manual EventKit Pass

This is still the top priority. The code paths exist; live validation is the missing confidence layer.

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
  - confirm matching EventKit updates or deletes happen
- reconciliation:
  - move the linked event externally in Calendar.app
  - delete the linked event externally in Calendar.app
  - confirm planner refresh or app re-activation reconciles the local block state
- error handling:
  - missing write calendar
  - non-writable write calendar
  - revoked permission after launch
  - event missing at update or delete time

Definition of done:

- a real manual note exists under `docs/test_sessions/`
- README and this file can stop saying the EventKit pass is still outstanding
- the manual testing workflow docs are updated if the live behavior differs from current assumptions

### 2. Do A Full Live iPhone Workflow Pass On The Now-Available Simulator

The runtime-install blocker is gone. The next gap is not simulator availability, but a real narrow-width workflow pass.

Required checklist:

- keep `xcrun simctl list runtimes` and `xcrun simctl list devices available` returning usable entries
- keep the app launchable in the simulator
- verify:
  - quick add
  - task review and edit
  - swipe actions
  - planner screen layout
  - selected-slot planning interactions
  - permission-state copy on iPhone

Definition of done:

- a short simulator validation note exists under `docs/test_sessions/` with actual UI observations, not just launch smoke
- README and this file can describe iPhone confidence as live workflow confidence, not just launch/build confidence

### 3. Build The First Settings UI

Persisted settings already affect live planner behavior, but there is still no in-app way to change them.

The first settings screen should expose:

- excluded read calendars
- write calendar title
- minimum gap minutes
- default assumed duration
- planner suggestion cap

Definition of done:

- users can change these settings in-app
- changes affect the planner without editing storage manually

## Near-Term Hardening After The Immediate Queue

These should happen after the three immediate steps above are complete or well underway.

### 4. Tighten Scheduling Semantics

The model still lets task status and scheduled-block truth drift apart in some cases.

Next cleanup:

- decide what should be derived from active scheduled blocks
- reduce duplicated scheduling meaning in `MyTask.status`
- make reconciliation and block lifecycle updates the primary driver of scheduling truth

Definition of done:

- task scheduling state is predictable after accept, edit, reschedule, cancel, delete, and reconcile flows

### 5. Strengthen Permission And Recovery UX

The app has workable inline copy for permission states, but not a broader user recovery path.

Next improvements:

- better denied and restricted guidance
- clearer handling when the configured write calendar is missing or unwritable
- better recovery when permission changes after launch

Definition of done:

- permission failures feel like a recoverable product flow, not just surfaced errors

### 6. Tighten iPhone UX After Live Use

The new phone capture flow exists, but the remaining work should be driven by real narrow-width use, not guesswork.

Next improvements:

- tighten the full editor where it still feels Mac-shaped
- simplify dense planner controls where phone use exposes friction
- keep platform differences in view composition, not domain logic

Definition of done:

- the common iPhone task and planner flows feel deliberate rather than merely portable

## Long-Term Product Plan

### 7. Improve Planner Quality

The current planner is good enough for an MVP loop, but not yet good enough for broader use.

Next improvements:

- more than one candidate per free gap
- richer alternatives within a selected slot
- better regeneration after rejection
- persistent rejected-suggestion history across launches
- possible multi-task packing when the slot is large

Definition of done:

- selected-slot planning shows meaningful alternatives instead of mostly one candidate
- rejection feels like real alternative search rather than a session-local blocklist

### 8. Keep The Python Prototype In Reference Mode

The Python code still has value as a regression and behavior reference surface, but it should not become a second product path.

Guideline:

- keep Python tests healthy
- use Python as a reference when it helps validate planner behavior
- avoid new Python feature work unless it directly supports Swift planning or regression coverage

### 9. Add Personal-Device Sync Only After The Local Product Loop Is Stable

CloudKit remains a later milestone.

Do not start sync work before:

- the manual EventKit pass is done
- the live iPhone pass is done
- store-change observation is done
- settings UI exists
- scheduling semantics are tighter

Once sync starts, the intended scope is still:

- one user
- one Apple ID
- personal-device sync only
- sync for app-owned data:
  - tasks
  - scheduled blocks
  - planner-affecting settings
- Apple Calendar events themselves remain external and are not app-synced

### 10. Keep Explicit Deferrals Deferred

Still out of scope for now:

- collaboration or multi-user sync
- task sharing with other people
- web or non-Apple clients
- iPad-specific polish
- widgets
- Live Activities
- Apple Watch
- complications

## Testing Status

### Automated

Current repo-wide checks:

- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test`
- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build`
- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing`
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
- live calendar inclusion and exclusion behavior
- real write-calendar routing
- real Apple Calendar update, delete, and reconcile behavior
- full iPhone workflow behavior beyond the April 10 simulator launch smoke

That is why the manual EventKit pass and simulator pass are the top two execution items.

## Risks To Watch

### Risk 1: Live EventKit Reality Still Lags Automation

Current state:

- automated coverage is good
- real Calendar.app behavior is still not manually signed off

### Risk 2: iPhone Confidence Is Better, But Still Not Workflow-Complete

Current state:

- iPhone builds cleanly
- the app now launches on `iPhone 17`
- the narrow-width task and planner flows still need a real tap-through

### Risk 3: Task Status Still Carries Scheduling Meaning

Current state:

- partly mitigated
- not fully normalized

### Risk 4: Planner Quality Could Stall After The MVP Loop

Current state:

- the end-to-end workflow works
- suggestion richness still needs a second pass

## Bottom Line

The repo is no longer blocked on missing architecture. The immediate work is now product hardening and live validation.

Execution order:

1. manually validate the real EventKit loop
2. do a full live iPhone workflow pass on the now-available simulator
3. expose planner and calendar settings in the UI

After that, focus on:

- tighter scheduling semantics
- stronger permission and recovery UX
- iPhone-specific tightening based on live use
- richer planner alternatives

CloudKit stays out of the critical path until those foundations are stable.
