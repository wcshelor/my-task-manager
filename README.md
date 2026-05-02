# Task Manager

This repo currently has two active code paths:

- an Apple SwiftUI app in `apple_app/task-manager/` targeting macOS and iPhone
- a legacy Python planner/calendar prototype in `src/`

The Swift app is the real product path. The Python code is still useful as a reference implementation and regression surface, but it is not wired into the Swift UI.

## Verification Snapshot

This README was updated against the repo state in this checkout on April 10, 2026.

Automated checks run during this update:

- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test` -> `passed`
- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build` -> `passed`
- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing` -> `passed`
- `pytest -q` -> `27 passed`
- `python3 scripts/core_smoke_check.py` -> `8 passed, 0 failed`

Additional runtime checks run during this update:

- `xcrun simctl list runtimes` -> `iOS 26.3 (26.3.1 - 23D8133)`
- `xcrun simctl list devices available` -> available devices include `iPhone 17`
- `xcrun simctl boot D015EDAE-E08D-4EA4-9178-80164B787D70` -> `passed`
- `xcrun simctl install D015EDAE-E08D-4EA4-9178-80164B787D70 .../task-manager.app` -> `passed`
- `xcrun simctl launch D015EDAE-E08D-4EA4-9178-80164B787D70 camp.task-manager` -> `launched (pid 71725)`

Not manually verified during this update:

- no live macOS click-through of the newest planner UI
- no full iPhone simulator tap-through of quick add, swipe actions, or planner interactions after the successful iPhone 17 launch smoke
- no real EventKit permission-state pass against a live calendar account
- no live verification of excluded read calendars
- no live verification of fixed write-calendar selection
- no live verification of accept/edit/reschedule/cancel/delete flows against Apple Calendar
- no live verification of reconciliation behavior after external calendar edits or deletes

## Repo Layout

- `apple_app/`: shared SwiftUI Apple app, SwiftData persistence, EventKit integration, planner engine, and Swift tests
- `src/`: Python prototype modules for models, planner logic, scheduling, and calendar experimentation
- `tests/`: Python pytest suite
- `scripts/`: smoke checks and manual-session helpers
- `docs/`: product direction, testing notes, planner notes, and archived manual sessions
- `data/`: local JSON data and manual-test backups
- `concrete_plan.md`: current implementation status and ordered next steps

## Product Contract

The current product contract is:

- tasks live in the app database
- Apple Calendar is external busy-time input
- accepted planner suggestions are written back to Apple Calendar only after explicit user acceptance
- `ScheduledBlock` is the bridge object linking app tasks to calendar events
- calendar drift must be reconciled back into app-owned scheduled-block state

## Swift App Status

The Swift app lives in `apple_app/task-manager/`.

### What Works Today

- the shared Apple target builds for macOS and iPhone simulator SDKs
- the macOS Swift test suite passes
- the iPhone simulator test bundle builds successfully
- this machine now has an installed iOS 26.3 simulator runtime and multiple available simulator devices
- the current app launches on a live `iPhone 17` simulator in addition to passing simulator SDK builds
- the app shell is a two-tab SwiftUI app:
  - `Tasks`
  - `Calendar`
- the `Tasks` tab supports create, edit, delete, search, sort, and grouping
- new tasks now default to `Inbox`, with no due date and neutral priority / energy / work-mode defaults
- on iPhone, the `Tasks` tab now has a separate quick-add capture path with:
  - title
  - notes
  - easy quarter-hour duration choices
  - optional due date
  - a `More Details` handoff into the full editor while keeping shared form logic
- the full task editor still supports:
  - title
  - notes
  - status
  - estimated minutes
  - priority
  - energy level
  - work mode
  - comma-separated tags
  - UUID editing on macOS
- task rows now surface compact metadata for due date, duration, priority, and inbox / scheduled / archived state
- iPhone task rows now support swipe delete plus contextual complete / archive / reopen actions
- local persistence is wired through SwiftData repositories for:
  - tasks
  - scheduled blocks
  - app settings
- live app composition goes through `AppContainer` and `AppEnvironment`
- EventKit-backed services now exist for:
  - permission state / access request
  - readable calendar discovery
  - event reads with excluded-calendar filtering
  - fixed write-calendar validation
  - calendar event create / update / delete
  - scheduled-block reconciliation against external calendar moves and deletes
- the `Calendar` tab is now a planner-first surface
- the planner screen can:
  - show current calendar permission state
  - request full calendar access
  - manually refresh planner/calendar state
  - refresh again when the app becomes active
  - refresh again when EventKit posts store-change notifications while the app stays frontmost
  - show a selected-day timeline with:
    - real fetched calendar events
    - accepted scheduled blocks
    - transient planner suggestions
  - navigate between days
  - click open timeline regions to create a quarter-hour-aligned temporary selection
  - drag to expand the temporary selection in 15-minute increments
  - clear stale selected-slot suggestions when the selected slot changes or is cleared
  - hide the temporary day-calendar `Fill` overlay once slot suggestions render so the generated task blocks do not overlap it
  - use the selected slot as the primary planning window through the inline slot planner panel
  - use a secondary `Plan by Horizon` flow for broader windows:
    - `Next 2 Hours`
    - `Rest of Today`
    - `Tomorrow`
    - `Next 7 Days`
  - add lightweight planning constraints before generating suggestions:
    - work mode
    - tags
    - priority emphasis
  - generate transient planner suggestions from:
    - real EventKit events as busy time
    - active scheduled blocks as additional busy time
    - SwiftData task metadata
    - persisted planner settings
    - either an explicitly selected slot or a preset horizon
  - accept a suggestion and:
    - validate the configured fixed write calendar
    - persist an accepted `ScheduledBlock`
    - write a real EventKit event into the configured calendar
    - store linkage metadata back onto the `ScheduledBlock`
    - update the linked task status to `scheduled`
  - accept or reject a transient suggestion inline from the day-calendar block with check / x controls, or from the agenda cards
  - reject a suggestion locally and avoid immediately regenerating the exact same suggestion during the same planner session
  - manage already-accepted scheduled blocks from the agenda:
    - edit start/end time in a sheet
    - move a block into the currently selected open slot
    - cancel a block while preserving local canceled history
    - delete a block entirely
  - update or remove the matching EventKit event when an accepted block is edited, rescheduled, canceled, or deleted
  - reconcile accepted blocks on planner refresh/load so that:
    - external calendar moves update the saved block interval
    - external calendar deletes mark the block as deleted externally
    - the UI surfaces moved/sync-warning states on scheduled blocks

### Current Planner Engine

The first-pass planner engine is implemented in pure Swift.

Current behavior:

- converts calendar events and active scheduled blocks into busy intervals
- merges overlapping or touching busy intervals
- computes free gaps inside the requested planning window
- filters out completed, archived, and already-actively-scheduled tasks
- scores tasks with deterministic heuristics:
  - tasks that fit the gap are preferred
  - due-soon tasks are preferred
  - higher-priority tasks are preferred
  - durations close to the available gap are preferred
  - missing durations use the default assumed duration from settings
- supports both:
  - a selected custom time slot
  - a preset horizon window
- produces one best suggestion per gap, capped by the configured suggestion limit
- keeps suggestions transient until the user accepts one

### What Exists But Is Still Partial

- the app now has live iPhone simulator launch confidence on this machine, but the quick-add, swipe-action, and planner flows still have not had a full manual tap-through in this update
- the iPhone full editor still uses the same detailed form as macOS, so more phone-specific tightening may still be worthwhile after live use
- `AppSettings` persistence exists, but there is still no user-facing settings screen
- rejected suggestions are still session-local only
- the planner currently surfaces one best candidate per gap, so a selected slot usually yields one best suggestion at a time
- the task status model still coexists with scheduled-block truth instead of being fully derived from it
- no real manual EventKit validation pass has been completed for the new write/update/delete/reconciliation loop

### What Is Not Implemented Yet In Swift

- persistent rejected-suggestion history across launches
- multi-task packing or broader alternative sets inside one selected slot
- settings management UI
- stronger onboarding / recovery flows for denied, restricted, or write-only calendar states
- CloudKit sync

## Current Swift Architecture

Relevant folders:

- `apple_app/task-manager/task-manager/App/`: app composition and environment
- `apple_app/task-manager/task-manager/Models/`: task and scheduling domain types
- `apple_app/task-manager/task-manager/Persistence/`: repository protocols, SwiftData records, repositories, and container factory
- `apple_app/task-manager/task-manager/Calendar/`: calendar contracts, EventKit services, and stubs
- `apple_app/task-manager/task-manager/Planner/`: planner domain contracts and pure Swift planner engine
- `apple_app/task-manager/task-manager/Features/Tasks/`: task list view model
- `apple_app/task-manager/task-manager/Features/Planner/`: planner presentation models and planner view model
- `apple_app/task-manager/task-manager/Views/`: task and planner SwiftUI views

Boundary intent in the current Swift app:

- SwiftData persists tasks, scheduled blocks, and settings
- EventKit services own permission, calendar listing, read normalization, writeback, reconciliation, and store-change observation
- planner code owns busy-time normalization, gap detection, ranking, and suggestion generation
- the planner view model coordinates repositories, calendar services, and transient UI state

## Swift Test Coverage

Swift tests currently cover:

- task model cleanup and validation
- task form parsing and validation
- task collection behavior
- task-list search, sorting, and grouping
- task-list quick complete / reopen / archive transitions
- SwiftData task repository behavior
- SwiftData scheduled-block repository behavior
- SwiftData settings repository behavior
- EventKit permission-status mapping
- readable-calendar exclusion behavior
- calendar event normalization and filtering
- write-calendar validation
- calendar event create / update / delete behavior
- reconciliation of accepted blocks after external moves and deletes
- frontmost store-change observation trigger behavior
- planner engine gap merging, gap detection, ranking, and default-duration behavior
- planner timeline quarter-hour alignment, point-to-slot conversion, drag expansion, and open-region selection rejection when busy time is tapped
- planner view-model loading, slot-based and horizon-based plan generation, exact selected-slot timing, accept/reject flow behavior, stale slot-suggestion clearing, accepted-block lifecycle actions, accepted-block timeline rendering, mirrored write-calendar event suppression, and transient rejection behavior

Relevant Swift test files:

- `apple_app/task-manager/task-managerTests/Calendar/EventKitCalendarServicesTests.swift`
- `apple_app/task-manager/task-managerTests/Features/TaskListViewModelTests.swift`
- `apple_app/task-manager/task-managerTests/Models/MyTaskTests.swift`
- `apple_app/task-manager/task-managerTests/Models/MyTaskFormDataTests.swift`
- `apple_app/task-manager/task-managerTests/Models/MyTaskCollectionTests.swift`
- `apple_app/task-manager/task-managerTests/Models/TaskListPresentationTests.swift`
- `apple_app/task-manager/task-managerTests/Persistence/SwiftDataTaskRepositoryTests.swift`
- `apple_app/task-manager/task-managerTests/Persistence/SwiftDataScheduledBlockRepositoryTests.swift`
- `apple_app/task-manager/task-managerTests/Persistence/SwiftDataSettingsRepositoryTests.swift`
- `apple_app/task-manager/task-managerTests/Planner/PlannerEngineTests.swift`
- `apple_app/task-manager/task-managerTests/Planner/PlannerTimelineGridTests.swift`
- `apple_app/task-manager/task-managerTests/Planner/PlannerViewModelTests.swift`

## Python Prototype Status

The Python code under `src/` is still present and tested.

It currently provides:

- task, project, event, scheduled-block, and preference models
- planner candidate ranking logic
- free-gap detection
- scheduler/session generation
- compatibility and roundtrip helpers
- Apple Calendar read/prototype integration via older AppleScript-era code paths

Current Python tests:

- `tests/test_models.py`
- `tests/test_planner.py`
- `tests/test_gap_detection.py`
- `tests/test_calendar_read.py`
- `tests/test_compatibility.py`

What the Python side is not:

- it is not the current product UI
- it is not integrated into the Swift app
- it is not the long-term EventKit integration path

## Running The Repo

### Swift App

Open `apple_app/task-manager/task-manager.xcodeproj` in Xcode and run the `task-manager` scheme.

Build for macOS from the command line:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' build
```

Run macOS Swift tests:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test
```

Build the iPhone app against the simulator SDK:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build
```

Build the iPhone test bundle for testing:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing
```

This machine now has an installed `iOS 26.3` simulator runtime and multiple available devices. A live launch smoke was verified on `iPhone 17`, but a broader manual phone workflow pass is still outstanding.

### SwiftUI macOS Debugging Notes

Useful patterns from local scripting/debugging experiments on the Swift app:

- For layout or AppKit-bridge issues, a small scratch harness that hosts the target SwiftUI view in `NSHostingView` inside a plain `NSWindow` is much faster than repeatedly launching the full app.
- Recursively dumping the `NSView` tree is useful when SwiftUI labels do not map cleanly to AppKit controls. In this app, the task-form `Toggle` bridged to `FocusRingNSButton`, and the visible text lived in a sibling hosting view, not in `NSButton.title`.
- In headless/local CLI experiments, `button.performClick(nil)` and posted Quartz `CGEvent` mouse clicks did not reliably propagate back into SwiftUI state. Synthesized `NSEvent.mouseEvent(...)` events routed through the owning `NSWindow` were more reliable for driving the real control path.
- `System Events` / AppleScript is fine for process-level checks, but UI-element scripting can stall or fail if Accessibility access is not available. For repeatable debugging from the shell, in-process AppKit harnesses are more dependable.
- Keep model and form-state validation covered with ordinary Swift tests, and use the AppKit harness only for view/layout bugs that depend on real macOS control behavior.

### Python Prototype

Create the environment:

```bash
conda env create -f environment.yml
conda activate task-manager-test
```

Run the Python tests:

```bash
pytest -q
```

Run the smoke check:

```bash
python3 scripts/core_smoke_check.py
```

## Current Reality

Implemented and verified:

- shared Swift task workflow foundations for macOS and iPhone
- SwiftData-backed task, scheduled-block, and settings repositories
- EventKit-backed permission, calendar listing, event reads, writeback, block edits, block deletes, reconciliation, and frontmost store-change observation
- Swift planner UI with selected-slot-first planning and real transient suggestions
- pure Swift planner engine for busy-time merging, free-gap detection, and ranking
- accepted planner suggestions persisted as `ScheduledBlock` records and written to the configured calendar
- accepted-block edit/reschedule/cancel/delete lifecycle in the planner
- iPhone simulator runtime availability and successful `iPhone 17` launch smoke on April 10, 2026
- planner rejection behavior scoped to the current planning session
- Python planner, scheduler, gap-detection, compatibility, and smoke-test coverage

Still intentionally deferred:

- real manual EventKit validation of permission states, excluded calendars, write-calendar selection, accept flow, lifecycle actions, and error handling
- a broader manual iPhone workflow pass after the April 10, 2026 simulator launch smoke
- persistent rejected suggestions
- settings and onboarding UX
- richer multi-suggestion packing inside a single selected slot
- sync beyond the current local prototype

## Related Docs

- `concrete_plan.md`: current repo status and next steps
- `docs/iphone_product_scope.md`: frozen scope for the first macOS+iPhone migration pass
- `docs/iphone_readiness_audit.md`: platform audit and sequencing notes for the iPhone migration
- `docs/product_direction.md`: frozen product responsibilities and target workflow
- `docs/planner_contract_v0_1.md`: Python planner contract summary
- `docs/testing_workflow.md`: repo-wide testing workflow
