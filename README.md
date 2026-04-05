# Task Manager

This repository currently contains two active prototype surfaces:

- a macOS SwiftUI app in `apple_app/task-manager/`
- a Python planning/calendar prototype in `src/`

The Swift app is the current product-facing prototype. The Python code still contains the richer planner, compatibility, and calendar-prototype logic, but it is not wired into the Swift app.

## Verification Snapshot

This README was updated against the actual repo state on April 4, 2026.

Automated checks run during this audit:

- `pytest` -> `27 passed`
- `python3 scripts/core_smoke_check.py` -> `8 passed, 0 failed`
- `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test` -> `passed`

Not verified during this audit:

- no manual click-through of the macOS app UI
- no manual validation of the live EventKit permission prompt or real-calendar read behavior

## Repo Layout

- `apple_app/`: SwiftUI macOS prototype, SwiftData persistence scaffolding, and Swift tests
- `src/`: Python prototype modules for models, planner logic, scheduling, and calendar experimentation
- `tests/`: Python pytest suite
- `scripts/`: smoke checks and manual-session helpers
- `docs/`: planner contract notes, testing notes, and earlier manual session logs
- `data/`: local JSON data and manual-test backups
- `concrete_plan.md`: current implementation plan with status tracking

## Swift App Status

The Swift app lives in `apple_app/task-manager/`.

### What Works Today

- the macOS target builds and its Swift test suite passes
- the visible app surface is a task list backed by `TaskListViewModel`
- users can create, edit, and delete tasks from the SwiftUI task form
- task fields currently supported in the form are:
  - UUID
  - title
  - notes
  - status
  - estimated minutes
  - optional due date
  - priority
  - energy level
  - work mode
  - comma-separated tags
- task-list search matches title, notes, and tags
- task-list sorting supports created date, title, due date, estimated minutes, priority, and status
- task-list grouping supports none, status, priority, due date bucket, and work mode
- local persistence is wired through SwiftData repositories for tasks, scheduled blocks, and app settings
- the app composition root now uses `AppContainer` and `AppEnvironment`
- live app composition now wires EventKit-backed calendar permission, calendar-listing, and read-only fetch services
- excluded read-calendar titles from settings are applied when fetching calendar events

### What Exists In Code But Is Still Scaffolding

- `ScheduledBlock`, `CalendarLinkState`, and `AppSettings` domain models exist
- SwiftData models and repositories exist for tasks, scheduled blocks, and settings
- calendar seams now exist for:
  - `CalendarReading`
  - `CalendarListing`
  - `CalendarWriting`
  - `CalendarReconciling`
  - `CalendarPermissionProviding`
- EventKit-backed read-path services exist for:
  - full-access permission status/request
  - readable calendar discovery
  - read-only event fetch mapped into `CalendarEventSnapshot`
- planner boundary models exist:
  - `CalendarEventSnapshot`
  - `BusyInterval`
  - `FreeGap`
  - `TaskPlanningInput`
  - `SuggestionCandidate`
  - `PlannerOutput`

These pieces are present so the Swift app can grow into planner/calendar features, but they are not yet a full feature loop.

### What Is Not Implemented Yet In Swift

- calendar permission UI and user-visible task-only fallback flow
- planner engine logic in Swift
- planner suggestions UI
- accepting a suggestion and writing it into the `Important` calendar
- calendar write/update/delete services
- reconciliation of local scheduled blocks against external calendar changes
- settings, onboarding, planner, or diagnostics screens
- CloudKit sync

### Current Swift Architecture

Relevant folders:

- `apple_app/task-manager/task-manager/App/`: app composition and environment
- `apple_app/task-manager/task-manager/Models/`: task domain types, scheduling domain types, and task-list presentation helpers
- `apple_app/task-manager/task-manager/Persistence/`: repository protocols, SwiftData records, repository implementations, and model-container factory
- `apple_app/task-manager/task-manager/Calendar/`: calendar contracts, preview stubs, and EventKit-backed permission/listing/read services
- `apple_app/task-manager/task-manager/Planner/Models/`: planner-facing boundary models only
- `apple_app/task-manager/task-manager/Features/Tasks/`: task list view model
- `apple_app/task-manager/task-manager/Views/`: current task list and task form views

The architecture direction is clear, but only the task-list surface is currently live.

### Swift UI Behavior Today

Task list behavior:

- the app opens into `TaskListView`
- `New Task` opens create mode
- selecting a row opens edit mode
- empty state messaging distinguishes between:
  - no tasks
  - no matches for the current search
- grouped sections only appear when they have tasks
- grouped tasks still respect the selected sort mode

Task form behavior:

- create and edit use the same form
- delete is shown only in edit mode
- blank titles are rejected
- invalid UUID values are rejected
- duplicate UUID values are rejected when they would collide with another task
- non-positive estimated minutes are rejected

Persistence behavior:

- normal app runs use a disk-backed SwiftData `ModelContainer`
- previews and tests use in-memory containers
- repository tests now pass after fixing repository initialization to retain the `ModelContainer` instead of only a `ModelContext`

### Swift Test Coverage

Swift tests currently cover:

- task model cleanup and enum-backed fields
- task form parsing and validation
- in-memory task collection behavior
- search behavior
- sort behavior
- grouping behavior
- grouped-section ordering
- SwiftData task repository behavior
- SwiftData scheduled-block repository behavior
- SwiftData settings repository behavior
- EventKit permission-status mapping
- readable-calendar exclusion behavior
- calendar event normalization and read ordering

Relevant test files:

- `apple_app/task-manager/task-managerTests/Calendar/EventKitCalendarServicesTests.swift`
- `apple_app/task-manager/task-managerTests/Models/MyTaskTests.swift`
- `apple_app/task-manager/task-managerTests/Models/MyTaskFormDataTests.swift`
- `apple_app/task-manager/task-managerTests/Models/MyTaskCollectionTests.swift`
- `apple_app/task-manager/task-managerTests/Models/TaskListPresentationTests.swift`
- `apple_app/task-manager/task-managerTests/Persistence/SwiftDataTaskRepositoryTests.swift`
- `apple_app/task-manager/task-managerTests/Persistence/SwiftDataScheduledBlockRepositoryTests.swift`
- `apple_app/task-manager/task-managerTests/Persistence/SwiftDataSettingsRepositoryTests.swift`

## Python Prototype Status

The Python code under `src/` is still active and still useful. It currently provides:

- task, project, event, scheduled-block, and preferences models
- planner candidate ranking logic
- free-gap detection
- JSON serialization and compatibility helpers
- Apple Calendar read/prototype integration via AppleScript
- older scheduler and compatibility surfaces still exercised by smoke checks

### What Works Today In Python

- the full pytest suite passes
- the smoke check passes
- model roundtrips and current/legacy schema compatibility paths are covered
- planner candidate selection is covered
- gap detection is covered
- Apple Calendar record parsing is covered

Python test files:

- `tests/test_models.py`
- `tests/test_planner.py`
- `tests/test_gap_detection.py`
- `tests/test_calendar_read.py`
- `tests/test_compatibility.py`

### What The Python Side Is Not

- it is not the current UI
- it is not integrated into the Swift app
- it is not the long-term calendar integration path for the product

The practical direction of the repo is:

- Swift app becomes the real app shell
- SwiftData becomes the durable app-state layer
- EventKit becomes the future calendar integration path
- Python remains a behavioral reference and test oracle until that logic is ported

## Running The Repo

### Swift App

Open `apple_app/task-manager/task-manager.xcodeproj` in Xcode and run the `task-manager` scheme.

Build from the command line:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' build
```

Run Swift tests:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test
```

### Python Prototype

Create the environment:

```bash
conda env create -f environment.yml
conda activate task-manager-test
```

Run the Python test suite:

```bash
pytest
```

Run the smoke check:

```bash
python3 scripts/core_smoke_check.py
```

## Current Reality

Implemented and verified:

- Swift macOS task list and task form prototype
- Swift search, sort, and grouping behavior
- SwiftData-backed repositories and passing repository tests
- Swift EventKit permission, calendar-listing, and read-only fetch services
- Python model, planner, gap-detection, calendar-read, and compatibility tests
- Python smoke coverage across core compatibility surfaces

Implemented but still only scaffolding:

- Swift scheduled-block persistence
- Swift app settings persistence
- Swift calendar write/reconcile contracts
- Swift planner boundary models

Not implemented yet:

- Swift planner engine
- suggestion acceptance and calendar writeback
- reconciliation with external calendar edits
- planner/settings/onboarding UI
- CloudKit sync

## Related Docs

- `concrete_plan.md`: current implementation plan with status notes
- `docs/planner_contract_v0_1.md`: current Python planner contract summary
- `docs/testing_workflow.md`: repo-wide testing workflow
