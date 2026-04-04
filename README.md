# Task Manager Prototype

This repository currently contains two active prototype surfaces:

- Python planning and calendar prototype code under `src/`
- A SwiftUI Apple app prototype under `apple_app/`

The Swift app is the current visible UI prototype. The Python code still holds most of the planner, model, compatibility, and Apple Calendar experimentation.

## Swift App Status

The Swift app lives in `apple_app/task-manager/`.

What it can do today:

- show an in-memory task list seeded with sample tasks
- create a new task from a dedicated task screen
- open any existing task into a detail/edit screen from the main list
- edit every current `MyTask` field in place: `id`, `title`, `isDone`, and `createdAt`
- cancel out of create/edit without saving
- save changes back into the visible list
- delete an existing task from the detail screen

Current task flow:

1. Launch the app to the task list.
2. Click or tap `New Task` to open the task form in create mode.
3. Click or tap an existing task row to open its detail/edit screen.
4. Save to create or update the task, or cancel to discard changes.
5. Delete is available only when editing an existing task.

Important limitations:

- Swift tasks are in-memory only right now. There is no persistence layer yet.
- Closing or relaunching the app resets the Swift task list to sample data.
- The Swift app does not yet expose projects, planner suggestions, calendar sync, or settings flows.
- The current Swift prototype is a focused task-list/editor demo, not a full product implementation.

## Python Prototype Status

The Python code under `src/` is still present and still matters. It contains the current prototype logic for:

- task, project, event, scheduled-block, and preferences models
- planner candidate ranking
- free-gap detection
- Apple Calendar reading/prototype integration
- JSON serialization and compatibility helpers
- older task/calendar utility surfaces and smoke-check scripts

This side of the repo is still prototype code, not a production application shell.

## Repo Layout

- `apple_app/`: SwiftUI prototype app and Swift unit tests
- `src/`: Python prototype modules
- `tests/`: Python pytest suite for planner/model/calendar behavior
- `scripts/`: manual smoke-check and helper scripts
- `data/`: local prototype data files

## Running The Swift App

Open `apple_app/task-manager/task-manager.xcodeproj` in Xcode and run the `task-manager` scheme.

From the command line, build or test with:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=macOS' test
```

## Running Python Tests

The repo includes a Conda environment file for the Python test setup:

```bash
conda env create -f environment.yml
conda activate task-manager-test
pytest
```

Python tests currently cover model serialization/validation, planner candidate selection, gap detection, calendar record parsing, and compatibility behavior.

## Prototype vs Not Implemented

Prototype / present today:

- Swift task list and task detail/edit flow
- Python model and planner prototype logic
- Python tests for core planner/model/calendar behavior
- Swift unit tests for task model and form behavior

Not implemented yet:

- Swift persistence
- Swift planner UI and end-to-end scheduling flow
- production-grade Apple Calendar sync/writeback from the Swift app
- polished multi-screen product architecture beyond the current prototype flows
