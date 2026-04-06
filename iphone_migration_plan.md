iPhone Version + Sync Plan for Task Manager

This plan is based on the repo’s current state in README.md and concrete_plan.md: the Swift app is already the real product path, SwiftData is already the app-side source of truth, EventKit is already the calendar boundary, and CloudKit sync is not implemented yet.

It also incorporates current Apple documentation on SwiftData + CloudKit sync, modern EventKit permission levels, and EKEventStoreChanged handling, plus practical caution from Apple Developer Forums where people report real-world sync and SwiftData edge cases.

iPhone Migration and Cross-Device Sync Plan
Goal

Evolve the existing Swift app from a mac-first local prototype into a two-device Apple-only app that works well on:

MacBook
iPhone

with these priorities:

Fast, comfortable task capture on iPhone
Shared synced task list across Mac + iPhone
iPhone access to planner/calendar functionality
No architectural damage to the current repo
No premature overengineering for multi-user or cross-platform support
Guiding Product Decisions
Product assumptions to freeze first

Before implementation, the code agent should assume the following are true unless explicitly changed:

there is one user only
that user uses one Apple ID
the app only needs to support Mac + iPhone
sync is for app-owned data, not for Apple Calendar itself
Apple Calendar remains the external source of truth for calendar events
app-owned entities that should sync are:
tasks
scheduled blocks
settings that matter across devices
the correct sync direction is SwiftData + CloudKit, not a shared iCloud folder with custom files

Apple’s SwiftData docs explicitly frame CloudKit-backed sync as the intended way to sync model data across a person’s devices.

Architectural principle to preserve

Do not collapse these boundaries:

App data boundary

SwiftData remains the source of truth for:

tasks
scheduled blocks
app settings
sync metadata
planner state that must survive launches
Calendar boundary

EventKit remains responsible for:

permission requests
calendar discovery
busy-time reads
accepted writeback into Apple Calendar
reconciliation with external calendar changes
Planner boundary

Pure Swift planner/domain logic remains responsible for:

gap detection
task ranking
suggestion generation
packing logic
slot reasoning

This boundary is already consistent with the repo’s current structure.

High-Level Risk Assessment
What is likely easy
keeping planner/domain logic shared across Mac + iPhone
keeping repositories shared across Mac + iPhone
reusing SwiftData as the persistence layer
reusing EventKit integration patterns already in the repo
syncing tasks with CloudKit once the data model is CloudKit-safe
What is likely medium difficulty
adapting the UI to narrow iPhone layouts
making task entry feel genuinely fast on phone
making planner/calendar interactions feel touch-native
testing all EventKit permission states and writeback behavior on real devices
resolving sync semantics for edited/deleted/reconciled scheduled blocks
What is likely the real danger zone
assuming Mac UI patterns will feel acceptable on iPhone
enabling CloudKit before auditing the model for sync compatibility
letting task status and scheduled-block state drift further apart
treating CloudKit sync as “magic” instead of a subsystem that needs device testing and conflict expectations

Apple’s docs are positive about managed CloudKit sync, but Apple Developer Forums show recurring reports of abnormal sync behavior, stalls, and SwiftData edge cases in real apps. That does not mean “don’t use it”; it means “use it carefully, with simple models and strong testing.”

Phase 0 — Freeze Scope and Success Criteria
Objective

Reduce ambiguity before code changes.

Deliverables

Create a short product note in docs/ that freezes:

supported platforms: macOS + iPhone only
supported sync scope: single-user, same Apple ID
synced data:
tasks
scheduled blocks
app settings
non-synced external data:
Apple Calendar events themselves
phone-first priority:
frictionless task entry
basic task review/edit
basic planner/calendar workflows
explicitly deferred:
collaboration
sharing tasks with others
web app
iPad-specific polish
widgets/watch complications unless later requested
Technical notes

The repo already says CloudKit is not yet implemented and should not be the immediate critical path before other hardening work. That warning is healthy and should remain reflected in planning docs.

Phase 1 — Audit the Existing Swift App for iPhone Readiness
Objective

Identify what already ports cleanly and what is macOS-shaped.

Tasks
1. Inventory platform assumptions

Audit the Swift app for:

#if os(macOS) branches
use of AppKit or mac-only behaviors
toolbar patterns that may not translate well
window-size assumptions
hover/right-click interactions
keyboard-heavy workflows
sheets/popovers/forms that will feel awkward on iPhone
2. Inventory layout risk

Review all major surfaces:

task list
task creation/edit screen
calendar/planner tab
settings surfaces if any hidden stubs already exist

Classify each screen:

portable as-is
needs layout adaptation
needs interaction redesign
3. Inventory data-flow portability

Confirm that these are UI-independent enough to share unchanged:

models
repositories
planner engine
EventKit service abstractions
reconciliation logic
validation logic
Deliverables

Produce an internal audit document listing:

reusable shared modules
platform-specific UI surfaces
platform-specific bugs to expect
sequencing recommendation for iPhone work
Technical notes

This phase should not change logic yet. It is meant to protect the codebase from a sloppy “just make it compile on iPhone” pass.

Phase 2 — Introduce an iPhone Target Safely
Objective

Get the app running on iPhone with the smallest possible blast radius.

Tasks
1. Add or adapt the app target

Create or update the iOS/iPhone app target while preserving:

shared model layer
shared repository layer
shared planner engine
shared EventKit service abstractions
2. Keep composition centralized

AppContainer / AppEnvironment should remain the composition root if possible. The goal is:

shared service construction
per-platform UI entry points
minimal duplication
3. Keep persistence bootstrapping unified

The model container / repository wiring should be shared as much as possible. Platform forks should be isolated to app entry and UI composition, not persistence semantics.

4. Add iPhone scheme/test path

Add command/build instructions so the repo can verify:

macOS build still works
iPhone simulator build works
iPhone tests run where applicable
Deliverables
iPhone target builds
app launches on iPhone simulator
existing mac build remains intact
no sync yet
no planner polish yet
Technical notes

At this point, success is just “shared architecture, separate platform shell,” not feature parity.

Phase 3 — Make Task Entry Excellent on iPhone
Objective

Build the phone flow that matters most: capture a task fast when an idea appears.

Why this phase comes early

Your product priority is not “full desktop parity.” It is “I can quickly dump tasks into the system from my phone.” That means the first phone UX must be optimized for:

one-handed use
minimal scrolling
minimal required fields
fast save
good defaults
later editing on desktop if needed
Tasks
1. Redesign task entry for phone ergonomics

The coding agent should create an iPhone-first task-entry flow with:

prominent title field
optional notes
estimated duration in easy quarter-hour increments
due date optional and quick to set
default values for priority/energy/work mode
minimal friction for tags
large tap targets
keyboard-aware layout
2. Separate “quick add” from “full edit”

Use two modes:

Quick Add

For rapid capture:

title
maybe notes
maybe duration
save immediately
Full Edit

For later refinement:

all metadata
status
tags
due date
energy/work mode
other advanced fields
3. Make default values deliberate

Choose defaults that minimize thought:

sensible default duration
neutral/default priority
no due date by default
task status default = inbox/open/new
optional “Add details later” mindset
4. Keep form logic shared where possible

Validation/parsing should remain shared with existing task form logic rather than being rewritten separately for iPhone.

Deliverables
iPhone quick-add flow
iPhone full-edit screen
save/edit/delete tested on simulator and device
task list reflects changes locally
Technical notes

This phase should produce something you would actually use daily even before sync exists.

Phase 4 — Build a Good iPhone Task List Experience
Objective

Make reviewing and editing tasks on iPhone feel comfortable, not just possible.

Tasks
1. Adapt list presentation for narrow width

Design for:

search at top
clear grouping/sorting controls
compact but readable rows
easy tap into details
swipe actions where useful
no dependence on desktop-like multi-pane layouts
2. Keep interaction lightweight

Likely iPhone-friendly actions:

swipe delete
swipe complete/archive if appropriate
tap row to edit
quick filters
segmented sort/group toggle if useful
3. Be careful with overloading rows

Do not try to show every attribute in the list row. Prioritize:

title
due date if important
duration
maybe priority marker
maybe scheduled indicator
Deliverables
useful iPhone task list
quick navigation to add/edit
shared underlying repository behavior unchanged
Phase 5 — Bring EventKit to iPhone Properly
Objective

Make sure the calendar layer is genuinely valid on iPhone, not just on Mac.

Why this needs special care

Modern EventKit access is more explicit than older “request access” flows. Apple distinguishes among:

no access
write-only access
full access

Apple’s guidance is that apps should only request full access if reading existing calendar data is core to the app’s functionality. Your planner does need to read existing events and manipulate linked events, so full access is justified here.

Tasks
1. Validate permission request path on iPhone

Test:

first launch with undetermined permission
granting full access
denying access
revoking access later in Settings
app relaunch after permission changes
2. Clean up permission UX

The iPhone app should clearly explain:

why it needs full access
what still works without it
how to recover if permission is denied
3. Verify read behavior

Confirm on real iPhone:

readable calendars are discovered correctly
excluded calendars are really excluded
busy-time read behavior matches Mac
4. Verify write/update/delete behavior

Confirm:

accepted suggestions create calendar events correctly
edits propagate
deletes/cancels propagate
missing or invalid write calendar surfaces a clear error
Deliverables
iPhone EventKit permission flow validated
iPhone write/read lifecycle works on real device
manual test notes added to docs/test_sessions/
Technical notes

The repo already identifies real manual EventKit validation as a top next step. That should now become a cross-platform validation pass, not a Mac-only one.

Phase 6 — Add Live Calendar Change Observation
Objective

Make the app react to external calendar changes while frontmost.

Apple documents EKEventStoreChanged / EKEventStoreChangedNotification as the notification posted when the Calendar database changes, and recommends listening for it to update app state.

Tasks
1. Add a dedicated observer layer

Create a small calendar change observer that:

subscribes to EKEventStoreChanged
debounces/coalesces refresh if needed
notifies the planner/view model layer
2. Define refresh semantics

On receipt of a store-change notification:

refresh relevant calendar snapshot
reconcile linked scheduled blocks
update visible timeline/planner state
avoid infinite loops from app-originated writes
3. Test behavior

Verify:

external event edits appear without app restart
external deletes reconcile into local state
multiple rapid changes do not thrash the UI
Deliverables
live store-change observation on both platforms
tests for observation trigger path where practical
fewer manual refresh requirements
Phase 7 — Adapt the Planner/Calendar UI for iPhone
Objective

Make the planner usable on touch devices without cramming the desktop UI into a narrow screen.

Principle

Do not aim for instant feature parity in visual form. Aim for functional parity with a different interaction model.

Tasks
1. Simplify the main planner presentation

On iPhone, likely prefer a vertically structured flow:

selected day
agenda / timeline summary
selected slot controls
plan generation controls
transient suggestions
accepted blocks

rather than trying to show too much at once.

2. Rework slot selection for touch

Quarter-hour selection is still a good rule, but touch interactions may need:

larger slot hit areas
drag gestures that are forgiving
fallback controls for start/end adjustment
sheet-based editing for exact times
3. Keep horizon planning simple

The “Plan by Horizon” modes are well suited to iPhone if presented cleanly:

next 2 hours
rest of today
tomorrow
next 7 days
4. Keep accepted-block lifecycle intact

Phone users should still be able to:

accept
reject
edit
reschedule
cancel
delete

but those actions may live in sheets/menus instead of dense inline controls.

Deliverables
usable iPhone planner screen
slot-based planning works
horizon-based planning works
accepted-block lifecycle works on iPhone
Phase 8 — Audit the SwiftData Model for CloudKit Compatibility
Objective

Prepare the model before turning sync on.

Why this matters

SwiftData can sync automatically through CloudKit, but the model must be compatible. Apple’s docs explicitly say to add capabilities and define a compatible schema.

Tasks
1. Inventory synced entities

Audit these records carefully:

TaskRecord
ScheduledBlockRecord
AppSettingsRecord

For each, document:

fields
relationships
optional/non-optional properties
uniqueness assumptions
derived vs persisted fields
fields that are purely local/UI/session only
2. Separate sync-worthy data from device-local/UI state

Do not sync ephemeral state unless it truly matters across devices.

Examples that may be local-only:

sheet open/closed state
current transient slot selection
temporary planner suggestions
session-local rejection list unless you intentionally want it shared

Examples that likely should sync:

tasks
accepted scheduled blocks
user settings that affect planner behavior
maybe task archival/completion metadata
3. Review model complexity

Look for model patterns likely to create sync pain:

over-coupled bidirectional relationships
too much duplicated truth
fields whose meaning is derived but also persisted independently
sync-sensitive status fields that can drift

This connects directly to the repo’s existing warning that scheduling semantics still partly live in task status instead of being fully derived from blocks. That should be tightened before sync becomes authoritative.

4. Decide conflict semantics now

Define how conflicts should behave conceptually:

if a task is edited on Mac and iPhone close together, what is acceptable?
if a scheduled block changes locally while external calendar reconciliation also updates it, which field wins?
do canceled/deleted blocks stay as history records or disappear?
Deliverables
model sync audit document
list of fields safe to sync
list of fields to keep local-only
proposed simplifications before CloudKit enablement
Phase 9 — Tighten Scheduling Semantics Before Sync
Objective

Reduce contradictory sources of truth before introducing multi-device behavior.

Why this matters

Right now, the repo already notes that task scheduling meaning partly lives in MyTask.status and partly in scheduled-block truth. That is survivable locally, but much more dangerous once sync and reconciliation are involved.

Tasks
1. Decide canonical scheduling truth

Prefer one primary truth source:

active scheduled blocks determine whether a task is scheduled
task status should not independently invent scheduling truth unless clearly separate
2. Normalize derived states

Clarify:

scheduled
canceled
deleted externally
completed
archived

Decide which are:

persisted raw states
derived view states
reconciliation outcomes
3. Reduce duplication

Where possible:

derive task scheduling presentation from linked blocks
reduce duplicate status meaning
make reconciliation update the canonical layer, not parallel state tracks
Deliverables
clarified scheduling semantics
migration/update plan if model fields need refactor
lower conflict risk before CloudKit
Phase 10 — Enable CloudKit for SwiftData
Objective

Turn on managed sync for the app-owned data.

Tasks
1. Add required capabilities and entitlements

Enable the appropriate iCloud/CloudKit capabilities for the app targets.

2. Configure the model container for CloudKit

Use SwiftData’s CloudKit-backed model configuration for the synced store. Apple’s managed sync path is the intended approach here.

3. Decide whether all entities live in one synced container

Likely simplest:

one CloudKit-backed model container for synced app data

Only split stores if there is a clear benefit.

4. Handle first-run migration carefully

Plan for existing local-only users:

preserve current local data
verify migration into synced storage
avoid duplicate tasks/records
test with preexisting sample data
5. Instrument for diagnosis

Add logging around:

container boot
save failures
sync-relevant errors
migration path
unusual duplication/conflict outcomes
Deliverables
CloudKit capability enabled
app launches with synced model container
no immediate crashes or migration corruption
basic create/edit/delete propagates between devices
Technical notes

Apple Developer Forums contain recurring reports of sync stalls and SwiftData weirdness in some apps. That argues for conservative rollout, strong logging, and physical-device testing rather than blind trust.

Phase 11 — Validate Cross-Device Sync on Real Hardware
Objective

Prove that Mac + iPhone actually stay in sync under realistic usage.

Test matrix
Task creation/editing

Verify:

add task on phone → appears on Mac
add task on Mac → appears on phone
edit title/notes/duration → propagates
delete/archive/complete → propagates
Scheduled blocks

Verify:

accept suggestion on Mac → block appears on phone
accept suggestion on phone → block appears on Mac
edit/reschedule/cancel/delete on one device → reflected on the other
Settings

Verify only for settings intentionally chosen to sync:

excluded calendars
write calendar title
planner defaults
suggestion cap
minimum gap minutes
Conflict-ish scenarios

Try:

edit same task on both devices close together
schedule on one device while editing metadata on the other
offline edit then reconnect
revoke calendar permission on one device only
Deliverables
documented sync test pass
list of observed delays/quirks
list of unacceptable failure modes to fix
Phase 12 — Add Sync-Aware UX and Recovery Behavior
Objective

Make the app understandable when sync or permissions are imperfect.

Tasks
1. Add sync status diagnostics

At minimum, support:

last successful save timestamp
last sync-relevant error
current device/platform
whether CloudKit-backed store loaded successfully
2. Add calendar diagnostics

Support:

permission state
selected write calendar
excluded read calendars
recent reconciliation results
3. Improve user-facing recovery

For example:

denied calendar access → show Settings recovery path
missing write calendar → prompt to choose/fix it
sync appears stalled → show troubleshooting hint, not silent failure
Deliverables
minimal settings/diagnostics UX
fewer invisible failure modes
Phase 13 — Final Polish and Hardening
Objective

Stabilize the two-device product rather than rushing into extra features.

Tasks
1. Performance check

Review:

task list query performance
planner refresh cost
reconciliation cost
sync overhead on launch/foreground
2. Data correctness check

Review:

no duplicated task records after migration/sync
no orphaned scheduled blocks
reconciliation states remain sane after external calendar edits
3. UX polish

Ensure:

task entry is fast
calendar explanation is clear
planner controls are touch-friendly
errors are understandable
4. Documentation update

Update:

README
concrete plan
testing docs
setup instructions for CloudKit/iCloud entitlements
manual test session notes
Deliverables
repo docs match reality
stable daily-use iPhone workflow
stable shared task list between Mac + iPhone
Recommended Order of Execution

This is the order I would actually have the coding agent follow:

Stage A — Foundation
Phase 0 — Freeze scope
Phase 1 — iPhone readiness audit
Phase 2 — add iPhone target safely
Stage B — Phone usefulness first
Phase 3 — excellent iPhone task entry
Phase 4 — good iPhone task list
Phase 5 — EventKit validation on iPhone
Phase 6 — live EKEventStoreChanged observation
Phase 7 — iPhone planner/calendar adaptation
Stage C — Sync preparation
Phase 8 — CloudKit model audit
Phase 9 — tighten scheduling semantics
Stage D — Sync rollout
Phase 10 — enable CloudKit
Phase 11 — real-device cross-device sync validation
Phase 12 — sync-aware diagnostics/recovery
Phase 13 — polish and documentation
Practical Guidance for the Coding Agent
General rules
do not rewrite the architecture
preserve current boundaries
prefer additive/refactoring-safe changes
keep Mac behavior working while adding iPhone support
do not introduce iPad-specific complexity unless necessary
do not start CloudKit work before the model audit
do not treat EventKit mocks as sufficient; require real-device passes
UI rules
iPhone does not need to mirror Mac layout
prioritize comfort and speed over desktop parity
task entry should be the first iPhone screen that feels truly good
planner can be simplified visually as long as capability remains
Data rules
sync only durable, app-owned state
keep ephemeral UI/session state local unless there is a compelling reason not to
reduce duplicate sources of scheduling truth before turning sync on
Testing rules

Every major phase should include:

mac regression check
iPhone simulator check
physical iPhone check where EventKit or CloudKit is involved
updated manual notes for anything OS-integrated
Documentation and Forum Research Summary
Apple docs most relevant to this work
SwiftData + CloudKit

Apple documents SwiftData’s CloudKit-backed sync as the supported path for syncing a person’s model data across their own devices, with emphasis on enabling capabilities and using a compatible schema.

EventKit permissions

Apple’s EventKit docs and WWDC material distinguish among no access, write-only access, and full access. Apps that only add events may use write-only or EventKitUI flows, but apps that need to read existing events and modify them should request full access. That matches this app’s planner needs.

Event store change notifications

Apple documents EKEventStoreChanged / EKEventStoreChangedNotification as the mechanism for reacting to calendar database changes. This should back the app’s live reconciliation path.

Forum/practitioner caution worth keeping in mind

Apple Developer Forums show recurring reports that SwiftData + CloudKit can sometimes exhibit abnormal sync behavior, stalls, or tricky runtime issues in real apps. Those reports are not a reason to avoid the stack, but they are a strong reason to:

keep the model simple
log aggressively
test on physical devices
avoid making sync the very first milestone
separate local/UI state from truly synced state carefully
Bottom Line

The correct path is not “make a separate iPhone app” and not “store task files in an iCloud folder.”

The correct path is:

keep the current Swift architecture
add an iPhone target safely
make task capture excellent on phone
validate EventKit properly on iPhone
tighten scheduling semantics
enable SwiftData + CloudKit for app-owned data
test the Mac+iPhone pair heavily on real hardware

That path fits both the repo’s current shape and Apple’s intended frameworks.

If you want, I can next turn this into a sequence of concrete coding-agent prompts, one phase per prompt.