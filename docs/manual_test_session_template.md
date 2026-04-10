# Manual Test Session

Use this template for repo-wide audit sessions. Mark items `N/A` when they are out of scope.

Use `README.md`, `concrete_plan.md`, and `docs/product_direction.md` as the expected-behavior references for the session.

## Session Meta

- Date:
- Tester:
- Branch or commit:
- Swift macOS test command:
- Swift macOS test result:
- iPhone simulator build command:
- iPhone simulator build result:
- Swift app launched in Xcode:
- Simulator runtime available:
- Simulator or device used:
- EventKit account used:
- Conda env:
- Python version:
- Pytest command:
- Pytest result:
- Smoke command:
- Smoke result:
- Data backup path:
- Focus for this session:

## Preflight

- [ ] Backed up `data/*.json`
- [ ] Ran `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test`
- [ ] Ran `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build` if iPhone work is in scope
- [ ] Ran `xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing` if iPhone work is in scope
- [ ] Activated `task-manager-test` if Python checks are in scope
- [ ] Ran `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests` if Python checks are in scope
- [ ] Ran `python3 scripts/core_smoke_check.py` if Python checks are in scope
- [ ] Reviewed any failing automated checks before manual exploration
- [ ] Reviewed `docs/testing_workflow.md` for the current planner/EventKit checklist
- [ ] Opened this note before deeper exploration

## Swift Task Checklist

- [ ] Opened `apple_app/task-manager/task-manager.xcodeproj`
- [ ] Ran the `task-manager` scheme
- [ ] Verified the `Tasks` tab loads
- [ ] Created a task
- [ ] Edited a task
- [ ] Deleted a task
- [ ] Checked task search behavior
- [ ] Checked task sort behavior
- [ ] Checked task grouping behavior
- [ ] Verified task-form validation for blank title / invalid UUID / duplicate UUID / estimated minutes when relevant
- [ ] Checked quick complete / reopen / archive actions when relevant
- [ ] Checked the iPhone quick-add flow if a simulator or device is available
- [ ] Checked iPhone swipe actions if a simulator or device is available

## Planner And EventKit Checklist

- [ ] Verified the `Calendar` tab loads
- [ ] Confirmed the Calendar permission-state text looks correct for the machine under test
- [ ] Exercised `Request Calendar Access` if safe for the session
- [ ] Checked denied / restricted / write-only / not-determined messaging if those states are reachable
- [ ] Checked readable-calendar listing if full access is granted
- [ ] Confirmed excluded calendars are labeled `Excluded` when applicable
- [ ] Checked selected-day timeline rendering if full access is granted
- [ ] Created a selected slot from the timeline
- [ ] Drag-expanded the selected slot in 15-minute increments
- [ ] Generated suggestions for a selected slot
- [ ] Generated suggestions with a horizon preset
- [ ] Accepted a suggestion and confirmed the event was written to the configured calendar
- [ ] Rejected a suggestion and confirmed it disappears from the current planner session
- [ ] Edited an accepted block
- [ ] Rescheduled an accepted block
- [ ] Canceled an accepted block
- [ ] Deleted an accepted block
- [ ] Moved the linked event externally and checked reconciliation
- [ ] Deleted the linked event externally and checked reconciliation
- [ ] Checked missing / ambiguous / non-writable write-calendar handling when reachable

## iPhone Runtime Checklist

- [ ] Confirmed `xcrun simctl list runtimes` returns at least one installed runtime if simulator work is in scope
- [ ] Confirmed `xcrun simctl list devices available` returns at least one available device if simulator work is in scope
- [ ] Launched the app on an iPhone simulator or device if runtime testing is in scope
- [ ] Verified narrow-width task layout
- [ ] Verified narrow-width planner layout
- [ ] Verified selected-slot interactions on phone layout
- [ ] Verified permission-state copy on phone layout

## Python Checklist

- [ ] Model roundtrips look plausible
- [ ] Gap detection results look plausible
- [ ] Planner suggestion ranking looks plausible
- [ ] Calendar record parsing looks plausible
- [ ] Persistence helpers checked if in scope
- [ ] Scheduler compatibility checked if in scope
- [ ] Findings mapped back to README expectations

## Issues Found

### Issue 1

- Area:
- Severity:
- Repro steps:
- Expected:
- Actual:
- Notes:

### Issue 2

- Area:
- Severity:
- Repro steps:
- Expected:
- Actual:
- Notes:

### Issue 3

- Area:
- Severity:
- Repro steps:
- Expected:
- Actual:
- Notes:

## End of Session Summary

- What looked solid:
- What needs attention next:
- Best next automated test to add:
