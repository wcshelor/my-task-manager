# Routines Feature

Scaffold only. No Routines UI, model, persistence, or view model is implemented yet.

## Purpose

Future feature area for morning, night, and custom routines with gentle completion tracking.

## Likely Future Objects

- `Routine`
- `RoutineItem`
- `RoutineCompletion`
- routines view model
- routine checklist presentation models

## Interaction With Tasks / Planner

Routine items may link to tasks. Scheduled routine time should flow through Planner / ScheduledBlock instead of writing directly to Apple Calendar.
