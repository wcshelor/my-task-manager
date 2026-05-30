# Fitness Module

## Purpose

Fitness is now a standalone Home-reachable module for structured exercise logging.

It is separate from the older generic Health workout log. In v1 there is no migration, no shared writes, and no Apple Health integration.

## V1 Product Shape

The gym workflow is:

- open Fitness from Home
- pick a workout day or an exercise
- review the last one to three sessions
- log the current session with the date auto-stamped

The main screen has two surfaces:

- `Workout Days`: user-facing containers built from saved exercise order
- `Exercise Library`: the full exercise list with Recent, A-Z, and Tag sorting

## Durable Objects

- `FitnessExercise`
- `WorkoutTemplate`
- `ExerciseSession`
- `StrengthSet`

User-facing label: `Workout Day`

Internal durable type: `WorkoutTemplate`

## Exercise Rules

- Every exercise requires exactly one tag: `legs`, `push`, `pull`, or `cardio`.
- Every exercise requires one tracking style.
- `strengthSets` exercises store ordered sets with reps and optional weight.
- `metricSummary` exercises store a non-empty subset of:
  - `durationMinutes`
  - `difficultyLevel`
  - `averageRPM`
  - `distance`

## Unit Rules

- Units are stored per exercise, not app-wide.
- Strength exercises require `lb` or `kg`.
- Metric-summary exercises require `miles` or `kilometers` only when distance is enabled.

## Workout Day Rules

- A workout day must have a non-empty name and at least one exercise.
- It stores an ordered, unique list of exercise IDs.
- Duplicate exercise IDs are normalized away while preserving the first occurrence order.
- The same exercise can appear in multiple workout days.

## Session Rules

- Every session stores `exerciseID`, `performedAt`, `createdAt`, and `updatedAt`.
- New sessions auto-stamp `performedAt`.
- Editing preserves the original `performedAt`.
- Logged-today state is derived from any same-day session for that exercise.
- V1 has no workout-completion object, plan object, charts, archive flow, or Health sync.

## Persistence Shape

Fitness owns its own repository and SwiftData records:

```text
Models/
  FitnessModels.swift

Persistence/
  Repositories/
    FitnessRepository.swift
  SwiftDataModels/
    FitnessExerciseRecord.swift
    WorkoutTemplateRecord.swift
    ExerciseSessionRecord.swift
  SwiftDataRepositories/
    SwiftDataFitnessRepository.swift

Features/Fitness/
  FitnessViewModel.swift
  FitnessView.swift
```

The repository is intentionally simple. View models do recent-session grouping and filtering in memory because the expected data volume is small.

## Relationship To Health

- Health still owns the older lightweight generic workout log.
- Fitness now owns structured exercise progression, workout days, and per-exercise history.
- A later migration can consolidate those systems, but that is explicitly deferred.

## Status

Implemented work in progress. Fitness has its own Home module entry, SwiftData persistence, workout-day editing, exercise detail/history, and session logging, but still needs broader manual QA and product polish.
