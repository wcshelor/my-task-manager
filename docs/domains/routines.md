# Routines Domain

Routines are a first-pass Life Assistant domain in the Swift app.

## Purpose

Support recurring morning, night, and custom checklists that help the user execute useful habits without turning the app into a guilt system.

## Current Objects

- `Routine`
- `RoutineItem`
- `RoutineCompletionLog`

Current fields include:

- routine name
- active days or recurrence pattern
- ordered items
- item completion state for a date

Possible future fields:

- optional expected duration
- skip reason or gentle deferral state
- optional link from a routine item to a task

## Interaction With Tasks / Planner

Routine items may create or link to tasks when they represent concrete obligations. Routines should not write directly to Apple Calendar. If routine time needs scheduling, it should flow through the planner / scheduled-block system.

## Status

Implemented in Swift as user-authored routines with daily or selected-weekday recurrence, Today visibility, and per-day item-level completion logs.
