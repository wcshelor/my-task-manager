# Testing Workflow

The SwiftUI Apple app in `apple_app/task-manager/` is the only active implementation surface.

Use `README.md`, `docs/life_assistant_vision.md`, and `docs/product_direction.md` as expected-behavior references for each session.

## 1. Baseline Automated Checks

From the repo root, run:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing
```

These are the default checks for coding sessions because they do not require booting a simulator runtime.

Current automated confidence covers:

- task models, repositories, and task-list presentation behavior
- planner engine ranking, gap handling, and selected-slot behavior
- planner view-model acceptance, rejection, lifecycle, and reconciliation behavior
- EventKit adapter behavior with mocked stores
- Home layout/execution view-model behavior, including capture conversion and module summaries
- promise models, repositories, and Home aggregation behavior
- routine models, repositories, and daily completion behavior
- Shopping models, SwiftData repository round trips, view-model behavior, and inbox conversion
- work-in-progress Health model calculations, SwiftData repository round trips, and Health view-model summaries
- Fitness model validation, SwiftData repository round trips, Fitness view-model state, and Home Fitness summaries
- Music Practice model validation, SwiftData repository round trips, view-model behavior, and Home summaries
- People Memory model validation, SwiftData repository round trips, view-model behavior, and Home summaries

## 2. Optional Simulator Swift Runs

Use these only when simulator behavior is required for the change and CoreSimulator is available. Use `-only-testing` when narrowing scope, for example:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' test -only-testing:task-managerTests/PlannerViewModelTests
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' test -only-testing:task-managerTests/HomeExecutionViewModelTests
```

Use the iPhone simulator SDK builds to catch cross-platform compile regressions even when no simulator runtime is installed:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing
```

If `xcrun simctl list runtimes` or `xcrun simctl list devices available` is empty, treat iPhone confidence on that machine as build-only confidence.

## 3. Manual Session Helper

From the repo root:

```bash
bash scripts/manual_test_session.sh
```

That helper:

- runs an iPhone simulator build
- creates a timestamped note in `docs/test_sessions/`
- prints the next recommended Swift, EventKit, simulator, Home, Promises, and Routines validation steps

Run simulator tests in the helper only when intentionally enabled:

```bash
RUN_IOS_SIMULATOR_TESTS=1 bash scripts/manual_test_session.sh
```

You still need to launch the Swift app from Xcode for real EventKit or hands-on simulator testing.

## 4. Current Manual Surface

Split manual testing by area depending on scope.

### Home / Promises

Validate:

- Home is the first visible tab
- new promise creation
- active promise visibility on Home
- active-promise banner on Tasks and Planner
- kept check-in flow
- missed check-in flow with reflection
- reset promise creation
- kept/missed history counts
- no direct Apple Calendar writes from promises

### Routines

Validate:

- daily routine creation
- selected-weekday routine creation
- item ordering
- Home visibility for routines active today
- item completion and uncompletion
- per-day completion persistence after relaunch
- no direct Apple Calendar writes from routines

### Tasks

Validate:

- task create, edit, delete
- search, sort, and grouping
- quick complete, reopen, and archive flows
- iPhone quick add and narrow-width task review if a simulator or device is available

### Calendar / Planner And EventKit

Validate:

- permission-state copy for not-determined, granted, denied, restricted, or write-only states when reachable
- readable calendar listing and excluded-calendar labeling
- selected-day timeline rendering
- selected-slot creation, drag expansion, and clearing
- slot-based suggestion generation
- horizon-based suggestion generation
- accept, reject, edit, reschedule, cancel, and delete flows
- write-calendar routing
- reconciliation after external calendar moves and deletes

### Health

Validate:

- quick sleep check-in entry and persistence
- completed PVT session saving
- real-time PVT tap flow timing on device or simulator
- meal and workout quick logs
- Health history and delete flows
- neutral 7/30-day trend summaries

### Shopping

Validate:

- open Shopping from Home
- add a shopping item from the module screen
- add a shopping item from the Home quick-add widget
- group active items by store type
- mark items bought, skipped, archived, reopened, and deleted
- search active and history lists

### Fitness

Validate:

- open Fitness from Home
- create Push Day, Pull Day, and Leg Day workout days
- create one strength exercise and one bike-style metric exercise
- add existing exercises to a workout day
- log sessions from both the exercise list and workout day flow
- confirm last-session references refresh immediately
- confirm logged-today state appears after same-day logging
- confirm Recent, A-Z, and Tag sorting
- confirm the older Health workout log still works unchanged

### Music Practice

Validate:

- open Music Practice from Home
- add a practice piece
- log a practice session with and without a piece
- confirm recent sessions, 7/30-day totals, focus-area breakdown, and stale-piece visibility refresh

### People Memory

Validate:

- open People Memory from Home
- add a person with meeting context and tags
- search by name, details, and tag text
- start a study review and apply easy/almost/missed ratings
- confirm due-review counts and saved-person counts refresh on Home

### iPhone Runtime Pass

Validate when a simulator runtime exists:

- app launch
- Home layout
- promise creation and check-in sheets
- routine builder and checklist sheets
- task quick add
- task edit and swipe actions
- planner screen layout
- selected-slot interactions
- permission-state copy and recovery messaging on phone layout

## 5. Manual EventKit Checklist

Use this checklist when you have a real macOS calendar account available:

- permission states:
  - not determined
  - granted full access
  - denied
  - restricted if reproducible
  - write-only if reproducible
- excluded read calendars:
  - confirm excluded calendars do not contribute busy time
  - confirm included calendars still do
- write calendar:
  - confirm the configured write calendar is used
  - confirm missing or ambiguous write-calendar configuration fails clearly
- accepted suggestion flow:
  - generate a suggestion
  - accept it
  - confirm the linked event is created in the correct calendar
- accepted block lifecycle:
  - edit
  - reschedule
  - cancel
  - delete
  - confirm matching EventKit updates or deletes happen
- reconciliation:
  - move the linked event externally in Calendar.app
  - delete the linked event externally in Calendar.app
  - confirm the app refreshes or reconciles the local block state correctly
- error handling:
  - missing write calendar
  - non-writable write calendar
  - revoked permission after launch
  - event missing at update or delete time

## 6. Manual Logging Protocol

For each issue, capture:

- area
- exact steps
- expected behavior
- actual behavior
- severity
- whether it blocks testing or is polish

Keep issue notes short during the session. Rewrite them later only if they turn into tracked bug work.
