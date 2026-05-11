# Task Manager / Life Assistant

This repo contains a SwiftUI Apple app evolving from a task manager into a broader Life Assistant / personal planning hub.

Status: active work in progress. Implemented areas are usable development surfaces, while newer modules, especially Health, should still be treated as incomplete until manual QA and product polish catch up.

The product framing is:

> The app is a personal planning hub for capturing obligations, planning time, executing routines, tracking personal growth, and noticing useful life patterns.

The Swift app is the only active product path.

## Quick Orientation

- Active app: `apple_app/task-manager/`
- Xcode project: `apple_app/task-manager/task-manager.xcodeproj`
- Visible tabs:
  - `Home`
  - `Tasks`
  - `Projects`
- `Home` is the widget-based execution hub.
- Planner / Calendar is reached from Home and remains the planner-first surface.
- SwiftData owns app-owned durable data.
- EventKit owns Apple Calendar permission, reads, writes, and reconciliation.
- Home widget layout is app-owned SwiftData state.
- Planner behavior should stay in Swift/domain logic and remain testable outside SwiftUI.
- SwiftUI views should render state and collect interaction; business rules belong in models, repositories, or view models.

## Product Spine

Every feature should support at least one of these jobs:

- Capture - get obligations, ideas, errands, and admin out of the user's head.
- Plan - turn tasks into realistic time blocks around the user's calendar.
- Execute - help the user actually do the next thing.
- Recover - help the user reset when tired, scattered, behind, or low-energy.
- Understand patterns - track useful signals across routines, promises, practice, Health, mood, and related life data.

## Implemented / Active Areas

- Tasks
- Calendar / Planner
- Home widget hub
- Projects
- Promises
- User-authored Routines
- Health work in progress: sleep check-ins, one-minute PVT sessions, lightweight meal/workout logs, and neutral rolling trend summaries
- SwiftData persistence for tasks, projects, captures, project items, scheduled blocks, settings, home layout, promises, routines, routine completion logs, and work-in-progress Health records
- EventKit integration for calendar permission, reads, writes, and scheduled-block reconciliation

Future or incomplete areas remain product ideas, scaffolding, or active work in progress until the app and docs say otherwise:

- Piano practice mode
- Task evolution: projects, subtasks, recurrence, prerequisites, and sequences
- Vices Tracking
- People Memory
- Music Practice
- Journaling & Reflection
- Shopping list and wish list
- Budgeting / purchase decision support
- General life logs
- Optional folder-based cloud sync

## Module Roadmap

Domain documentation is split by implementation status:

- `docs/domains/`: implemented or active app domains.
- `docs/domains/future-modules/`: plan-only modules, scaffolds, active work-in-progress docs, and product sketches.

Implemented or active domain docs:

- `docs/domains/promises.md`: active promises, check-ins, reset promises, and future promise-breaking / renegotiation friction.
- `docs/domains/routines.md`: user-authored recurring routine checklists.
- `docs/domains/today_dashboard.md`: Today / Home as the execution hub.
- `docs/domains/future-modules/health.md`: active work-in-progress Health section for Sleep / PVT, Nutrition, Fitness, and daily context.
- `docs/domains/future-modules/sleep_pvt.md`: active work-in-progress Health subdomain for sleep check-ins, PVT sessions, and trend tracking.
- `docs/domains/future-modules/nutrition.md`: active work-in-progress Health subdomain for lightweight meal logging and trends.
- `docs/domains/future-modules/fitness.md`: active work-in-progress Health subdomain for workout logging and trends.

Plan-only future module docs:

- `docs/domains/future-modules/task_evolution.md`: projects, subtasks, recurring tasks, prerequisites, and task sequences.
- `docs/domains/shopping.md`: shopping items, trip grouping, and future wish-list support.
- `docs/domains/future-modules/budgeting.md`: lightweight expense logs, spending awareness, and purchase decision support.
- `docs/domains/future-modules/vices.md`: custom vices, mindful pre-action logging, goals, limits, and pattern review.
- `docs/domains/future-modules/people_memory.md`: remembering names, meeting context, reusable tags, study mode, and future export.
- `docs/domains/future-modules/music_practice.md`: instruments, practice logs, pieces, routines, and music practice goals.
- `docs/domains/future-modules/journaling_reflection.md`: guided journaling, freeform reflection, search, links, and follow-up actions.
- `docs/domains/future-modules/life_logs.md`: generic logs and guidance for when a domain needs dedicated models.
- `docs/domains/future-modules/future_widgets.md`: future Home widget and sub-module widget ideas.

Rough next steps:

1. Strengthen the existing task system with explicit task groups/projects, then subtasks.
2. Add promise-breaking / renegotiation friction to the existing Promises flow.
3. Build Shopping as the next practical capture module, keeping wish-list decisions separate from necessities.
4. Add lightweight Budgeting around manual expenses and purchase decisions.
5. Polish the Health work in progress: manually QA the PVT tap flow, refine neutral trend summaries, and decide how Health should surface in Home / Routines.
6. Add Vices Tracking once the promise, Health, log, and check-in patterns are mature enough to support it cleanly.
7. Add People Memory, Music Practice, and Journaling & Reflection when their capture and retrieval flows are clear.
8. Build optional folder-based cloud sync after the SwiftData models for durable records are stable enough to audit for identity, merge behavior, deletion semantics, privacy, and migration risk.

## Current User-Facing App

### Home

Home is the widget-based execution hub. The default layout migrates the old Today sections into first-class widgets:

- inbox / quick capture
- pinned projects
- today’s calendar overview
- active promises
- due promise check-ins
- today’s active routines
- simple promise history counts

Home supports a persisted vertical widget board. Users can long-press to edit, reorder widgets, remove widgets, resize supported widgets between small and large, and add more widgets from a module-grouped Add Widget screen.

Home can create captures, promises, and routines; check in on promises as kept or missed; create reset promises; complete routine checklist items for the current day; open Planner; and navigate into module pages where available.

### Tasks

The Tasks tab supports:

- create, edit, delete
- search, sort, group
- complete, archive, reopen
- iPhone quick-add capture
- task metadata: status, due date, estimated minutes, priority, energy level, work mode, tags, and notes

When promises are active, Tasks shows a compact promise-presence banner so current commitments stay visible while using the app.

### Calendar / Planner

Planner supports:

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

When promises are active, Planner also shows a compact promise-presence banner.

### Health

Health is active work in progress and is reached from Home. The current app supports quick sleep check-ins, a rough one-minute in-app PVT reaction test, lightweight meal and workout logs, and neutral rolling 7/30-day trend summaries.

The module is for personal tracking and progress visibility, not diagnosis or judging health state. Manual QA still needs to verify the real-time PVT tap flow on device or simulator.

## Product Contract

- Tasks live in app-owned SwiftData storage.
- App settings live in app-owned SwiftData storage.
- Scheduled blocks live in app-owned SwiftData storage.
- Home widget layout lives in app-owned SwiftData storage.
- Promises live in app-owned SwiftData storage.
- Routine definitions and daily completion logs live in app-owned SwiftData storage.
- Health check-ins, PVT sessions, meal logs, and workout logs live in app-owned SwiftData storage.
- Apple Calendar is the external source of truth for calendar busy time.
- Accepted planner suggestions are written to Apple Calendar only after explicit user acceptance.
- `ScheduledBlock` is the bridge between app tasks and Apple Calendar events.
- Calendar drift must be reconciled back into scheduled-block state.
- Planner suggestions remain ephemeral until accepted.
- Only Planner / ScheduledBlock flows should write to Apple Calendar.
- Promises, Routines, Music Practice, Health, Shopping, Budgeting, Vices Tracking, People Memory, and Journaling & Reflection should not write directly to Apple Calendar.
- Cross-device sync is not active today.
- CloudKit is not the planned near-term sync path because it depends on Apple developer capabilities that may not be available to every user or build setup.
- The planned sync extension is optional folder-based sync: the user chooses a cloud-backed folder, the app keeps SwiftData as the local source of truth, and sync reads/writes portable files in that folder.
- Folder sync should use append-only change batches, compact snapshots, bounded backups, tombstones for deletes, and explicit conflict records instead of placing the live SwiftData database in the cloud folder.
- Folder sync should run on startup, on foreground activation, from a manual Sync Now action, and on a best-effort active-app timer. iOS background sync should be treated as opportunistic, not guaranteed.

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
- `docs/domains/`: domain docs for implemented or active app areas.
- `docs/domains/future-modules/`: plan-only future module docs.
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
|-- Sync/
|-- Views/
|-- ContentView.swift
`-- task_managerApp.swift
```

### Composition

- `task_managerApp.swift` creates the app entry point.
- `ContentView.swift` defines the tab shell.
- `App/AppContainer.swift` wires concrete repositories and services.
- `App/AppEnvironment.swift` passes dependencies into feature views.
- `HomeWidgetRegistry` describes available in-app Home widgets.
- `HomeLayoutViewModel` owns Home layout editing actions; domain data comes from `HomeExecutionViewModel` and the existing domain repositories.

Prefer injecting repositories/services through the app container instead of constructing production dependencies inside views.

### Persistence

`Persistence/` separates repository contracts from SwiftData records and implementations:

- `TaskRepository`
- `ScheduledBlockRepository`
- `SettingsRepository`
- `HomeLayoutRepository`
- `PromiseRepository`
- `RoutineRepository`
- `HealthRepository`

SwiftData records include tasks, projects, captures, project items, scheduled blocks, settings, home layout, promises, routines, routine completion logs, and work-in-progress Health records.

### Planned Folder Sync

`Sync/` contains scaffolding for a future optional sync service that will use a user-selected cloud folder rather than CloudKit. The intended shape is:

- `SyncService`: app-facing dependency exposed through `AppContainer` once implemented.
- `SyncEngine`: pull / backup / merge / push orchestration.
- `SyncFolderAccess`: security-scoped folder access and persisted bookmarks.
- `SyncChangeBatch`: immutable per-device change files.
- `SyncSnapshot`: compact full-state snapshots for bootstrap and pruning.
- `SyncConflict`: conflict preservation before any fallback merge choice.
- `SyncBackupPolicy`: bounded backup retention so sync remains recoverable without unbounded storage growth.

The planned cloud folder layout is:

```text
My Life Manager Sync/
|-- manifest.json
|-- devices/
|-- changes/
|-- snapshots/
|-- backups/
`-- conflicts/
```

The live SwiftData store should remain local. The cloud folder should contain portable JSON or compressed JSON artifacts only.

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
- Keep Home widgets as summaries, shortcuts, and controls; full module behavior should live on module pages.
- Keep domain logic testable outside SwiftUI.
- Prefer simple rule-based assistant behavior before adding heavier AI behavior.
- Avoid guilt/shame mechanics; promises and routines should be honest, visible, and recovery-oriented.
- Do not add a new domain as visible UI until it has useful content.
