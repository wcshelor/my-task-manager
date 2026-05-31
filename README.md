**AGENTS: Always read [AGENTS.md](AGENTS.md) whenever you read this README.**

# Task Manager / Life Assistant

This repo contains a SwiftUI Apple app evolving from a task manager into a broader Life Assistant / personal planning hub.

Status: active work in progress. Implemented areas are usable development surfaces, while newer modules, especially Health, Music Practice, Fitness, Shopping, and People Memory, should still be treated as incomplete until manual QA and product polish catch up.

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
  - `Settings`
- `Home` is the widget-based execution hub and replaces the older Today framing in most current UI.
- Finance is a Home-reachable manual tracking module for income and expenses, with monthly balance and category spend summaries.

### Finance MVP

- Entry point: add the Finance widget/module from `Home`, then open it from the Home dashboard.
- Persistence: local SwiftData only.
- Models:
  - `FinanceTransaction`
  - `FinanceCategory`
  - `TransactionKind`
- Workflow:
  - manually log income and expenses
  - assign a category on entry
  - review the current month balance
  - view expense spending by category in a donut chart
  - open a monthly transaction list grouped by date or category
- Current scope:
  - manual entry only
  - no bank sync
  - no subscriptions
  - no authentication
  - editing deferred; create/delete/view are the current supported actions
- Planner / Calendar is reached from Home and now supports manual planning, Block Focus, and Debrief follow-through.
- SwiftData owns app-owned durable data.
- EventKit owns Apple Calendar permission, reads, writes, and reconciliation.
- Home widget layout is app-owned SwiftData state.
- Planner behavior should stay in Swift/domain logic and remain testable outside SwiftUI.
- SwiftUI views should render state and collect interaction; business rules belong in models, repositories, or view models.

## For Coding Agents: Start Here

Before making changes, read this section and the relevant domain doc.

This app is a SwiftUI personal Life Assistant. The main rule is: do not rewrite architecture to solve a local UI problem.

### Common Workflows

If changing Home widgets:

- Start in `HomeWidgetRegistry`.
- Check `HomeLayoutViewModel`.
- Check Home feature/views under `Features/`, `Views/`, or the current Home-related folders.
- Preserve persisted widget layout state.
- Keep widgets lightweight: summaries, shortcuts, quick-add controls, and small status views.
- Full module behavior belongs on module pages, not inside Home widgets.

If changing Tasks:

- Start with task models in `Models/` and repository contracts/implementations in `Persistence/`.
- Check `TaskRepository` before changing persistence behavior.
- Check the task form/view model code before editing SwiftUI directly.
- Keep task validation/parsing shared between quick-add and full edit flows.
- Preserve existing task metadata unless the prompt explicitly asks for model changes.

If changing Planner / Calendar:

- Planner/domain logic belongs in `Planner/`.
- EventKit access belongs in `Calendar/`.
- Do not write directly to Apple Calendar outside Planner/ScheduledBlock flows.
- Accepted suggestions become `ScheduledBlock` records before/while writing linked EventKit events.
- Keep planner logic testable outside SwiftUI, SwiftData, and EventKit.

If changing Settings:

- Start with `AppSettingsRecord` and `SettingsRepository`.
- Use repository-backed state, not ad hoc global state.
- Settings should affect behavior through repositories, services, or view models.
- User-facing settings should be simple and recoverable; avoid hidden behavior changes.

If changing Routines:

- Start with routine models and `RoutineRepository`.
- Keep routine execution separate from routine editing.
- Keep routine stats/review separate from the clean daily checklist UI.
- Do not hardcode personal routines. Make routines user-authored and configurable.

If changing Projects:

- Start with project models and existing project item/object types.
- Do not invent new project object types unless the task explicitly asks for model changes.
- Prefer dashboard-style cards/widgets inside project detail screens when surfacing object groups.

If changing Health:

- Treat Health as active work in progress.
- Keep language neutral and non-diagnostic.
- Prioritize simple personal tracking, trend visibility, and manual QA.

If changing Music Practice:

- Treat Music Practice as a lightweight tracking foundation, not a full practice-planning system.
- Keep piece/session logging simple unless the prompt explicitly asks for richer planning.

If changing Shopping:

- Keep Shopping practical and capture-oriented.
- Separate necessities/current list behavior from future wish-list or purchase-decision behavior.

If changing Finance:

- Keep Finance manual-entry and local-only for now.
- Use `Decimal` for money and keep balance/category math out of SwiftUI views.
- Treat Home widgets as lightweight entry points; full logging and history belong in the Finance screens.

If changing People Memory:

- Start with `PeopleMemoryModels`, `PeopleMemoryRepository`, and `PeopleMemoryViewModel`.
- Keep tag ranking and study queue logic outside SwiftUI.
- Treat photos, contacts, export, and task/planner links as future work unless explicitly requested.

If changing Sync:

- Do not implement sync unless explicitly asked.
- Current near-term direction is optional folder-based sync, not live SwiftData-in-cloud storage.
- Keep live SwiftData local.
- Use sync tasks first as audits/design memos unless implementation is explicitly requested.

## Where Things Live

| Area | Main files / folders | Notes |
|---|---|---|
| App composition | `App/AppContainer.swift`, `App/AppEnvironment.swift`, `task_managerApp.swift`, `ContentView.swift` | Wire dependencies here; avoid constructing production services inside views. |
| Persistence | `Persistence/`, SwiftData records, repository implementations | Repositories are the seam between views/view models and storage. |
| Tasks | task models, `TaskRepository`, task views/forms | Preserve quick-add vs full-edit distinction. |
| Home widgets | `HomeWidgetRegistry`, `HomeLayoutViewModel`, Home views | Layout is persisted app-owned state. |
| Planner | `Planner/` | Pure/domain planner logic should remain independent of SwiftUI/EventKit/SwiftData. |
| Debriefs | debrief models/repository/views | Calendar-event reflection records with lightweight capture, task outcomes, and close-the-loop status. |
| Block Focus | calendar block focus models/repository/views | App-owned intention records for calendar events; connect projects/tasks to manual calendar blocks. |
| Calendar/EventKit | `Calendar/` | Permission, calendar reads/writes, and reconciliation. |
| Settings | `AppSettingsRecord`, `SettingsRepository`, settings views | User-facing settings UI should use repository-backed state. |
| Promises | promise models/repository/views | Avoid guilt/shame mechanics; keep recovery-oriented tone. |
| Routines | routine models/repository/views | User-authored recurring page-based routines with per-step logs and optional routine step links. |
| Health | health models/repository/views | Work in progress; not medical diagnosis. |
| Music Practice | music practice models/repository/views | Lightweight practice tracking, not a full practice planner yet. |
| Fitness | fitness models/repository/views | Standalone Home-reachable structured exercise tracking. |
| Shopping | shopping models/repository/views | Practical capture module. |
| Finance | `Features/Finance/`, finance models/repository/views | Manual local-only income/expense tracking with monthly summaries. |
| People Memory | people-memory models/repository/views | Work in progress private memory aid for names, contexts, reusable tags, and lightweight study review. |
| Sync | `Sync/` | Scaffolding only unless explicitly asked. |
| Tests | `task-managerTests/`, `scripts/` | Run Swift tests and smoke helpers after meaningful changes. |

## Non-Negotiable Architecture Contracts

- SwiftData is the source of truth for app-owned durable data.
- EventKit is the only boundary for Apple Calendar permission, reads, writes, and reconciliation.
- Planner/domain logic must stay testable outside SwiftUI.
- SwiftUI views should render state and collect user interaction; avoid putting business rules directly in views.
- Home widgets are summaries, shortcuts, and lightweight controls. Full module behavior belongs on module pages.
- Planner suggestions are ephemeral until accepted.
- Accepted planner suggestions become `ScheduledBlock` records.
- Only Planner / ScheduledBlock flows may write to Apple Calendar.
- Block Focus records live in app-owned SwiftData storage.
- Block Focus reads and annotates EventKit events but never writes to Apple Calendar.
- Debriefs read EventKit events but never write EventKit events.
- Debrief task outcomes live in app-owned SwiftData storage.
- Cross-device sync is not active.
- Do not implement CloudKit or folder sync unless the prompt explicitly asks for sync implementation.
- Do not add a new visible domain unless it has useful content, persistence, and a clear user-facing workflow.

## Agent Workflow

### Before You Code

1. Identify the feature area: Home, Tasks, Planner, Debriefs, Settings, Routines, Projects, Promises, Health, Music Practice, Fitness, Shopping, People Memory, or Sync.
2. Read this README section plus the relevant domain doc under `docs/domains/` or `docs/domains/future-modules/`.
3. Find the existing model/repository/view model before editing SwiftUI views.
4. Prefer extending existing patterns over introducing new architectural styles.
5. If the task is UI-only, avoid changing persistence models.
6. If the task requires model changes, check whether migration/backward compatibility is needed.
7. Keep platform-specific changes isolated where possible.

### After You Code

1. Run the relevant Swift build/test command.
2. Run repo smoke checks if the change touches shared logic.
3. Manually inspect affected screens in Xcode/simulator when possible.
4. Summarize:
   - files changed
   - behavior changed
   - tests run
   - manual checks still needed
   - any deferred follow-up

## Standard Task Types

### UI Polish Task

Expected behavior:

- Preserve models and repositories.
- Make minimal view/view-model changes.
- Keep UI consistent with the existing soft card/widget style.
- Do not introduce new domain concepts.
- Keep empty states readable and non-crashy.

Required output:

- Files changed
- Screens affected
- Tests/builds run
- Manual checks needed

### New Setting Task

Expected behavior:

- Add setting to durable settings model only if it must persist.
- Route access through `SettingsRepository`.
- Expose user-facing controls in Settings.
- Make the setting affect behavior through view models/services, not ad hoc global state.
- Include sensible defaults and safe behavior when the setting is missing.

### New Module Widget Task

Expected behavior:

- Register widget in `HomeWidgetRegistry`.
- Keep widget lightweight.
- Widget may summarize, shortcut, or quick-add.
- Full workflows belong in the module screen.
- Empty states must not crash.
- Preserve Home layout persistence.

### Routine Change Task

Expected behavior:

- Preserve existing routine definitions and logs.
- Separate editing, execution, and stats.
- Keep daily checklist uncluttered.
- Avoid hardcoding personal routines.
- Keep routine creation simple: title plus multiline step text, one non-empty line per step.
- Treat routine step links as routine-specific shortcuts, not Home widgets.
- If adding step states or statistics, keep the stats behind a separate screen/sheet.

### Planner / Calendar Task

Expected behavior:

- Do not bypass EventKit service abstractions.
- Do not write directly to Calendar from non-Planner modules.
- Keep planner logic testable outside SwiftUI.
- Add/update tests for planner behavior where possible.
- Real EventKit behavior needs manual validation, not just mocks.

### Project Screen Task

Expected behavior:

- Reuse existing project models and object/item types.
- Prefer clear card/widget sections for project-related groups.
- Do not invent a full project-management system unless explicitly requested.
- Keep object creation obvious with small plus/add controls.

### Sync Task

Expected behavior:

- Default is research/audit only.
- Do not implement sync unless explicitly asked.
- Do not put the live SwiftData store in a cloud folder.
- Document migration/conflict/deletion assumptions before implementation.
- Keep optional folder-based sync conceptually separate from CloudKit unless the prompt asks for a comparison.

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
- Debriefs from recent ended calendar events
- Home widget hub
- Projects
- Promises
- User-authored Routines with page-by-page execution, durable completed/skipped step state, and optional per-step routine links
- Shopping list
- Health work in progress: sleep check-ins, one-minute PVT sessions, lightweight meal/workout logs, and neutral rolling trend summaries
- Fitness work in progress: workout days, exercise library, exercise-owned history, and structured session logging
- Music Practice foundation: lightweight piece records, session logging, recent summaries, and Home access
- People Memory work in progress: person records, reusable tags, search, lightweight study cards, and Home access
- SwiftData persistence for tasks, projects, captures, project items, scheduled blocks, debrief records, settings, home layout, promises, routines, routine step links, routine completion logs, Shopping records, work-in-progress Health records, Music Practice records, Fitness records, and People Memory records
- EventKit integration for calendar permission, reads, writes, and scheduled-block reconciliation

Future or incomplete areas remain product ideas, scaffolding, or active work in progress until the app and docs say otherwise:

- Task evolution: richer project/task-group structure, subtasks, recurrence, prerequisites, and sequences
- Vices Tracking
- Journaling & Reflection
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
- `docs/domains/shopping.md`: active shopping list, trip grouping, and future wish-list support.
- `docs/domains/today_dashboard.md`: Today / Home as the execution hub.
- `docs/domains/debriefs.md`: Debrief workflow for recent ended calendar events, capture, and close-the-loop processing.
- `docs/domains/calendar_block_focus.md`: Block Focus records for linking calendar events to projects, tasks, and Debrief intent.
- `docs/domains/future-modules/health.md`: active work-in-progress Health section for Sleep / PVT, Nutrition, lightweight workout logs, and daily context.
- `docs/domains/future-modules/sleep_pvt.md`: active work-in-progress Health subdomain for sleep check-ins, PVT sessions, and trend tracking.
- `docs/domains/future-modules/nutrition.md`: active work-in-progress Health subdomain for lightweight meal logging and trends.
- `docs/domains/future-modules/fitness.md`: active work-in-progress standalone Fitness module for workout days, exercises, and exercise history.
- `docs/domains/future-modules/music_practice.md`: active work-in-progress Music Practice foundation for pieces, sessions, and recent practice summaries.
- `docs/domains/future-modules/people_memory.md`: active work-in-progress People Memory foundation for remembering names, meeting context, reusable tags, and lightweight study.

Plan-only and product-sketch docs:

- `docs/domains/future-modules/task_evolution.md`: richer project/task-group behavior, subtasks, recurring tasks, prerequisites, and task sequences.
- `docs/domains/future-modules/budgeting.md`: lightweight expense logs, spending awareness, and purchase decision support.
- `docs/domains/future-modules/vices.md`: custom vices, mindful pre-action logging, goals, limits, and pattern review.
- `docs/domains/future-modules/journaling_reflection.md`: guided journaling, freeform reflection, search, links, and follow-up actions.
- `docs/domains/future-modules/life_logs.md`: generic logs and guidance for when a domain needs dedicated models.
- `docs/domains/future-modules/future_widgets.md`: mixed-status Home widget and sub-module widget ideas; `HomeWidgetRegistry` is the source of truth for current availability.

Rough next steps:

1. Strengthen the existing task system with richer project/task-group behavior, then subtasks.
2. Add promise-breaking / renegotiation friction to the existing Promises flow.
3. Polish the Music Practice foundation with piece detail review, archive/unarchive, and manual QA.
4. Polish Shopping as a practical capture module, keeping wish-list decisions separate from necessities.
5. Add lightweight Budgeting around manual expenses and purchase decisions.
6. Polish the Health work in progress: manually QA the PVT tap flow, refine neutral trend summaries, and decide how Health should surface in Home / Routines.
7. Add Vices Tracking once the promise, Health, log, and check-in patterns are mature enough to support it cleanly.
8. Polish People Memory with clearer detail review, export decisions, and manual QA; add Journaling & Reflection when its capture and retrieval flow is clear.
9. Build optional folder-based cloud sync after the SwiftData models for durable records are stable enough to audit for identity, merge behavior, deletion semantics, privacy, and migration risk.

## Current User-Facing App

### Home

Home is the widget-based execution hub. The default layout migrates the old Today sections into first-class widgets:

- inbox / quick capture
- pinned projects
- today’s calendar overview
- pending Debriefs, with linked project names and focus-task counts when available
- active promises
- due promise check-ins
- today’s active routines
- simple promise history counts
- Shopping, Health, Music Practice, Fitness, and People module entry widgets

Home supports a persisted vertical widget board. Users can long-press any widget or tap `Edit` to enter edit mode, then reorder widgets, remove widgets, resize supported widgets between small and large, and add more widgets from a module-grouped Add Widget screen.

The Shopping module now also exposes a dedicated `Shopping Quick Add` sub-widget so users can add list items directly from Home without opening the full shopping list.

Home can create captures, promises, and routines; check in on promises as kept or missed; create reset promises; run routines as one-step-at-a-time page flows; add or remove per-step routine links; open routine-linked PVT or Promise sheets without leaving the routine; open Planner; and navigate into module pages where available. Home quick capture now uses a lightweight overlay with a dimmed background instead of a full-screen sheet, and inbox review refreshes Home counts after convert/archive changes as well as on dismiss.

### Tasks

The Tasks tab supports:

- create, edit, delete
- search, sort, group
- complete, archive, reopen
- iPhone quick-add capture
- task metadata: status, due date, optional estimated duration, priority, energy level, work mode, tags, and notes
- new-task flows default estimated duration to `None`; duration can be added or cleared in 15-minute steps

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
- manual calendar event project recognition and Block Focus editing

Planner suggestions are transient until accepted. Accepted suggestions become `ScheduledBlock` records and write linked events to the configured Apple Calendar.

When promises are active, Planner also shows a compact promise-presence banner.

Auto-generation remains available as supporting behavior. The primary calendar support loop is now manual planning, calendar awareness, and Debrief follow-through.

### Debriefs

Debriefs are lightweight reflections attached to recent ended calendar events. The Debrief flow:

- reads external calendar events through EventKit abstractions
- lets the user choose Work Block, Meeting, or Social templates
- captures essential answers plus optional detail
- includes a universal "Capture from this event" input that writes captures into the inbox
- can surface project-linked Block Focus context and selected tasks for Work Blocks
- can persist task outcomes for project-linked work blocks in SwiftData
- marks events as Debriefed or No Debrief needed
- persists Debrief records in SwiftData for future trend analysis

### Projects

Projects are available as a top-level tab. The current app supports lightweight project records, pinned project surfacing on Home, project-linked tasks, project captures, project items such as maybes and notes, and compact calendar activity surfacing for linked work blocks and recent Debriefs.

Project support is still intentionally lightweight. It is not a full project-management system, and future task evolution work still covers subtasks, recurrence, prerequisites, sequences, and richer task/project structure.

### Health

Health is active work in progress and is reached from Home. The current app supports quick sleep check-ins, a rough one-minute in-app PVT reaction test, lightweight meal and workout logs, and neutral rolling 7/30-day trend summaries.

The module is for personal tracking and trend visibility, not diagnosis or judging health state. Manual QA still needs to verify the real-time PVT tap flow on device or simulator.

### Fitness

Fitness is active work in progress and is reached from Home through its module widget. The current app supports workout days, an exercise library, per-exercise recent history, structured strength-set logging, metric-summary cardio logging, and same-day logged-state surfacing.

The module is for personal tracking and progress visibility. Workout-completion objects, plans, charts, archive flows, Health sync, and Apple Health integration remain deferred.

### Shopping

Shopping is reached from Home. The current app supports active shopping items, lightweight item capture, a dedicated Home quick-add widget, grouped trip views, item history, and basic bought/skipped/archive/reopen flows.

### Music Practice

Music Practice is active work in progress and is reached from Home through its module widget. The current app supports lightweight practice piece capture, practice session logging, optional session-to-piece association, recent session review, 7/30-day practice totals, focus-area breakdown, and basic stale-piece visibility.

The module is intentionally small: it does not include practice plans, audio recording, metronome behavior, AI recommendations, detailed repertoire hierarchy, or Calendar/EventKit integration.

### People Memory

People Memory is active work in progress and is reached from Home through its module widget. The current app supports person capture, reusable tags, search across person details and tags, due-review counts, and lightweight study cards with easy/almost/missed ratings.

Photos, Contacts integration, export, richer study modes, Home prompts, and task/planner links remain future work.

## Product Contract

- Tasks live in app-owned SwiftData storage.
- Projects, captures, and project items live in app-owned SwiftData storage.
- Calendar Block Focus records live in app-owned SwiftData storage.
- App settings live in app-owned SwiftData storage.
- Scheduled blocks live in app-owned SwiftData storage.
- Debrief records live in app-owned SwiftData storage.
- Debrief task outcomes live in app-owned SwiftData storage.
- Home widget layout lives in app-owned SwiftData storage.
- Promises live in app-owned SwiftData storage.
- Routine definitions, routine step links, and daily completion logs live in app-owned SwiftData storage.
- Health check-ins, PVT sessions, meal logs, and workout logs live in app-owned SwiftData storage.
- Fitness exercises, workout days, and exercise sessions live in app-owned SwiftData storage.
- Music Practice pieces and sessions live in app-owned SwiftData storage.
- Shopping items live in app-owned SwiftData storage.
- People Memory people and tags live in app-owned SwiftData storage.
- Apple Calendar is the external source of truth for calendar busy time.
- Accepted planner suggestions are written to Apple Calendar only after explicit user acceptance.
- `ScheduledBlock` is the bridge between app tasks and Apple Calendar events.
- Calendar drift must be reconciled back into scheduled-block state.
- Planner suggestions remain ephemeral until accepted.
- Only Planner / ScheduledBlock flows should write to Apple Calendar.
- Promises, Routines, Music Practice, Fitness, Health, Shopping, Budgeting, Vices Tracking, People Memory, and Journaling & Reflection should not write directly to Apple Calendar.
- Debriefs should not write directly to Apple Calendar.
- Cross-device sync is not active today.
- CloudKit is not the planned near-term sync path because it depends on Apple developer capabilities that may not be available to every user or build setup.
- The planned sync extension is optional folder-based sync: the user chooses a cloud-backed folder, the app keeps SwiftData as the local source of truth, and sync reads/writes portable files in that folder.
- Folder sync should use append-only change batches, compact snapshots, bounded backups, tombstones for deletes, and explicit conflict records instead of placing the live SwiftData database in the cloud folder.
- Folder sync should run on startup, on foreground activation, from a manual Sync Now action, and on a best-effort active-app timer. iOS background sync should be treated as opportunistic, not guaranteed.

## Repository Layout

```text
.
|-- README.md
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
- `DebriefRepository`
- `CalendarBlockFocusRepository`
- `PromiseRepository`
- `RoutineRepository`
- `HealthRepository`
- `FitnessRepository`
- `MusicPracticeRepository`
- `ShoppingRepository`
- `PeopleMemoryRepository`

SwiftData records include tasks, projects, captures, project items, scheduled blocks, debrief records, calendar block focus records, settings, home layout, promises, routines, routine completion logs, Shopping records, work-in-progress Health records, Music Practice records, Fitness records, and People Memory records.

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

Default to non-simulator checks first:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing
```

Run simulator tests only when needed and when CoreSimulator is healthy:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' test
```

Run the Swift QA helper:

```bash
bash scripts/manual_test_session.sh
```

Enable simulator tests in the helper only when intentionally requested:

```bash
RUN_IOS_SIMULATOR_TESTS=1 bash scripts/manual_test_session.sh
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
