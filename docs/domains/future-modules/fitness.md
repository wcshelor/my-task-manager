# Health: Fitness Subdomain

## Purpose

Fitness tracking should help the user log workouts, maintain consistency, and understand how exercise interacts with energy, sleep, routines, food, and planning.

This is a subdomain of Health. It should be a workout/session domain, not just a habit checkbox. Routines can remind the user to work out, but Health records what actually happened.

## Product Shape

The first version should support simple workout logging:

- workout type
- duration
- intensity
- notes
- optional energy or mood effect

Later versions can support exercise templates, sets, reps, progression, and planned workout blocks.

## Possible Objects

- `WorkoutLog`
- `WorkoutType`
- `Exercise`
- `ExerciseSet`
- `WorkoutTemplate`
- `WorkoutPlan`

Start with `WorkoutLog`. Add detailed exercise tracking only when needed.

## Possible Log Fields

A `WorkoutLog` might include:

- timestamp
- workout type: strength, cardio, mobility, walk, sport, other
- duration
- intensity
- energy before
- energy after
- notes
- optional linked routine item
- optional linked scheduled block

## Interaction With Today / Planner

Today can show:

- planned workout
- last workout
- due routine item connected to fitness
- quick log button

Planner should schedule workouts only through task or scheduled-block flows. Health / Fitness should not write directly to Apple Calendar.

If a workout is planned but not completed, the app should support recovery-friendly rescheduling rather than guilt mechanics.

## Interaction With Health / Nutrition / Vices / Logs

Fitness can eventually support Health pattern review with:

- meal timing
- sleep
- PVT results
- vice logs
- mood or energy logs
- routine completion

This should come after basic workout logging is reliable.

## Implementation Sketch

```text
Models/
  FitnessModels.swift
  WorkoutLogModels.swift

Persistence/
  SwiftDataModels/
    WorkoutLogRecord.swift
  Repositories/
    FitnessRepository.swift
  SwiftDataRepositories/
    SwiftDataFitnessRepository.swift

Features/Health/Fitness/
  Quick workout log
  Workout history
  Optional workout detail view
```

Keep workout rules and summary logic testable outside SwiftUI.

## Design Principles

- Make logging easy after a workout.
- Treat missed workouts as planning data, not failure.
- Keep routines and workout logs conceptually separate.
- Add detailed progression tracking only after simple logs prove useful.

## Open Questions

- Should Fitness appear as a subview within Health, or also have shortcuts from Today?
- Should workout templates be included in the first implementation?
- Should Apple Health integration be considered later, or avoided for now?
- How much detail should strength workouts support?

## Status

Planning only. No fitness model, persistence, or UI exists yet.
