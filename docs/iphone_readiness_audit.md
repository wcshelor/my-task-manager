# iPhone Readiness Audit

Status: captured from the current checkout on April 6, 2026.

## Shared Modules That Already Port Cleanly

These areas are already UI-independent enough to share across macOS and iPhone without logic forks:

- `apple_app/task-manager/task-manager/App/AppContainer.swift`
- `apple_app/task-manager/task-manager/App/AppEnvironment.swift`
- `apple_app/task-manager/task-manager/Persistence/`
- `apple_app/task-manager/task-manager/Calendar/CalendarContracts.swift`
- `apple_app/task-manager/task-manager/Calendar/EventKit/`
- `apple_app/task-manager/task-manager/Planner/`
- `apple_app/task-manager/task-manager/Features/Tasks/TaskListViewModel.swift`
- `apple_app/task-manager/task-manager/Features/Planner/PlannerViewModel.swift`
- `apple_app/task-manager/task-manager/Models/`

The current app already keeps the important seams in the right places:

- SwiftData is the app-data source of truth.
- EventKit is the calendar boundary.
- planner logic is pure Swift.
- `AppContainer` is the composition root.

## Platform Assumptions Found

### Build / target assumptions

- The Xcode project was macOS-only before this migration pass.
- The scheme only exposed macOS destinations before the target settings change.
- The app target used a macOS sandbox entitlements file and macOS-only build settings.

### UI assumptions

- The app has no `AppKit` imports and no `#if os(macOS)` branches in feature code today.
- The task form includes a default keyboard shortcut for save, which is harmless on Mac but not meaningful on iPhone.
- Two planner sheets used fixed minimum widths sized for desktop presentation.
- Several planner cards use dense horizontal button groups that fit on Mac but can wrap or compress on iPhone.
- The planner timeline is scrollable and touch-compatible, but it is visually dense and will need later interaction polish on phone.

### Interaction assumptions

- The task list is already close to portable: searchable list, navigation-driven editing, and lightweight controls.
- The task form is functionally portable but still Mac-shaped in its emphasis on full-form editing, visible UUID editing, and bottom action buttons.
- The planner is portable at the domain level but needs layout adaptation for narrow widths and later touch-native refinement.
- There is no settings screen yet, so there is no platform-specific settings audit surface.

## Screen Inventory

| Surface | Classification | Notes |
| --- | --- | --- |
| Task list | Needs layout adaptation | Core flow already works with `NavigationStack`, search, and list presentation. Header actions and filters need narrow-width fallbacks rather than redesign. |
| Task create/edit | Needs interaction redesign | Functional on iPhone, but the full editing form is not yet optimized for fast capture. UUID visibility and bottom-button workflow are Mac-biased. |
| Planner / calendar | Needs interaction redesign | Shared logic is good, but the surface is information-dense and built around wide cards, dense controls, and sheet sizing that assumed desktop space. |
| Settings | Deferred / missing | No live settings UI exists yet, so there is nothing to port in this phase. |

## Bugs And Risks To Expect

- Narrow-width compression in planner controls and metric cards.
- Sheet sizing or toolbar behavior differences between macOS and iPhone.
- iPhone-specific EventKit permission and writeback behavior needing real-device validation later.
- Hidden assumptions in tests or project settings that were safe in a macOS-only scheme.

## Recommended Sequencing

1. Keep one shared app composition root and one shared data stack.
2. Make the existing app target build for iPhone before redesigning feature flows.
3. Add light platform-aware view composition and remove obvious desktop sizing assumptions.
4. Focus the first iPhone UX pass on fast task capture and basic review/edit.
5. Leave deeper planner touch polish and CloudKit work until the shared shell is stable.
