# Testing Workflow

This repo currently has two testable implementation surfaces:

- the shared SwiftUI Apple app in `apple_app/task-manager/`
- the legacy Python reference surface in `src/` and `tests/`

The Swift app is the product path. Manual testing should now center on the planner-first `Calendar` tab, EventKit integration, and the iPhone task flow, not the earlier read-only calendar shell.

Use `README.md`, `concrete_plan.md`, and `docs/product_direction.md` as the expected-behavior references for each session.

## 1. Baseline Automated Checks

From the repo root, run:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing
pytest -q
python3 scripts/core_smoke_check.py
```

Current automated confidence is strongest for:

- Swift task models, repositories, and task-list presentation behavior
- Swift planner engine ranking, gap handling, and selected-slot behavior
- Swift planner view-model acceptance, rejection, lifecycle, and reconciliation behavior
- EventKit adapter behavior with mocked stores
- Python model, planner, gap-detection, compatibility, and smoke surfaces

## 2. Focused Swift Runs

Use the full macOS test command above for broad Swift confidence.

When narrowing scope, prefer `-only-testing`, for example:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test -only-testing:task-managerTests/PlannerViewModelTests
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test -only-testing:task-managerTests/EventKitCalendarServicesTests
```

Use the iPhone simulator SDK builds to catch cross-platform compile regressions even when no simulator runtime is installed:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing
```

If `xcrun simctl list runtimes` or `xcrun simctl list devices available` is empty, treat iPhone confidence on that machine as build-only confidence.

## 3. Focused Python Runs

Create or update the test environment when Python checks are in scope:

```bash
mamba env create -f environment.yml
conda activate task-manager-test
```

If the env already exists:

```bash
mamba env update -f environment.yml --prune
conda activate task-manager-test
```

Run the full Python suite:

```bash
pytest -q
```

Run narrower checks when needed:

```bash
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_models.py
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_gap_detection.py
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_planner.py
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_calendar_read.py
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_compatibility.py
```

Run the smoke check:

```bash
python3 scripts/core_smoke_check.py
```

## 4. Manual Session Helper

From the repo root:

```bash
bash scripts/manual_test_session.sh
```

That helper:

- backs up `data/*.json` into `data/manual_test_backups/<timestamp>/`
- runs `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests` when `pytest` is available
- runs `python3 scripts/core_smoke_check.py`
- creates a timestamped note in `docs/test_sessions/` using the current planner-first session template
- prints the next recommended Swift, EventKit, simulator, and Python validation steps

Important:

- the helper still does not run `xcodebuild` for you
- you still need to launch the Swift app from Xcode for any real EventKit or simulator pass
- the generated note is meant to capture both Swift and Python findings in one place

## 5. Current Manual Surface

Split manual testing into four surfaces depending on scope.

### Swift Task Flow

Validate:

- task create, edit, delete
- search, sort, and grouping
- quick complete, reopen, and archive flows
- iPhone quick add and narrow-width task review if a simulator or device is available

### Swift Planner And EventKit Flow

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

### iPhone Runtime Pass

Validate when a simulator runtime exists:

- app launch
- task quick add
- task edit and swipe actions
- planner screen layout
- selected-slot interactions
- permission-state copy and recovery messaging on phone layout

### Python Reference Pass

Validate:

- model roundtrips
- gap detection plausibility
- planner candidate ranking
- calendar record parsing
- compatibility helpers that still protect the Swift migration path

## 6. Manual EventKit Checklist

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

## 7. Manual Logging Protocol

For each issue, capture:

- area
- exact steps
- expected behavior
- actual behavior
- severity
- whether it blocks testing or is polish

Keep issue notes short during the session. Rewrite them later only if they turn into tracked bug work.
