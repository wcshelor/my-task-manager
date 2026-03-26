# Legacy Usage Analysis

Date: 2026-03-19

Context:

- The current source of truth is [README.md](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/README.md), which describes the active v0.1 product model and plan.
- `legacy/` should be treated as old code, not as the target architecture.
- Status update: the active workflow docs/scripts were later cleaned so they no longer direct testing into `legacy/`. Remaining mentions here are documentary analysis.

## Conclusion

The active codebase does **not** currently require `legacy/` in order to run the `src/` core modules or the `tests/` unit suite.

The current dependency picture is:

1. `src/` and `tests/` are effectively independent of `legacy/`.
2. `legacy/` contains old code that imports and depends on `src/`.
3. A few newer docs/scripts currently reference `legacy/` as a manual-testing path. Those references are not aligned with the README-based plan and should be removed or replaced.

So the main problem is **not** that the current architecture depends on `legacy/` internally. The problem is that:

- old archival code is still present and reaches into current modules, and
- some repo tooling/docs still point humans toward that old folder.

## What The Active Code Uses

### No `legacy/` dependency in active Python package code

I found no references to `legacy` inside `src/`.

This means the current application logic under `src/` does not import from `legacy/`, does not call into `legacy/`, and does not require `legacy/` to execute.

### No `legacy/` dependency in active pytest configuration

[pytest.ini](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/pytest.ini#L1) explicitly limits test discovery to `tests`:

- `testpaths = tests`

That means `legacy/test_*.py` is excluded from normal pytest collection unless someone runs it manually.

### Active unit tests are pointed only at `src/`

The current tests under `tests/` import only `src.*` modules and do not reference `legacy/`.

Implication:

- from the README-based architecture perspective, `legacy/` is already outside the active automated surface.

## Where `legacy/` Is Still Referenced

### 1) Newer workflow docs and helper script

These repo files currently direct manual testing into `legacy/`:

- [docs/testing_workflow.md](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/docs/testing_workflow.md#L5)
- [docs/manual_test_session_template.md](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/docs/manual_test_session_template.md#L16)
- [scripts/manual_test_session.sh](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/scripts/manual_test_session.sh#L67)

Specific examples:

- [docs/testing_workflow.md](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/docs/testing_workflow.md#L56) tells the user to launch `PYTHONPATH=. python legacy/app.py`.
- [docs/manual_test_session_template.md](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/docs/manual_test_session_template.md#L22) includes “Started the legacy GUI”.
- [scripts/manual_test_session.sh](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/scripts/manual_test_session.sh#L69) records the GUI launch command as `PYTHONPATH=. python legacy/app.py`.

These are documentation/tooling references, not core architecture dependencies. But they are still important because they push real testing behavior toward the old folder.

### 2) Generated session note artifacts

Generated files under `docs/test_sessions/` also now contain `legacy` launch instructions because they were created from the helper script template.

These are artifacts, not source logic, but they should be considered stale once the workflow is corrected.

## How `legacy/` Depends On Current Code

The strongest active coupling is actually in the opposite direction: old legacy code imports current `src/` modules.

### Legacy GUI imports current `src/`

[legacy/app.py](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/legacy/app.py#L16) imports:

- `src.models`
- `src`
- `src.preferences`
- `src.calendar_manager`
- `src.scheduler`

This means the old GUI is effectively acting as an outdated frontend on top of current backend modules.

That is risky because the GUI expects the old data model while `README.md` and newer tests are moving toward the new v0.1 object model.

### Legacy helper/test scripts also import current `src/`

Examples:

- [legacy/verify_gui_tasks.py](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/legacy/verify_gui_tasks.py#L7) imports `src.task_manager`.
- [legacy/test_scheduler.py](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/legacy/test_scheduler.py#L8) manually mutates `sys.path` and imports `src.models` and `src.scheduler`.

This is not the active plan. It is old code using current modules through compatibility assumptions.

## Signs That `legacy/` Is Already Broken Or Mismatched

### Broken legacy test-mode path

[legacy/app_test.py](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/legacy/app_test.py#L8) imports `src.test_mode`, but there is no active `src/test_mode.py` in the repo.

That means this old test-mode entrypoint is already broken.

### Broken relative imports inside old helper

[legacy/test_mode.py](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/legacy/test_mode.py#L12) uses relative imports like:

- `from .models import Task`
- `from .utils import load_tasks, save_tasks`

But this file lives in `legacy/`, not in an installed package context. As currently structured, this is not a valid active workflow.

### Old schema assumptions

[legacy/app.py](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/legacy/app.py#L53) and [legacy/test_scheduler.py](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/legacy/test_scheduler.py#L20) use older task concepts like:

- `deadline`
- `est_time`
- `effort`
- `priority`
- `category`
- `notes`

But the README source of truth defines the v0.1 task model around fields like:

- `dueDate`
- `priorityLevel`
- `energyLevel`
- `estimatedMinutes`
- `minBlockMinutes`
- `projectId`

So even where compatibility aliases exist, the legacy code is conceptually driving the wrong object model.

## Practical Interpretation

If the README is the source of truth, then `legacy/` should be treated as:

- archive/reference material,
- possible design inspiration,
- but **not** part of the current execution or testing strategy.

At the moment, the repo is already mostly there technically:

- active `src/` code does not import `legacy/`
- active `tests/` do not import `legacy/`
- pytest does not collect legacy tests by default

What remains is mostly cleanup and boundary enforcement.

## What Needs To Be Done To Undo Legacy Reliance

### Immediate cleanup

1. Remove `legacy` references from active testing docs and helper scripts.
   Files:
   - [docs/testing_workflow.md](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/docs/testing_workflow.md#L5)
   - [docs/manual_test_session_template.md](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/docs/manual_test_session_template.md#L16)
   - [scripts/manual_test_session.sh](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/scripts/manual_test_session.sh#L67)

2. Replace the manual workflow with one aligned to the README plan.
   Right now there is no active non-legacy GUI entrypoint in the repo, so the honest options are:
   - define a non-GUI manual workflow around `src/` services and tests, or
   - build the new active app entrypoint before advertising manual GUI testing.

3. Treat existing `docs/test_sessions/*.md` notes as stale artifacts once the workflow is updated.

### Boundary hardening

4. Add a README note or project convention that `legacy/` is archival and not part of the active runtime plan.

5. Keep pytest scoped to `tests/` only.
   This is already done in [pytest.ini](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/pytest.ini#L1).

6. Avoid new tooling that launches or imports `legacy/`.

### Structural cleanup

7. Consider renaming `legacy/` to something more explicit like `archive/legacy_ui_prototype/`.
   That would reduce the chance that agents or humans mistake it for the current app.

8. If you want to keep the folder, add a short `legacy/README.md` stating:
   - archival only
   - not source of truth
   - may be broken
   - do not use for current implementation planning unless explicitly requested

## Recommended Next Move

The cleanest next step is:

1. remove active workflow references to `legacy/`
2. define a README-aligned testing workflow that targets only `src/` and `tests/`
3. decide whether manual testing should wait until a new non-legacy app shell exists

That would make the repo behavior consistent with the architecture described in [README.md](/Users/campshelor/Desktop/GitHub%20Repos/task_manager/README.md#L1).
