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

## Session Meta

- Date: $(date '+%Y-%m-%d %H:%M:%S')
- Tester:
- Conda env: $conda_env
- Python version: $python_version
- Branch or commit:
- Pytest command: PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests
- Pytest result: exit code $pytest_exit
- Smoke command: python scripts/core_smoke_check.py
- Smoke result: exit code $smoke_exit
- Data backup path: $backup_dir
- Focus for this session:

## Preflight

- [ ] Backed up \`data/*.json\`
- [ ] Activated \`task-manager-test\`
- [ ] Ran \`PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q tests\`
- [ ] Ran \`python scripts/core_smoke_check.py\`
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
EOF

echo
echo "Session note created:"
echo "  $notes_path"
echo
echo "No active non-legacy GUI entrypoint exists in the repo today."
echo "Recommended next steps:"
echo "  1. Open the note above and capture any issues from the smoke output."
echo "  2. Re-run: python scripts/core_smoke_check.py"
echo "  3. For interactive exploration: ipython"
