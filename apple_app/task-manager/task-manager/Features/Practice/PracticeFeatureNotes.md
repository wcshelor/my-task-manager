# Practice Feature

Scaffold only. No piano practice mode, model, persistence, or view model is implemented yet.

## Purpose

Future feature area for piano goals, active pieces, practice skills, and practice sessions.

## Likely Future Objects

- `PieceGoal`
- `PracticeSkill`
- `PracticeSession`
- practice mode view model

## Interaction With Tasks / Planner

Practice goals may create tasks. Practice sessions should be persisted as app-owned data. Scheduled practice time should go through Planner / ScheduledBlock.
