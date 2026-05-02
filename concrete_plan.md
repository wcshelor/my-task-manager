# Concrete Plan

This plan keeps the current Swift task/planner app stable while the repo starts orienting toward a broader Life Assistant / personal planning hub.

The Swift app remains the production path. The Python prototype remains reference/test material.

## Current Implemented Core

- Tasks
- Planner / Calendar
- SwiftData persistence for app-owned tasks, scheduled blocks, and settings
- EventKit integration for calendar permission, reads, writes, updates, deletes, and reconciliation
- Pure Swift planner engine for busy-time merging, gap detection, and task ranking

## Near-Term Technical Hardening Priorities

Preserve these priorities before broad feature expansion:

1. Manual EventKit validation
   - Verify permission states, readable-calendar filtering, write-calendar selection, accept/update/delete flows, and reconciliation against a real calendar account.
2. Store-change observation
   - Keep validating that EventKit store-change notifications refresh the planner at the right time without excessive churn.
3. Settings UI
   - Add user-facing controls for persisted planner/calendar settings.
4. Planner quality improvements
   - Improve suggestion quality, alternatives, packing behavior, and low-energy/admin/errand planning modes without breaking the current acceptance flow.
5. Scheduling semantics cleanup
   - Clarify the relationship between task status and scheduled-block truth.
   - Keep `ScheduledBlock` as the bridge between app tasks and Apple Calendar events.
6. CloudKit later
   - Do not start CloudKit until the SwiftData model is audited for sync identity, conflict behavior, deletion semantics, privacy, and migration risk.

## Life Assistant Expansion Path

The broader product direction is a modular Life Assistant: a personal planning hub for capturing obligations, planning time, executing routines, tracking personal growth, and noticing useful life patterns.

Proposed expansion order:

1. Add documentation and repo structure for modular life domains.
2. Add first-pass Routines domain.
3. Add Today dashboard.
4. Integrate Sleep / PVT check-in.
5. Add lightweight Piano Practice Mode.
6. Add optional general logging domains: workouts, food, reflection.
7. Only later consider sync for all durable app-owned data.

CloudKit should still not be started until the model is audited.

## Architecture Rules To Preserve

- SwiftData persists app-owned durable state.
- EventKit owns Apple Calendar permission, reads, writes, and reconciliation.
- Planner/domain logic stays testable outside SwiftUI.
- SwiftUI views should not become the source of business logic.
- Only Planner / ScheduledBlock flows should write to Apple Calendar.
- Routines, practice, workouts, food, and reflection should not write directly to calendar.
- Future domains should be added as separate life domains, not as ad hoc logic inside existing views.

## Current Non-Goals

- Do not implement full routines yet.
- Do not implement PVT.
- Do not implement piano practice logging.
- Do not implement workout tracking.
- Do not implement anti-spiral journaling.
- Do not add CloudKit.
- Do not rewrite the planner.
- Do not replace the EventKit architecture.
