# Concrete Plan

Status update as of April 4, 2026.

Legend:

- `Done`: implemented and present in the repo
- `Mostly done`: the intended structure exists, but follow-up work is still needed
- `Partially done`: some of the shape is present, but the user-facing feature loop is incomplete
- `Not started`: still absent

## High-Level Summary

Done or mostly done:

- the Swift app now has a real composition root
- local SwiftData persistence exists for tasks, scheduled blocks, and app settings
- repository seams exist
- planner and calendar boundary types/protocols exist
- the EventKit read path now exists for permission status, readable-calendar discovery, and event normalization
- the Swift task-list surface is backed by repository data rather than a view-local sample array
- Swift and Python automated tests both pass

Partially done:

- scheduled-block modeling exists, but there is no planner or calendar write loop yet
- settings are modeled and persisted, but only calendar-read exclusions drive live runtime behavior today
- the task status model still coexists with scheduled-block truth instead of being fully derived from it

Not started:

- permission flow UI
- planner engine in Swift
- suggestion acceptance/writeback
- reconciliation
- CloudKit sync

## 1. Architectural Shape To Freeze Now

Status: `Mostly done`

### Persistence Boundary

Done:

- SwiftData model types exist for:
  - `TaskRecord`
  - `ScheduledBlockRecord`
  - `AppSettingsRecord`
- repository protocols exist for:
  - `TaskRepository`
  - `ScheduledBlockRepository`
  - `SettingsRepository`
- SwiftData repository implementations exist for all three repositories

Still missing:

- reconciliation diagnostics storage beyond the current block-level fields
- richer persistence rules around derived task scheduling state

### Calendar Boundary

Mostly done:

- the boundary exists as protocols and result/report types in `Calendar/CalendarContracts.swift`
- `CalendarListing` now exists alongside the original calendar seams
- EventKit-backed permission, calendar-listing, and read services exist under `Calendar/EventKit/`
- the rest of the app does not directly depend on EventKit today

Not done:

- no calendar writer or reconciler
- no `EKEventStoreChanged` observer

### Domain / Planner Boundary

Partially done:

- plain Swift planner-facing structs exist:
  - `CalendarEventSnapshot`
  - `BusyInterval`
  - `FreeGap`
  - `TaskPlanningInput`
  - `SuggestionCandidate`
  - `PlannerOutput`
- these types are independent of SwiftUI, EventKit, and SwiftData

Not done:

- no planner engine
- no Swift port of the Python ranking and gap-placement behavior

## 2. Concrete Coding Decisions

Status: `Partially done`

### Model Decision 1: Use App-Owned IDs Everywhere

Status: `Done`

- `MyTask.id` is app-owned `UUID`
- `ScheduledBlock.id` is app-owned `UUID`
- SwiftData records persist app-owned IDs as durable identifiers
- no EventKit identifier is being used as a primary key

### Model Decision 2: Split Scheduling State From Reconciliation State

Status: `Done`

- `ScheduledBlockStatus` exists with workflow state
- `CalendarLinkState` exists with calendar-link state

This split is already present in the code and should be kept.

### Model Decision 3: Normalize Calendar Data Immediately

Status: `Mostly done`

- `CalendarEventSnapshot` exists
- `BusyInterval` exists
- EventKit read services now normalize calendar events into `CalendarEventSnapshot`

Still missing:

- no pipeline yet from calendar snapshots into merged planner busy intervals / planner input

### Model Decision 4: Make Task Scheduling Semantics Explicit

Status: `Partially done`

- `MyTask.hasActiveScheduledBlock(in:)` exists
- `ScheduledBlock.isActivelyScheduled` exists

Still missing:

- task scheduling state is not yet derived automatically from scheduled blocks
- task status can still drift from scheduled-block truth because there is no acceptance/reconciliation loop

### Model Decision 5: Make Settings Fixed But Still Modeled

Status: `Done`

- `AppSettings` exists
- MVP defaults are modeled:
  - excluded read calendars
  - write calendar title
  - minimum gap minutes
  - default assumed duration
  - planner suggestion cap
- settings are persisted through `AppSettingsRecord` and `SwiftDataSettingsRepository`

## 3. Suggested Swift Module / Folder Layout

Status: `Partially done`

Present now:

- `App/`
- `Models/`
- `Persistence/`
- `Calendar/`
- `Calendar/EventKit/`
- `Planner/Models/`
- `Features/Tasks/`
- `Views/`

Present but not in the originally suggested final place:

- task list and task form UI still live under `Views/` instead of being fully moved under `Features/Tasks/`

Still missing from the suggested layout:

- `Planner/Engine/`
- `Features/Planner/`
- `Features/Settings/`
- `Features/Onboarding/`
- `Diagnostics/`

## 4. The Protocols To Define First

Status: `Done`

Defined today:

- `CalendarReading`
- `CalendarListing`
- `CalendarWriting`
- `CalendarReconciling`
- `CalendarPermissionProviding`

This seam is already in place and should remain the integration contract.

## 5. Permissions Subsystem

Status: `Partially done`

Done:

- `CalendarPermissionStatus` exists with the intended cases
- EventKit permission service implementation exists
- full-access vs write-only-insufficient mapping exists

Not done:

- no UI for requesting permission
- no explicit task-only-mode messaging
- no user-visible fallback flow

## 6. EventKit Service Design

Status: `Partially done`

Done:

- a single shared `EKEventStore` owner exists in the live `AppContainer`
- permission checks
- readable calendar discovery
- read-only event fetch and normalization into `CalendarEventSnapshot`

Still needed:

- `Important` calendar resolution
- read/write/delete helpers
- store-change observation

## 7. Reconciliation Design

Status: `Not started`

Done:

- `ReconciliationIssue`
- `ReconciliationReport`
- scheduled-block state needed for reconciliation (`calendarEventIdentifier`, `calendarTitle`, `lastSyncedAt`, `syncErrorMessage`)

Not done:

- no reconciler implementation
- no foreground / planner-load / refresh triggers
- no response to external calendar moves/deletes

## 8. Suggested Implementation Order

### Phase 1: Freeze Contracts

Status: `Mostly done`

Done:

- core Swift planner models exist
- calendar protocols exist
- repository protocols exist
- settings are modeled
- app-owned IDs are used

Still useful follow-up:

- centralize date/calendar helpers
- add explicit error types around calendar and planner failures

### Phase 2: Add Real Persistence

Status: `Mostly done`

Done:

- SwiftData models exist
- repository implementations exist
- task list is repository-backed
- settings repository exists
- repository tests exist and pass

Still missing:

- no manual relaunch audit was performed in this review
- no archived/completed business-rule layer beyond current CRUD/state editing
- no migration story beyond the current prototype stage

### Phase 3: Calendar Read Path Only

Status: `Mostly done`

Done:

- EventKit permission service exists
- readable-calendar discovery exists
- excluded read-calendar settings are applied to live reads
- event fetch maps into `CalendarEventSnapshot`
- mock-based tests cover permission, listing, and read normalization

Still missing:

- no UI consuming the read layer yet
- no busy-interval / gap pipeline yet
- no manual validation against a real EventKit store in this audit

### Phase 4: Port Planner Logic Into Swift

Status: `Not started`

The Python planner remains the current reference implementation.

### Phase 5: Accept Suggestion Writeback

Status: `Not started`

There is no suggestion UI, no accepted-block flow, and no calendar write path.

### Phase 6: Reconciliation

Status: `Not started`

No implementation yet.

### Phase 7: CloudKit Sync Polish

Status: `Not started`

No CloudKit wiring is present.

## 9. Proper Testing Strategy

Status: `Partially done`

### Layer 1: Pure Unit Tests

Status: `Mostly done`

Done today:

- Python unit tests for:
  - models
  - gap detection
  - planner candidate selection
  - calendar read parsing
  - compatibility behavior
- Swift unit tests for:
  - task model cleanup
  - task form validation/parsing
  - task-list search/sort/grouping behavior
  - EventKit permission mapping
  - readable-calendar exclusion behavior
  - calendar event normalization and read ordering

Still missing:

- pure Swift planner-engine tests because the planner engine does not exist yet

### Layer 2: Repository Tests

Status: `Done`

Done today:

- `SwiftDataTaskRepositoryTests`
- `SwiftDataScheduledBlockRepositoryTests`
- `SwiftDataSettingsRepositoryTests`

Important note:

- these tests were crashing before this audit because repositories were being initialized from `ModelContext` while the in-memory `ModelContainer` was immediately dropped
- repository initialization now retains the `ModelContainer`, and the suite passes

### Layer 3: Calendar Adapter Tests With Mocks

Status: `Partially done`

Done:

- mock-based tests exist for the EventKit permission service
- mock-based tests exist for readable-calendar exclusion behavior
- mock-based tests exist for read normalization/filtering behavior

Not done:

- no writer or reconciler adapter tests exist because those implementations do not exist yet

### Layer 4: Manual Integration Matrix

Status: `Partially done`

Done:

- there are Python-oriented manual session notes under `docs/test_sessions/`

Not done:

- no current Swift manual integration matrix exists for live EventKit permission/read behavior
- no current manual UI verification document for the Swift app task-list surface

## 10. The Exact Tests To Add First

Status: `Mixed`

Already present in some form:

- repository tests for tasks, scheduled blocks, and settings
- Python equivalents of planner ranking and gap-detection coverage
- Swift tests for permission-state mapping and calendar-read normalization/filtering

Still needed on the Swift side:

- planner-engine tests once the engine exists:
  - gap detection
  - overlap merging
  - ranking behavior
  - default-duration behavior
- calendar reconciliation tests
- acceptance-flow tests

Recommended next high-value Swift tests:

- `PlannerEngineTests`
- `PlannerAcceptanceFlowTests`
- `CalendarReconcilerTests`
- `EventKitWriterTests`
- `EventStoreChangeObserverTests`

## 11. Risk Areas To Watch

### Risk 1: Task Status Still Carries Scheduling Meaning

Current state:

- partly mitigated by `hasActiveScheduledBlock(in:)`
- still unresolved at the product-flow level

### Risk 2: EventKit Layer Stops At Read-Only

Current state:

- real EventKit read behavior now exists
- writeback, reconciliation, and change observation are still absent

### Risk 3: Python / Swift Behavior Drift

Current state:

- Python is still the richer planner reference
- Swift has planner contracts but no engine

### Risk 4: Settings Exist Without UI Or Runtime Usage

Current state:

- settings persist correctly
- `excludedReadCalendarTitles` now drives live calendar reads
- most remaining settings are not yet driving live planner/calendar behavior because those systems are missing

### Risk 5: Manual Reality Lags Behind Automated Coverage

Current state:

- automated coverage is now decent for current surfaces
- manual Swift app verification is still light

## 12. Recommended Definition Of Done For Each Milestone

### Milestone A: Data Foundation Done

Status: `Mostly done`

Evidence:

- no view-local sample array drives the main task list
- repositories exist and tests pass
- app composition is container-based
- local SwiftData persistence is wired in the live app path

Remaining caution:

- this audit did not perform a multi-relaunch or long-running manual persistence pass

### Milestone B: Calendar Read Done

Status: `Mostly done`

Evidence:

- EventKit permission, calendar-listing, and read services exist
- excluded calendar settings affect live read behavior
- calendar read services are injected through `AppContainer`
- adapter tests pass

Remaining caution:

- no UI path uses the read layer yet
- this audit did not manually verify live calendars or permission prompts

### Milestone C: Planner Done

Status: `Not started`

### Milestone D: Accept / Write Done

Status: `Not started`

### Milestone E: Reconciliation Done

Status: `Not started`

### Milestone F: Sync Done

Status: `Not started`

## 13. Short Practical Marching Orders

Current best next sequence:

1. Keep the current Swift data foundation stable.
2. Surface the new EventKit permission/read layer in minimal UI and manually verify it against real calendars.
3. Port the Python planner behavior into a pure Swift planner engine with tests.
4. Build suggestion acceptance and calendar writeback.
5. Implement reconciliation before adding polish features like CloudKit sync or broader UI expansion.

Bottom line:

- the Swift app is now the real app shell
- SwiftData is now the live local persistence layer
- Python remains the behavior reference, not the integration target
- the next major missing milestone is turning the new calendar read path into planner/writeback behavior, not more task-list polish
