# Today Feature

First-pass Today dashboard support is implemented as the app's first tab.

## Purpose

Home screen / secretary dashboard for surfacing what matters today across promises, routines, tasks, scheduled blocks, practice, and recovery.

## Current Objects

- `TodayViewModel`
- `TodayRoutineProgress`
- `PromisePresenceViewModel`

Future objects may include:

- richer Today summary presentation models
- dashboard card view models
- quick-capture state

## Interaction With Tasks / Planner

Today should aggregate from existing domains and delegate actions back to Tasks, Planner, and future domain view models. It should not own task scheduling or calendar writeback logic.
