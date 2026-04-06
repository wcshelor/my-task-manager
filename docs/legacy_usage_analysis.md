# Legacy Usage Analysis

Date: 2026-04-05

This document records the current status of the repo's relationship to `legacy/`.

## Current Conclusion

`legacy/` is not part of the active product path.

The active implementation surfaces are now:

- the macOS SwiftUI app in `apple_app/task-manager/`
- the Python prototype modules and tests under `src/` and `tests/`

The Swift app is the active app shell. The Python code is still the richer planner reference and compatibility surface. The `legacy/` folder should be treated as archival material only.

## Why This Matters

Earlier repo cleanup work had to untangle two separate problems:

1. whether active code depended on `legacy/`
2. whether active docs and testing workflows were still sending humans into `legacy/`

The first problem is already mostly solved technically. The second problem is now largely solved in the documentation as well, but `legacy/` still exists in the tree and can still create confusion for future work.

## Active Runtime And Test Boundaries

### `src/` does not depend on `legacy/`

The current Python modules under `src/` do not require imports from `legacy/` in order to run.

Practical implication:

- active Python logic can execute independently of old archival code

### `tests/` do not depend on `legacy/`

The active pytest suite under `tests/` targets `src.*` modules, not `legacy.*`.

Practical implication:

- the automated Python surface is already scoped away from the old UI path

### `pytest.ini` keeps normal collection scoped to `tests`

Normal pytest discovery is limited to `tests`, which keeps old `legacy/test_*.py` files out of the default automated workflow.

Practical implication:

- the main test run does not accidentally pull legacy files back into the active path

## Documentation And Workflow Status

### Active docs now point at the real app shell

The repo now has a real non-legacy app entrypoint in `apple_app/task-manager/`, and the active docs should treat that as the current UI surface.

The main workflow documents now describe:

- Swift `xcodebuild` tests
- Swift manual testing through the Xcode app target
- Python unit tests and smoke checks

That is the correct direction for the repo.

### The manual session helper is still Python-oriented, but no longer needs legacy framing

`scripts/manual_test_session.sh` is still primarily a Python preflight helper. That is acceptable as long as the surrounding docs make two things explicit:

- it does not replace the Swift `xcodebuild` suite
- it does not represent the full manual workflow for the current app shell

### Old generated notes may still reflect older workflow assumptions

Historical artifacts under `docs/test_sessions/` may still capture older testing habits or narrower Python-focused sessions. They should be treated as session logs, not as current workflow guidance.

## How `legacy/` Still Interacts With Current Code

The most important remaining coupling is directional:

- old legacy code may import current `src/` modules
- active `src/` and `tests/` should not import legacy code back

That means `legacy/` can still be useful as archival reference material, but it should not be used to define current behavior, test expectations, or implementation priorities.

## Risks That Still Exist

### Risk 1: Humans may mistake `legacy/` for an active app path

Even if active code is decoupled, the folder name alone invites confusion.

### Risk 2: Old notes can look authoritative

Historical test-session notes can read like workflow instructions if someone opens them without context.

### Risk 3: Legacy data-model assumptions can leak back into planning

The legacy UI and helpers were built around older task concepts and compatibility assumptions. Those concepts should not override the current README / Swift-app direction.

## Recommended Project Conventions

The clean rule set is:

1. Treat `README.md` and `concrete_plan.md` as the current source of truth.
2. Treat `docs/product_direction.md` as the frozen product behavior contract.
3. Treat the Swift app under `apple_app/task-manager/` as the current UI shell.
4. Treat Python under `src/` and `tests/` as the behavioral reference and compatibility surface.
5. Treat `legacy/` as archival only unless a task explicitly asks for it.
6. Avoid new tooling, tests, or docs that route normal work through `legacy/`.

## Suggested Cleanup That Still Would Help

- Add a short `legacy/README.md` that says the folder is archival and may be broken.
- Consider renaming `legacy/` to a more obviously archival name if keeping it long-term.
- Keep generated session notes under `docs/test_sessions/` clearly separated from source-of-truth docs.

## Bottom Line

The repo no longer needs `legacy/` to explain or exercise the active product direction.

The correct implementation story is now:

- Swift app for the real shell
- SwiftData for local app state
- EventKit for calendar integration
- a calendar-first planner shell as the next product milestone
- Python as planner/reference behavior
- `legacy/` as archive
