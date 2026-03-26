# Manual Test Session

## Session Meta

- Date:
- Tester:
- Conda env:
- Python version:
- Branch or commit:
- Pytest command:
- Pytest result:
- Smoke command:
- Smoke result:
- Data backup path:
- Focus for this session:

## Preflight

- [ ] Backed up `data/*.json`
- [ ] Activated `task-manager-test`
- [ ] Ran `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests`
- [ ] Ran `python scripts/core_smoke_check.py`
- [ ] Reviewed any failing smoke checks
- [ ] Opened this note before deeper exploration

## Flow Checklist

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

## End of Session Summary

- What looked solid:
- What needs attention next:
- Best next automated test to add:
