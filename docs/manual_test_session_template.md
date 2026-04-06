# Manual Test Session

Use this template for repo-wide audit sessions. Mark items `N/A` when they are out of scope.

Use `README.md`, `concrete_plan.md`, and `docs/product_direction.md` as the expected-behavior references for the session.

## Session Meta

- Date:
- Tester:
- Branch or commit:
- Swift test command:
- Swift test result:
- Swift app launched in Xcode:
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
- [ ] Activated `task-manager-test` if Python checks are in scope
- [ ] Ran `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests` if Python checks are in scope
- [ ] Ran `python scripts/core_smoke_check.py` if Python checks are in scope
- [ ] Reviewed any failing automated checks before manual exploration
- [ ] Reviewed `docs/product_direction.md` if planner or calendar behavior is in scope
- [ ] Opened this note before deeper exploration

## Swift App Checklist

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
- [ ] Verified the `Calendar` tab loads
- [ ] Confirmed the Calendar permission state text looks correct for the machine under test
- [ ] Exercised `Request Calendar Access` if safe for the session
- [ ] Checked denied / restricted / write-only / not-determined messaging if those states are reachable
- [ ] Checked readable-calendar listing if full access is granted
- [ ] Confirmed excluded calendars are labeled `Excluded` when applicable
- [ ] Switched between `Today` and `Next 7 Days`
- [ ] Checked read-only event loading if full access is granted
- [ ] Checked empty and error states for the Calendar tab

## Python Checklist

- [ ] Model roundtrips look plausible
- [ ] Gap detection results look plausible
- [ ] Planner suggestion ranking looks plausible
- [ ] Calendar record parsing looks plausible
- [ ] Persistence helpers checked if in scope
- [ ] Scheduler compatibility checked if in scope
- [ ] Findings mapped back to README model expectations

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
