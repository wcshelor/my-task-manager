# Routines Feature

First-pass Routines support is implemented through shared domain models, SwiftData persistence, Today view-model aggregation, and Today UI.

## Purpose

Feature area for morning, night, and custom routines with gentle completion tracking.

## Current Objects

- `Routine`
- `RoutineItem`
- `RoutineCompletionLog`
- `RoutineRepository`
- `TodayViewModel` routine aggregation

## Interaction With Tasks / Planner

Routine items may link to tasks. Scheduled routine time should flow through Planner / ScheduledBlock instead of writing directly to Apple Calendar.
