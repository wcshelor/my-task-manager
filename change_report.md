# Change Report

## Executive summary

The real product path in this repository is the SwiftUI app in `apple_app/task-manager/`. The Python code under `src/` and `tests/` is still documented as an active reference surface, but it is not wired into the Swift app runtime (`README.md:3-8`).

The Swift app already compiles for a real iPhone device architecture. During this audit on April 22, 2026, the command below succeeded:

```bash
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj \
  -scheme task-manager \
  -destination 'generic/platform=iOS' \
  build CODE_SIGNING_ALLOWED=NO
```

That means the main migration problem is not "can the Swift code compile for iPhone?" The main problem is that the current project is still configured like a shared macOS+iPhone app with CloudKit/iCloud assumptions, hard-coded signing settings, and leftover sync-oriented behavior that work against the new goal of a single-user, iPhone-only app that must run on a real device with an unpaid Apple Personal Team account.

The simplest viable target state is:

- one iPhone app target
- local-only SwiftData persistence
- no CloudKit/iCloud sync
- no macOS support
- EventKit kept for busy-time reads and accepted-block write-back
- a minimal on-device settings/onboarding flow for calendar permission and write-calendar selection

The Python prototype is a reasonable removal candidate for this direction. It is not a runtime dependency of the Swift app, but removing it would require cleanup of test scripts, docs, and Python environment files.

## Current repo architecture

### Platforms, targets, and major surfaces

The repository currently contains two implementation surfaces:

- SwiftUI Apple app: `apple_app/task-manager/`
- Python prototype/reference surface: `src/`, `tests/`, `scripts/`, `environment.yml`, `requirements.txt`

The Xcode project contains one app target and one unit-test target:

- `task-manager`
- `task-managerTests`

Evidence:

- `xcodebuild -list -project apple_app/task-manager/task-manager.xcodeproj`
- `apple_app/task-manager/task-manager.xcodeproj/project.pbxproj:335-470`

The Apple app target is still configured as a shared multi-platform target, not an iPhone-only target:

- `SUPPORTED_PLATFORMS = "macosx iphoneos iphonesimulator"` appears at both project and target levels (`project.pbxproj:271, 330, 366, 407, 435, 464`)
- `TARGETED_DEVICE_FAMILY = 1` already limits the iOS slice to iPhone (`project.pbxproj:372, 413`)
- `MACOSX_DEPLOYMENT_TARGET = 26.2` is still configured (`project.pbxproj:266, 326, 431, 460`)

The app shell is one SwiftUI app that still branches for iOS vs. macOS at the view-composition level:

- `task_managerApp.swift` launches a single `WindowGroup` (`apple_app/task-manager/task-manager/task_managerApp.swift:11-28`)
- `ContentView.swift` chooses `IPhoneRootView` vs. `MacRootView`, but both currently feed the same `TaskManagerTabShell` (`apple_app/task-manager/task-manager/ContentView.swift:22-91`)

### Swift module layout

The Swift app is already organized into clean functional seams:

- `App/`: composition root and environment (`AppContainer.swift`, `AppEnvironment.swift`)
- `Models/`: task and scheduling domain types
- `Persistence/`: repository protocols, SwiftData models, SwiftData repositories, container factory
- `Calendar/`: calendar contracts, EventKit implementation, stubs
- `Planner/`: planning contracts and pure-Swift planner engine
- `Features/Tasks/`: task list view model
- `Features/Planner/`: planner view model and presentation models
- `Views/`: SwiftUI task and planner screens

That structure is compatible with an iPhone-only MVP and does not need a ground-up rewrite.

### Persistence strategy and sync assumptions

Live app persistence is SwiftData-based and covers:

- tasks
- scheduled blocks
- app settings

Evidence:

- `apple_app/task-manager/task-manager/App/AppContainer.swift:15-60`
- `apple_app/task-manager/task-manager/Persistence/SwiftDataRepositories/`
- `apple_app/task-manager/task-manager/Persistence/SwiftDataModels/`

However, the live model container is not purely local today. `ModelContainerFactory.swift` configures the live store to use a private CloudKit database:

- `apple_app/task-manager/task-manager/Persistence/ModelContainerFactory.swift:3-33`

Specifically:

- `cloudKitContainerIdentifier = "iCloud.camp.task-manager"`
- `ModelConfiguration(cloudKitDatabase: .private(cloudKitContainerIdentifier))`

The app also still contains sync-oriented reload logic:

- `TaskListView.swift` imports `CoreData` only to listen for `.NSPersistentStoreRemoteChange` (`apple_app/task-manager/task-manager/Views/TaskListView.swift:1, 148-158`)

There is no direct `import CloudKit` usage in the app code. The sync dependency currently enters through:

- SwiftData CloudKit-backed configuration
- iCloud/CloudKit entitlements
- remote-change assumptions in the UI

That is good news for the migration: the codebase is not deeply coupled to hand-written CloudKit APIs.

### Calendar integration status

Calendar integration already exists and is not merely aspirational.

Core contracts:

- `apple_app/task-manager/task-manager/Calendar/CalendarContracts.swift:3-106`

Concrete EventKit adapter:

- `apple_app/task-manager/task-manager/Calendar/EventKit/EventKitCalendarEventStore.swift:57-256`

Service layer:

- permission service (`EventKitCalendarPermissionService`)
- readable calendar listing (`EventKitCalendarListingService`)
- event reading (`EventKitCalendarReader`)
- event writing (`EventKitCalendarWriter`)
- reconciliation against external edits/deletes (`EventKitCalendarReconciler`)

Evidence:

- `apple_app/task-manager/task-manager/Calendar/EventKit/EventKitCalendarServices.swift:43-360`

App composition shows these services are part of the live container, not an optional future layer:

- `apple_app/task-manager/task-manager/App/AppContainer.swift:24-45`

Planner-side usage is also live:

- planner generation requires full calendar access and reads busy time from EventKit (`PlannerViewModel.swift:300-352`)
- accepting a suggestion validates the write calendar, saves a `ScheduledBlock`, creates an EventKit event, and links the identifiers back (`PlannerViewModel.swift:355-430`)
- refresh/reconciliation pulls data back from EventKit (`PlannerViewModel.swift:672-688`)

### Current product direction documented in the repo

The repo docs still describe the app as a broader Apple-platform project rather than an iPhone-only local app:

- `README.md:5-8` says the Swift app targets macOS and iPhone
- `docs/iphone_product_scope.md:7-24` says supported platforms are macOS and iPhone
- `docs/iphone_product_scope.md:8-13` still talks about one-user personal-device sync scope

There is also a notable inconsistency between docs and the actual project state:

- `README.md:195` says "CloudKit sync" is not implemented yet
- the live SwiftData container is already configured with `cloudKitDatabase: .private(...)` in `ModelContainerFactory.swift:27-29`

That suggests either an incomplete CloudKit migration or documentation drift. It should be treated as ambiguity before refactoring.

## Incompatibilities with unpaid iPhone deployment

### 1. iCloud / CloudKit is the main capability and signing risk

The iOS app target currently carries iCloud/CloudKit entitlements:

- `apple_app/task-manager/task-manager/task-manager-ios.entitlements:5-12`

The macOS entitlements file also carries iCloud/CloudKit:

- `apple_app/task-manager/task-manager/task-manager.entitlements:5-12`

The live SwiftData store explicitly depends on CloudKit:

- `apple_app/task-manager/task-manager/Persistence/ModelContainerFactory.swift:24-29`

Why this matters:

- Apple’s capability docs state that capability availability depends on platform and program membership.[^cap-overview][^supported-capabilities]
- SwiftData’s automatic sync guidance says iCloud sync requires both the iCloud capability and Background Modes.[^swiftdata-sync]
- The requested migration explicitly wants local-only persistence and no cross-device sync.

Practical conclusion:

- Even if parts of this configuration might be usable in some local-development contexts, it is the wrong architecture for the new goal and the most likely capability/signing pain point on a Personal Team.
- For this migration, CloudKit/iCloud should be treated as a required removal, not as a feature to preserve.

### 2. The project still has multi-platform macOS build assumptions

The app target is still configured as shared macOS+iPhone:

- `SUPPORTED_PLATFORMS = "macosx iphoneos iphonesimulator"` (`project.pbxproj:271, 330, 366, 407`)
- macOS deployment target is set (`project.pbxproj:266, 326`)
- separate macOS entitlements are selected using `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` (`project.pbxproj:340-341, 381-382`)
- macOS-only signing/capability settings remain, including app sandbox, hardened runtime, and user-selected files (`project.pbxproj:347-350, 388-391`)

There are also surviving code-level macOS branches:

- `ContentView.swift:29-34`
- `TaskFormView.swift:89-95, 251-263`
- `App/PlatformViewModifiers.swift`

These are not fatal to an iPhone build, but they add unnecessary complexity and leave the project positioned as a dual-platform app when the stated goal is explicitly iPhone-only.

### 3. Hard-coded signing assumptions are fragile for Personal Team use

The project file hard-codes:

- `DEVELOPMENT_TEAM = 83KWTTM2DT` (`project.pbxproj:246, 312, 346, 387, 423, 452`)
- app bundle identifier `com.camp.task-manager.dev` (`project.pbxproj:361, 402`)
- test bundle identifier `camp.task-managerTests` (`project.pbxproj:432, 461`)

Why this matters:

- A different Personal Team will need Automatic signing with the user’s own team selected.
- Hard-coded team IDs are one of the first things that break when another machine or Apple account tries to run the project on a real device.
- The bundle identifier situation is already inconsistent across repo artifacts:
  - project/build output: `com.camp.task-manager.dev`
  - README/test-session docs: `camp.task-manager` (`README.md:28`, `docs/test_sessions/2026-04-10_iphone_simulator_launch_smoke.md`)

Personal Team note:

- Apple’s QA1915 says a free Personal Team can sign apps for personal use on devices owned by the developer, but cannot be used for App Store submission.[^qa1915]

That is compatible with this migration goal, but it means the project should be optimized for local device deployment rather than distribution workflows.

### 4. Deployment target may block older real iPhones

The project sets:

- `IPHONEOS_DEPLOYMENT_TARGET = 26.2` (`project.pbxproj:264, 324, 355, 396, 425, 454`)

That is not a Personal Team restriction by itself, but it is a real on-device deployment constraint. The target phone must actually be on iOS 26.2 or later, or the project must intentionally lower the deployment target.

For a personal MVP, this needs an explicit decision instead of being left implicit.

### 5. Current calendar write configuration is fragile on a real device

The app requires full calendar access for both reading and writing:

- `EventKitCalendarEventStore.requestFullAccessToEvents()` (`EventKitCalendarEventStore.swift:83-85`)
- `EventKitCalendarReader` requires full access before reading (`EventKitCalendarServices.swift:111-118`)
- `EventKitCalendarWriter` requires full access and resolves the write calendar by title (`EventKitCalendarServices.swift:230-263`)

The default settings currently assume:

- `writeCalendarTitle = "Important"` (`SchedulingModels.swift:110-116`)

But the repo also says there is still no user-facing settings screen:

- `README.md:183`

Why this matters:

- On a real iPhone, there may be no calendar named `"Important"`.
- There may be multiple calendars with the same title.
- The current writer explicitly fails on missing or ambiguous title matches (`EventKitCalendarServices.swift:238-249`).

This does not block signing, but it will block or complicate successful real-device use unless a minimal settings/onboarding flow is added.

### 6. What I did **not** find

I did **not** find evidence of these additional paid-capability complications in the current repo:

- no App Groups entitlement in the entitlements files
- no push notifications entitlement (`aps-environment`)
- no `UIBackgroundModes` configuration in the project
- no widget, app extension, watch, or other auxiliary targets
- no direct `CloudKit` framework code

One small cleanup note:

- `REGISTER_APP_GROUPS = YES` is still present in the app target build settings (`project.pbxproj:364, 405`) even though no App Groups entitlement is present. That is probably just residue and should be removed while simplifying signing.

## What should be removed, simplified, or deferred

### Remove

- CloudKit-backed SwiftData configuration in `Persistence/ModelContainerFactory.swift`
- iCloud/CloudKit entitlements from both `task-manager-ios.entitlements` and `task-manager.entitlements`
- macOS support from the app target, including macOS-specific build settings and entitlements selection in `project.pbxproj`
- sync-oriented `.NSPersistentStoreRemoteChange` listening in `Views/TaskListView.swift`
- Python prototype/runtime/test/tooling surface if the repo truly no longer wants a second implementation path:
  - `src/`
  - `tests/`
  - `environment.yml`
  - `requirements.txt`
  - `pytest.ini`
  - `scripts/core_smoke_check.py`
  - Python-specific parts of `scripts/manual_test_session.sh`

### Simplify

- Collapse iOS/macOS root branching where it no longer buys anything:
  - `ContentView.swift`
  - `TaskFormView.swift`
  - `App/PlatformViewModifiers.swift`
- Treat SwiftData as local app storage only, not as a sync layer
- Keep `ScheduledBlock` as the link between tasks and calendar events, but do not treat it as cross-device sync state
- Replace title-based calendar selection with identifier-based selection for the write calendar
- Move the repo narrative from "Swift + Python + Mac + iPhone" to "iPhone app first"

### Defer

- any future CloudKit or multi-device sync work
- macOS support
- broader Apple ecosystem features such as widgets, extensions, or watch support
- aggressive architectural generalization for multiple Apple platforms

## What can stay

The Swift app already has a lot worth keeping.

### Core architecture

- `AppContainer.swift` and `AppEnvironment.swift` are solid seams for composing the app
- repository protocols in `Persistence/Repositories/` are still useful
- SwiftData record/repository pairs for tasks, scheduled blocks, and settings are still appropriate for a local iPhone app

### Domain model

- `Models/MyTask.swift`
- `Models/MyTaskFormData.swift`
- `Models/SchedulingModels.swift`
- `ScheduledBlock` specifically remains valuable even without CloudKit because it links local tasks to EventKit events and supports reconciliation

### Calendar layer

- `CalendarContracts.swift` is a good abstraction boundary
- `EventKitCalendarEventStore.swift` and `EventKitCalendarServices.swift` are directly relevant to an iPhone-only app
- the current reconciliation model is still useful if accepted planner blocks continue to be written into Calendar

### Planner layer

- `Planner/PlannerEngine.swift` is already pure Swift and UI-independent
- `Features/Planner/PlannerViewModel.swift` encapsulates the end-to-end planner workflow well
- planner presentation models and timeline logic are reusable on iPhone

### UI flows

- task list and task form flows
- `Views/TaskQuickAddView.swift` for fast iPhone capture
- planner screen and suggestion/accept/edit/reschedule flows

### Tests

- the Swift test structure is worth keeping
- examples:
  - `task-managerTests/Calendar/EventKitCalendarServicesTests.swift`
  - `task-managerTests/Persistence/*.swift`
  - `task-managerTests/Planner/*.swift`
  - `task-managerTests/Features/TaskListViewModelTests.swift`

One caveat:

- today the easiest test workflow uses a macOS destination for the shared target
- once the app becomes iPhone-only, the tests should remain, but the preferred destination will likely shift to iOS simulator rather than macOS host execution

## Recommended iPhone-only architecture

### Target and project setup

The project should become:

- one iPhone app target: `task-manager`
- one unit-test target: `task-managerTests`
- no macOS platform slice
- no macOS entitlements file
- Automatic signing with the current developer’s Personal Team

Whether to remove or ignore macOS support:

- I recommend removing it rather than merely ignoring it.
- The current repo has only light macOS branching, so the cleanup cost is low.
- Keeping the macOS slice around would continue to complicate signing, project settings, and reasoning about scope.

### Minimal viable data architecture

The clean iPhone-only MVP architecture is:

- `MyTask` remains the local source of truth for task data
- `ScheduledBlock` remains the local source of truth for accepted planner placements
- SwiftData persists tasks, scheduled blocks, and settings locally on device
- EventKit is treated as an external integration layer, not as app-owned storage

Recommended live container behavior:

- local-only `ModelContainer`
- no `cloudKitDatabase`
- no iCloud container dependency
- no sync-specific reload observers

### Calendar handling on iPhone

Keep full EventKit read/write support.

That is the right choice for this app because:

- the planner needs to read existing calendar busy time
- accepted suggestions are meant to write back into Calendar
- EventKit does not offer a read-only access mode; if the app needs to read events, it needs full access.[^eventkit]

Recommended on-device flow:

- first launch or first planner use: request full calendar access
- if access is granted: show readable calendars and let the user choose:
  - the write calendar
  - optionally excluded read calendars
- persist the chosen write calendar by stable calendar identifier, not by title
- keep display titles for the UI only

Why identifier-based storage is better:

- titles are user-editable
- multiple calendars can share the same title
- the current title-based writer already treats duplicate titles as an error

### Info.plist and permissions

The project currently generates its Info.plist from build settings rather than a checked-in plist file:

- `GENERATE_INFOPLIST_FILE = YES` (`project.pbxproj:351, 392, 424, 453`)

It already includes:

- `NSCalendarsFullAccessUsageDescription` (`project.pbxproj:352, 393`)
- `NSCalendarsUsageDescription` (`project.pbxproj:353, 394`)

Recommended direction:

- keep `NSCalendarsFullAccessUsageDescription` because this app needs to read and write calendar data[^eventkit]
- if the deployment target remains iOS 17+, the full-access key is the critical one
- if the deployment target is lowered to support pre-iOS-17 devices, keeping the older fallback key is still sensible

### Minimal viable module structure after simplification

The existing Swift folders are already close to the correct MVP shape:

- `App/`
- `Models/`
- `Persistence/`
- `Calendar/`
- `Planner/`
- `Features/Tasks/`
- `Features/Planner/`
- `Views/`

The key simplification is not reorganization. The key simplification is removing:

- CloudKit
- macOS
- Python
- sync-specific assumptions

## Recommended migration steps

1. **Required:** Remove iCloud/CloudKit from the iOS target. Delete the iCloud/CloudKit entitlements, remove CloudKit-backed SwiftData configuration, and make the live model container local-only.
2. **Required:** Convert the project from shared macOS+iPhone to iPhone-only. Remove `macosx` from supported platforms, remove the macOS entitlements path and macOS signing settings, and keep one iPhone app target.
3. **Required:** Normalize signing for Personal Team use. Keep Automatic signing, replace the hard-coded `DEVELOPMENT_TEAM`, confirm a unique app bundle ID, confirm a unique test bundle ID, and remove stale bundle-ID references in docs.
4. **Required:** Decide whether `IPHONEOS_DEPLOYMENT_TARGET = 26.2` is intentional. If the target phone may be older, lower it before device testing.
5. **Required:** Preserve EventKit full-access support and keep the calendar privacy strings. Add a minimal settings/onboarding surface so the user can select a real write calendar on-device.
6. **Required:** Change write-calendar persistence from title-based matching to identifier-based matching. Keep titles only for UI display.
7. **Recommended simplification:** Remove `.NSPersistentStoreRemoteChange` handling and any other sync-oriented assumptions once CloudKit is gone.
8. **Recommended simplification:** Delete the Python prototype and its tooling/docs if the repo no longer wants a second implementation surface. This includes `src/`, `tests/`, Conda/pip files, smoke scripts, and Python-oriented workflow docs.
9. **Recommended simplification:** Rewrite `README.md`, testing workflow docs, and migration-scope docs so they describe a single iPhone product path instead of Swift+Python and Mac+iPhone.
10. **Optional cleanup:** Collapse remaining `#if os(macOS)` UI branches that no longer serve a purpose after the macOS slice is removed.
11. **Optional cleanup:** Archive or delete stale migration/readiness docs that still describe cross-device sync, shared Mac+iPhone scope, or Python as an active behavioral reference.
12. **Verification step:** After the refactor, verify a full real-device run on a Personal Team-signed iPhone, not just simulator or unsigned generic-device builds.

## Risks, ambiguities, and things to verify

- **CloudKit ambiguity in the repo:** the docs say CloudKit sync is not implemented yet (`README.md:195`, `docs/iphone_product_scope.md:33`), but the live SwiftData container is already configured with a private CloudKit database (`ModelContainerFactory.swift:27-29`). That mismatch should be resolved before making assumptions about current behavior.
- **Bundle identifier inconsistency:** the project currently builds with `com.camp.task-manager.dev`, but README and some test-session notes still refer to `camp.task-manager`. Signing and documentation should be aligned before refactoring.
- **Real-device OS version:** the current deployment target is iOS 26.2. Verify the intended physical iPhone actually meets that version, or plan a deployment-target change as part of the migration.
- **Calendar write calendar configuration:** the app currently defaults to `"Important"` as the write calendar and has no settings UI. Without a settings/onboarding change, real-device testing may fail even after signing is fixed.
- **EventKit validation gap:** the repo itself says there has not yet been a full real EventKit validation pass for permission states, excluded calendars, write-calendar selection, accept/edit/delete flows, and reconciliation (`README.md:32-38, 181-187`).
- **Python removal blast radius:** removing the Python surface is architecturally reasonable, but it will break current Python-oriented docs, scripts, and manual test workflows unless they are cleaned up in the same effort.
- **Test workflow change:** once macOS support is removed, some existing `xcodebuild -destination 'platform=macOS' test` habits will no longer apply. The tests can stay, but the workflow should shift to iOS simulator destinations.
- **Capability interpretation:** Apple’s current documentation clearly ties capabilities to membership and platform, but the safest path for this repo does not depend on proving every Personal Team edge case. Removing CloudKit/iCloud is the right move regardless because the target product no longer wants sync.[^cap-overview][^supported-capabilities][^adding-capabilities]

## Official Apple references

[^qa1915]: Apple, "Technical Q&A QA1915: Your (Personal Team) cannot be used to Code Sign your App for submission to the App Store." https://developer.apple.com/library/archive/qa/qa1915/_index.html

[^cap-overview]: Apple, "Capabilities overview." https://developer.apple.com/help/account/capabilities/capabilities-overview

[^supported-capabilities]: Apple, "Supported capabilities (iOS)." https://developer.apple.com/help/account/reference/supported-capabilities-ios/

[^adding-capabilities]: Apple, "Adding capabilities to your app." https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app

[^swiftdata-sync]: Apple, "Syncing model data across a person's devices." https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices

[^eventkit]: Apple, "Accessing the event store." https://developer.apple.com/documentation/eventkit/accessing-the-event-store
