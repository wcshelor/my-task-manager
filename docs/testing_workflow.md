# Testing Workflow

This repo now has two active implementation surfaces:

- the macOS Swift app in `apple_app/task-manager/`
- the Python prototype in `src/` and `tests/`

Use `docs/product_direction.md` for the frozen product behavior. This workflow doc describes what is currently implemented and how to test it.

The fastest trustworthy workflow is:

1. Run the Swift test suite.
2. Run the Python test suite.
3. Run the Python smoke checks.
4. If needed, launch the Swift app in Xcode for a manual UI pass.
5. Log gaps against `README.md`, `concrete_plan.md`, and `docs/product_direction.md`.

## 1) Swift Automated Checks

From the repo root:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test
```

This currently verifies:

- task model behavior
- task form validation/parsing
- task-list search/sort/grouping behavior
- calendar-read view-model loading / permission / window-selection behavior
- SwiftData task repository behavior
- SwiftData scheduled-block repository behavior
- SwiftData settings repository behavior
- EventKit permission-state mapping
- readable-calendar exclusion behavior
- calendar event normalization and read ordering

## 2) Create and Activate the Python Env

From the repo root:

```bash
mamba env create -f environment.yml
conda activate task-manager-test
```

If the env already exists:

```bash
mamba env update -f environment.yml --prune
conda activate task-manager-test
```

## 3) Python Automated Checks

Run the Python suite:

```bash
pytest
```

Run the smoke check:

```bash
python3 scripts/core_smoke_check.py
```

These currently verify:

- Python model roundtrips
- planner candidate selection
- gap detection
- Apple Calendar record parsing
- compatibility behavior across older helper surfaces

## 4) Python Session Helper

From the repo root:

```bash
bash scripts/manual_test_session.sh
```

That script:

- runs `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests`
- runs `python scripts/core_smoke_check.py`
- creates a timestamped backup of `data/*.json`
- creates a timestamped session note in `docs/test_sessions/`
- prints the next recommended Python-focused exploration steps

Important:

- this script is Python-oriented
- it does not run the Swift `xcodebuild` test suite
- the session template under `docs/manual_test_session_template.md` is also Python-oriented

## 5) Current Manual Surface

There is now an active app entrypoint in the repository: the Swift macOS app.

Current manual work should be split like this:

- Swift app manual pass:
  - open the Xcode project
  - run the `task-manager` scheme
  - exercise the `Tasks` tab:
    - create a task
    - edit a task
    - delete a task
    - verify search, sort, and grouping
  - exercise the `Calendar` tab:
    - inspect the current permission state
    - request Calendar access if that is safe for the session
    - verify denied / restricted / write-only / empty states render sensible copy
    - switch between `Today` and `Next 7 Days`
    - verify readable calendars and read-only events load when full access is granted
- Python manual pass:
  - run the unit suite
  - run the smoke script
  - inspect failures against the README object model and expected behavior
  - optionally do deeper interactive exploration in `ipython`

The Swift app currently exposes two manual surfaces:

- a full task-list / task-form workflow
- a thin calendar-read workflow for permission status, readable-calendar listing, and read-only event browsing

The frozen target behavior is a calendar-first planner flow with `Generate Plan`, temporary suggestion blocks, and explicit accept-before-writeback. Planner suggestions, calendar writeback, and reconciliation are still not manual-testable because that feature loop does not exist yet.

The Python smoke script is:

```bash
python scripts/core_smoke_check.py
```

It intentionally covers:

- model serialization and roundtrips
- gap detection
- planner candidate selection
- calendar record parsing
- persistence and scheduler compatibility surfaces

## 6) Unit Test Coverage Strategy

Every repo-wide audit session should start with:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test
pytest
python scripts/core_smoke_check.py
```

When you are focused only on Python behavior, use:

```bash
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests
```

When you are focused on one area, use narrower runs:

```bash
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_models.py
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_gap_detection.py
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_planner.py
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests/test_calendar_read.py
```

When you are focused only on Swift behavior, use the full `xcodebuild` test command above or narrow the run with `-only-testing`.

## 7) Manual Test Protocol

Use this order during each session:

1. `Swift Suite`
   Run the Swift tests and note any failures.
2. `Python Suite`
   Run the Python tests and note any failures.
3. `Smoke Check`
   Run `python scripts/core_smoke_check.py`.
4. `Swift UI Review`
   If your change touches the app UI or calendar services, launch the Swift app in Xcode and exercise the task list, task form, and calendar-read flow that is relevant to the change.
5. `Python Core Review`
   Confirm the smoke output for Project, Task, Work-Mode Template, Event, and Scheduled Block still matches README expectations.
6. `Planner / Compatibility Review`
   If planner, persistence, scheduling, or calendar-manager compatibility checks fail, log them explicitly.
7. `Cleanup`
   Add a short summary with the most important issues and the next test to add.

## 8) Data Safety

Before manual testing, create a backup of `data/tasks.json` and `data/events.json`.

- `scripts/manual_test_session.sh` does this for you automatically.
- Backups are written under `data/manual_test_backups/<timestamp>/`.
- If a session corrupts or dirties local data, restore the relevant JSON file from that backup directory.

## 9) What To Log

For each issue, write down:

- area
- exact steps
- expected behavior
- actual behavior
- severity
- whether it blocks testing or is just a polish issue

Keep issue notes short while testing. You can rewrite them later if they turn into real bug tickets.
