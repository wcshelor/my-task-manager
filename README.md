# Task Manager / Life Assistant

This repo contains a SwiftUI Apple app evolving from a task manager into a broader Life Assistant / personal planning hub.

The product framing is:

> The app is a personal planning hub for capturing obligations, planning time, executing routines, tracking personal growth, and noticing useful life patterns.

The Swift app is the only active product path.

## Quick Orientation

- Active app: `apple_app/task-manager/`
- Xcode project: `apple_app/task-manager/task-manager.xcodeproj`
- Visible tabs:
  - `Today`
  - `Tasks`
  - `Calendar`
- `Calendar` is the planner-first surface.
- SwiftData owns app-owned durable data.
- EventKit owns Apple Calendar permission, reads, writes, and reconciliation.
- Planner behavior should stay in Swift/domain logic and remain testable outside SwiftUI.
- SwiftUI views should render state and collect interaction; business rules belong in models, repositories, or view models.

## Product Spine

Every feature should support at least one of these jobs:

- Capture - get obligations, ideas, errands, and admin out of the user's head.
- Plan - turn tasks into realistic time blocks around the user's calendar.
- Execute - help the user actually do the next thing.
- Recover - help the user reset when tired, scattered, behind, or low-energy.
- Understand patterns - track useful signals across routines, promises, practice, workouts, mood, and related life data.

## Implemented Areas

- Tasks
- Calendar / Planner
- Today hub
- Promises
- User-authored Routines
- SwiftData persistence for tasks, scheduled blocks, settings, promises, routines, and routine completion logs
- EventKit integration for calendar permission, reads, writes, and scheduled-block reconciliation

Future areas remain product ideas or scaffolding until implemented:

- Sleep / PVT tracker
- Piano practice mode
- Workout tracking
- Food / meal tracking
- Reflection / anti-spiral journaling
- General life logs
- CloudKit sync

## Current User-Facing App

### Today

Today is the execution hub. It surfaces:

- active promises
- due promise check-ins
- today’s active routines
- simple promise history counts

Today can create promises, check in on promises as kept or missed, create reset promises, create routines, and complete routine checklist items for the current day.

### Tasks

The Tasks tab supports:

- create, edit, delete
- search, sort, group
- complete, archive, reopen
- iPhone quick-add capture
- task metadata: status, due date, estimated minutes, priority, energy level, work mode, tags, and notes

When promises are active, Tasks shows a compact promise-presence banner so current commitments stay visible while using the app.

### Calendar / Planner

The Calendar tab supports:

- calendar permission status display
- full-calendar access request
- readable calendar loading
- writable calendar selection
- selected-day timeline
- day/week/month navigation
- real EventKit calendar events
- accepted scheduled blocks
- transient planner suggestions
- selected-slot planning
- horizon planning
- planning filters
- Morning Brief
- accept / reject controls for suggestions
- accepted-block edit, move, cancel, and delete flows
- EventKit writeback for accepted blocks
- reconciliation after external calendar moves or deletes

Planner suggestions are transient until accepted. Accepted suggestions become `ScheduledBlock` records and write linked events to the configured Apple Calendar.

When promises are active, Calendar also shows a compact promise-presence banner.

## Product Contract

- Tasks live in app-owned SwiftData storage.
- App settings live in app-owned SwiftData storage.
- Scheduled blocks live in app-owned SwiftData storage.
- Promises live in app-owned SwiftData storage.
- Routine definitions and daily completion logs live in app-owned SwiftData storage.
- Apple Calendar is the external source of truth for calendar busy time.
- Accepted planner suggestions are written to Apple Calendar only after explicit user acceptance.
- `ScheduledBlock` is the bridge between app tasks and Apple Calendar events.
- Calendar drift must be reconciled back into scheduled-block state.
- Planner suggestions remain ephemeral until accepted.
- Only Planner / ScheduledBlock flows should write to Apple Calendar.
- Promises, Routines, Practice, Workouts, Food, and Reflection should not write directly to Apple Calendar.
- CloudKit should not start until SwiftData models are audited for sync identity, conflict behavior, deletion semantics, privacy, and migration risk.

## Repository Layout

```text
.
|-- README.md
|-- concrete_plan.md
|-- life_assistant_app_brainstorm.md
|-- apple_app/
|-- docs/
`-- scripts/
```

Important directories:

- `apple_app/`: production SwiftUI Apple app.
- `docs/`: product, architecture, testing, and manual-session notes.
- `docs/domains/`: planning docs for future Life Assistant domains.
- `scripts/`: Swift app QA helper scripts.
- `concrete_plan.md`: ordered technical and product priorities.

## Swift App Architecture

Swift app root:

```text
apple_app/task-manager/
|-- task-manager.xcodeproj
|-- task-manager/
`-- task-managerTests/
```

Production Swift source:

```text
apple_app/task-manager/task-manager/
|-- App/
|-- Calendar/
|-- Features/
|-- Models/
|-- Persistence/
|-- Planner/
|-- Views/
|-- ContentView.swift
`-- task_managerApp.swift
```

### Composition

- `task_managerApp.swift` creates the app entry point.
- `ContentView.swift` defines the tab shell.
- `App/AppContainer.swift` wires concrete repositories and services.
- `App/AppEnvironment.swift` passes dependencies into feature views.

Prefer injecting repositories/services through the app container instead of constructing production dependencies inside views.

### Persistence

`Persistence/` separates repository contracts from SwiftData records and implementations:

- `TaskRepository`
- `ScheduledBlockRepository`
- `SettingsRepository`
- `PromiseRepository`
- `RoutineRepository`

SwiftData records include tasks, scheduled blocks, settings, promises, routines, and routine completion logs.

## Testing

Run the main Swift test suite on an available iOS simulator:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' test
```

Run iPhone simulator build checks:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing
```

Run the Swift QA helper:

```bash
bash scripts/manual_test_session.sh
```

See `docs/testing_workflow.md` for the current manual and automated workflow.

## Development Rules

- Keep app-owned durable data in SwiftData.
- Keep Apple Calendar writes restricted to Planner / ScheduledBlock flows.
- Keep domain logic testable outside SwiftUI.
- Prefer simple rule-based assistant behavior before adding heavier AI behavior.
- Avoid guilt/shame mechanics; promises and routines should be honest, visible, and recovery-oriented.
- Do not add a new domain as visible UI until it has useful content.
