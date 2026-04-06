#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
notes_dir="$repo_root/docs/test_sessions"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
notes_path="$notes_dir/${timestamp}_manual_test.md"
backup_dir="$repo_root/data/manual_test_backups/$timestamp"
pytest_exit=0
smoke_exit=0

mkdir -p "$notes_dir"
mkdir -p "$backup_dir"

python_version="$(python --version 2>&1 || true)"
conda_env="${CONDA_DEFAULT_ENV:-<no-conda-env>}"

shopt -s nullglob
data_files=("$repo_root"/data/*.json)
if ((${#data_files[@]})); then
  cp "${data_files[@]}" "$backup_dir/"
fi
shopt -u nullglob

echo "Repo: $repo_root"
echo "Conda env: $conda_env"
echo "Python: $python_version"
echo "Backup: $backup_dir"
echo

if [[ "$conda_env" == "<no-conda-env>" ]]; then
  echo "Warning: no conda environment is active."
  echo "Recommended: conda activate task-manager-test"
  echo
fi

echo "Running unit tests..."

if python - <<'PY' >/dev/null 2>&1
import importlib.util
import sys

sys.exit(0 if importlib.util.find_spec("pytest") else 1)
PY
then
  if (cd "$repo_root" && PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests); then
    pytest_exit=0
  else
    pytest_exit=$?
  fi
else
  pytest_exit=127
  echo "pytest is not available in the current Python interpreter."
  echo "Skipping automated preflight and continuing with note creation."
fi

echo
echo "Running core smoke checks..."

if (cd "$repo_root" && python scripts/core_smoke_check.py); then
  smoke_exit=0
else
  smoke_exit=$?
fi

cat > "$notes_path" <<EOF
# Manual Test Session

Use this template for repo-wide audit sessions. Mark items \`N/A\` when they are out of scope.

## Session Meta

- Date: $(date '+%Y-%m-%d %H:%M:%S')
- Tester:
- Branch or commit:
- Swift test command:
- Swift test result:
- Swift app launched in Xcode:
- Conda env: $conda_env
- Python version: $python_version
- Pytest command: PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests
- Pytest result: exit code $pytest_exit
- Smoke command: python scripts/core_smoke_check.py
- Smoke result: exit code $smoke_exit
- Data backup path: $backup_dir
- Focus for this session:

## Preflight

- [ ] Backed up \`data/*.json\`
- [ ] Ran \`xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test\`
- [ ] Activated \`task-manager-test\` if Python checks are in scope
- [ ] Ran \`PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests\` if Python checks are in scope
- [ ] Ran \`python scripts/core_smoke_check.py\` if Python checks are in scope
- [ ] Reviewed any failing automated checks before manual exploration
- [ ] Opened this note before deeper exploration

## Swift App Checklist

- [ ] Opened \`apple_app/task-manager/task-manager.xcodeproj\`
- [ ] Ran the \`task-manager\` scheme
- [ ] Verified the \`Tasks\` tab loads
- [ ] Created a task
- [ ] Edited a task
- [ ] Deleted a task
- [ ] Checked task search behavior
- [ ] Checked task sort behavior
- [ ] Checked task grouping behavior
- [ ] Verified task-form validation for blank title / invalid UUID / duplicate UUID / estimated minutes when relevant
- [ ] Verified the \`Calendar\` tab loads
- [ ] Confirmed the Calendar permission state text looks correct for the machine under test
- [ ] Exercised \`Request Calendar Access\` if safe for the session
- [ ] Checked denied / restricted / write-only / not-determined messaging if those states are reachable
- [ ] Checked readable-calendar listing if full access is granted
- [ ] Confirmed excluded calendars are labeled \`Excluded\` when applicable
- [ ] Switched between \`Today\` and \`Next 7 Days\`
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
EOF

echo
echo "Session note created:"
echo "  $notes_path"
echo
echo "Recommended next steps:"
echo "  1. Open the note above and capture any issues from the automated output."
echo "  2. If Swift work is in scope, run the xcodebuild test command and launch the Xcode app target."
echo "  3. Re-run: python scripts/core_smoke_check.py"
echo "  4. For interactive Python exploration: ipython"
