#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
note_path="$repo_root/docs/test_sessions/${timestamp}_manual_test.md"
project_path="apple_app/task-manager/task-manager.xcodeproj"
scheme="task-manager"
simulator_test_exit=0
iphone_build_exit=0

mkdir -p "$repo_root/docs/test_sessions"

echo "Task Manager Swift QA Session"
echo "============================="
echo "Repo: $repo_root"
echo "Note: $note_path"
echo

echo "Running iOS simulator Swift tests..."
if (cd "$repo_root" && xcodebuild -project "$project_path" -scheme "$scheme" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' test); then
  simulator_test_exit=0
else
  simulator_test_exit=$?
fi

echo
echo "Running iPhone simulator build..."
if (cd "$repo_root" && xcodebuild -project "$project_path" -scheme "$scheme" -sdk iphonesimulator build); then
  iphone_build_exit=0
else
  iphone_build_exit=$?
fi

cat > "$note_path" <<NOTE
# Manual Test Session - $timestamp

## Automated Checks

- iOS simulator Swift tests: exit code $simulator_test_exit
- iPhone simulator build: exit code $iphone_build_exit

## Current Product Path

- [ ] Opened \`apple_app/task-manager/task-manager.xcodeproj\`
- [ ] Ran the \`task-manager\` scheme
- [ ] Confirmed the app opens to Today

## Today / Promises

- [ ] Created a new promise
- [ ] Confirmed the promise appears on Today
- [ ] Confirmed the active-promise banner appears on Tasks and Calendar
- [ ] Checked in as kept
- [ ] Created another promise and checked in as missed
- [ ] Added a short recovery reflection
- [ ] Created a reset promise from the missed check-in
- [ ] Confirmed kept/missed counts update

## Routines

- [ ] Created a daily routine with multiple items
- [ ] Created a selected-weekday routine
- [ ] Confirmed today's active routines appear on Today
- [ ] Completed and uncompleted routine items
- [ ] Relaunched the app and confirmed completion state persists for today

## Tasks

- [ ] Created a task
- [ ] Edited a task
- [ ] Completed and reopened a task
- [ ] Checked search, sort, and grouping

## Calendar / Planner

- [ ] Checked calendar permission state
- [ ] Loaded readable calendars
- [ ] Selected a write calendar
- [ ] Generated planner suggestions
- [ ] Accepted a suggestion and confirmed calendar writeback
- [ ] Canceled/deleted an accepted block
- [ ] Confirmed promises and routines do not write directly to Apple Calendar

## Notes

-
NOTE

echo
echo "Manual test note created:"
echo "$note_path"
echo
echo "Recommended next steps:"
echo "  1. Review failing automated checks before manual QA."
echo "  2. Open the Xcode project and work through the generated checklist."
echo "  3. Add findings under the Notes section in the generated session note."
