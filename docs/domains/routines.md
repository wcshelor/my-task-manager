# Routines Domain

Routines are likely the first real Life Assistant expansion after the current task/planner hardening work.

## Purpose

Support recurring morning, night, and custom checklists that help the user execute useful habits without turning the app into a guilt system.

## Likely Objects

- `Routine`
- `RoutineItem`
- `RoutineCompletion`

Possible future fields:

- routine name
- active days or recurrence pattern
- ordered items
- optional expected duration
- item completion state for a date
- skip reason or gentle deferral state
- optional link from a routine item to a task

## Interaction With Tasks / Planner

Routine items may create or link to tasks when they represent concrete obligations. Routines should not write directly to Apple Calendar. If routine time needs scheduling, it should flow through the planner / scheduled-block system.

## Status

Scaffold only. No Routine model, persistence, view model, or UI exists yet.
