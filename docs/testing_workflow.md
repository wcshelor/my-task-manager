# Testing Workflow

This repo's active testing surface is:

- `tests/` for automated coverage
- `src/` for active application logic

`legacy/` is not part of the active plan and should not be used for current testing.

The smooth testing flow is:

1. Activate the conda env.
2. Run the active unit suite.
3. Run the core smoke checks against current `src/` functionality.
4. Start a timestamped manual test session note.
5. Log anything that looks inconsistent with the README model.

## 1) Create and Activate the Env

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

## 2) Recommended Session Workflow

From the repo root:

```bash
bash scripts/manual_test_session.sh
```

That script:

- runs `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests`
- runs `python scripts/core_smoke_check.py`
- creates a timestamped backup of `data/*.json`
- creates a timestamped session note in `docs/test_sessions/`
- prints the next recommended non-GUI exploration steps

## 3) Current Manual Surface

There is currently no active non-legacy app entrypoint in the repository.

So the current manual workflow is service-level rather than GUI-level:

- run the unit suite
- run the smoke script
- inspect failures against the README object model and expected behavior
- optionally do deeper interactive exploration in `ipython`

The smoke script is:

```bash
python scripts/core_smoke_check.py
```

It intentionally covers:

- model serialization and roundtrips
- gap detection
- planner candidate selection
- calendar record parsing
- persistence and scheduler compatibility surfaces

Some of those compatibility checks may fail today. That is useful signal.

## 4) Unit Test Coverage Strategy

Every manual session should start with:

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

This gives you a fast signal on the newer core modules before you spend time in the GUI.

## 5) Manual Test Protocol

Use this order during each session:

1. `Unit Suite`
   Run the active `tests/` suite and note any failures.
2. `Smoke Check`
   Run `python scripts/core_smoke_check.py` and separate pass/fail results into:
   README-aligned core behavior vs older compatibility surfaces.
3. `Core Model Review`
   Confirm the smoke output for Project, Task, Work-Mode Template, Event, and Scheduled Block still matches the README object model.
4. `Planner Review`
   Confirm free-gap detection and candidate ranking behavior look plausible.
5. `Compatibility Review`
   If persistence, scheduling, or calendar-manager compatibility checks fail, log them explicitly as integration gaps.
6. `Interactive Follow-up`
   If needed, open `ipython` and inspect one failing area more deeply.
7. `Cleanup`
   Add a short summary to the session note with the most important issues and the next test to add.

## 6) Data Safety

Before manual testing, create a backup of `data/tasks.json` and `data/events.json`.

- `scripts/manual_test_session.sh` does this for you automatically.
- Backups are written under `data/manual_test_backups/<timestamp>/`.
- If a session corrupts or dirties local data, restore the relevant JSON file from that backup directory.

## 7) What to Log

For each issue, write down:

- area
- exact steps
- expected behavior
- actual behavior
- severity
- whether it blocks testing or is just a polish issue

Keep issue notes short while testing. You can rewrite them later if they turn into real bug tickets.
