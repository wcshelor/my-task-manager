# Today Feature

Scaffold only. No Today dashboard is implemented yet.

## Purpose

Future home screen / secretary dashboard for surfacing what matters today across tasks, scheduled blocks, routines, check-ins, practice, and recovery.

## Likely Future Objects

- Today summary presentation model
- dashboard card view models
- quick-capture state

## Interaction With Tasks / Planner

Today should aggregate from existing domains and delegate actions back to Tasks, Planner, and future domain view models. It should not own task scheduling or calendar writeback logic.
