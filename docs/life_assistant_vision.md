# Life Assistant Vision

The app is a personal planning hub for capturing obligations, planning time, executing routines, tracking personal growth, and noticing useful life patterns.

## App Identity

This repo is evolving from a task manager into a modular Life Assistant / personal planning hub. The Swift app remains the real product path. The legacy Python prototype remains useful as reference and test material, but it is not the production app path.

The product should feel like a practical personal secretary for daily planning, not a collection of disconnected trackers.

## Current Implemented Modules

The implemented Swift app currently centers on:

- Tasks
- Planner / Calendar

Current foundations to preserve:

- SwiftData persists app-owned data.
- EventKit owns Apple Calendar permission, reading, writing, and reconciliation.
- The planner engine remains pure Swift/domain logic.
- SwiftUI views should not become the source of business logic.
- Existing Tasks and Planner / Calendar behavior should continue to work.

## Future Modules

Likely future life domains include:

- Today dashboard
- Routines
- Sleep / PVT tracker
- Piano practice mode
- Workout tracking
- Food / meal tracking
- Reflection / anti-spiral journaling
- General life logs

These are not implemented yet unless the README or feature-specific docs say otherwise.

## Product Spine

Every future feature should map to at least one of these functions:

- Capture - get obligations, ideas, errands, and admin out of my head
- Plan - turn tasks into realistic time blocks around my calendar
- Execute - help me actually do the next thing
- Recover - help me reset when tired, scattered, behind, or low-energy
- Understand patterns - track useful signals across sleep, routines, practice, workouts, mood, etc.

Ideas that do not clearly serve one of these functions should be treated cautiously.

## Modular Life Domains

Future modules should be added as separate life domains. A domain can start as a short planning doc and a feature folder before it has models or UI.

Conceptual domain names:

- `TaskDomain`
- `RoutineDomain`
- `SleepDomain`
- `PracticeDomain`
- `WorkoutDomain`
- `NutritionDomain`
- `ReflectionDomain`

This is a documentation and folder-structure idea for now. Do not introduce protocols, generic registries, or plugin machinery unless a concrete implementation needs them.

## Design Principles

- Personal-use first.
- Daily-use usefulness over impressive feature count.
- Avoid feature sprawl.
- Avoid guilt/shame mechanics.
- Prefer gentle nudges and recovery paths.
- Keep Apple Calendar as the external calendar source of truth.
- Keep app-owned data in SwiftData.
- Keep domain logic testable outside SwiftUI.
- Build rule-based assistant behavior before any heavy AI integration.

## Domain Implementation Pattern

Future domains should generally follow this pattern:

```text
Models/
  Domain model types

Persistence/
  SwiftData records
  repository protocol
  SwiftData repository implementation

Features/<Domain>/
  view model
  presentation models
  SwiftUI views

Tests/
  model tests
  repository tests
  view model tests
```

Keep this pattern pragmatic. A small domain may not need every layer on day one, but business rules should still live outside SwiftUI views.

## Durable vs Ephemeral State

Durable app-owned state should be persisted.

Examples:

- tasks
- scheduled blocks
- routine definitions
- routine completions
- practice sessions
- PVT sessions
- reflection entries
- workout logs

Ephemeral UI/session state should not be synced or persisted unless there is a clear reason.

Examples:

- currently open sheet
- transient planner suggestions
- selected tab
- temporary filters
- currently selected calendar slot

## Calendar Rule

Only Planner / ScheduledBlock features should write to Apple Calendar.

Routines, practice, workouts, reflection, and other domains should not write to calendar directly unless mediated through the planner / scheduled-block system.

Apple Calendar remains the external calendar source of truth. App-owned planning records remain in SwiftData.

## Future Sync Rule

CloudKit sync should eventually apply only to durable app-owned data after the model is audited.

Do not start CloudKit until the SwiftData model is stable enough to review for sync identity, conflict behavior, privacy, deletion semantics, and migration risk.
