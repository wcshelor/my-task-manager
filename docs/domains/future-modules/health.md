# Health Domain

## Purpose

Health is the overall app section for tracking sleep quality, vigilance, lightweight workouts, meals, and related daily context.

The goal is not medical-grade health tracking. The goal is personal pattern awareness: understanding how sleep, food, exercise, routines, vices, and the previous night's behavior affect energy, focus, and planning.

Health should remain a cohesive section of the app, with Nutrition and Sleep / PVT as active Health-owned surfaces, while structured Fitness progression now lives in its own standalone module.

## Product Shape

Health should help the user answer practical questions:

- How rested do I seem today?
- Did last night's behavior affect today's focus?
- How have food, workouts, sleep, and vices interacted lately?
- Should today's plan adapt because energy or vigilance is low?
- What patterns are worth changing?

The first Health experience should probably center on a morning check-in, because that is where sleep quality, psychomotor vigilance, energy, and the plan for the day naturally meet.

## Subdomains

### Sleep / PVT

Sleep tracking should include a morning psychomotor vigilance task and a short subjective check-in.

The PVT should become part of the morning routine so the app can compare reaction-time performance with:

- sleep duration
- subjective sleep quality
- bedtime and wake time
- what happened the night before
- food timing or meal quality
- alcohol, cannabis, caffeine, or other vice logs
- workout timing
- mood and energy

### Nutrition

Nutrition should start as lightweight meal logging, not calorie accounting.

Meal logs should help explain energy, sleep, workout performance, spending, and planning patterns.

### Fitness Relationship

Health still keeps the older lightweight generic workout log.

Structured exercise progression, workout days, sets, and exercise-owned history now live in the standalone Fitness module.

Workout logging should remain separate from routines. A routine can remind the user to work out, but the durable workout records live in Health or Fitness depending on which workflow the user used.

## Possible Health Objects

- `PVTSession`
- `SleepCheckIn`
- `HealthDailyCheckIn`
- `MealLog`
- `WorkoutLog`
- `HealthContextTag`

The first implementation does not need one large health model. It can start with dedicated subdomain records that are presented together in the Health section.

## Interaction With Today / Routines

Today can surface Health items when they are relevant to execution:

- morning PVT due
- sleep check-in due
- planned workout
- quick meal log
- low-energy planning nudge

Routines can include Health actions, especially:

- take morning PVT
- log sleep quality
- log breakfast
- complete workout

The Health domain should own the durable records. Routines should only provide recurring prompts or checklist structure.

## Interaction With Planner

Health can inform planning, especially when energy or vigilance is low.

Examples:

- prefer low-energy tasks after poor sleep
- avoid overloading the day after low PVT performance
- suggest recovery time after late nights
- schedule workout blocks through Planner / ScheduledBlock

Health should not write directly to Apple Calendar. Any scheduled workout, recovery block, meal prep block, or sleep-support task should flow through Tasks, Planner, or ScheduledBlock.

## Interaction With Vices / Budgeting / Shopping

Health should be able to correlate with other modules without owning their records.

Examples:

- vice logs can help explain sleep and next-day focus
- meal planning can generate shopping items
- takeout-heavy patterns can inform Budgeting
- late-night spending, smoking, or alcohol can become part of sleep context

## Implementation Sketch

```text
Models/
  HealthModels.swift
  SleepPVTModels.swift
  NutritionModels.swift
Persistence/
  SwiftDataModels/
    PVTSessionRecord.swift
    SleepCheckInRecord.swift
    MealLogRecord.swift
    WorkoutLogRecord.swift
  Repositories/
    HealthRepository.swift
  SwiftDataRepositories/
    SwiftDataHealthRepository.swift

Features/Health/
  Health dashboard
  Morning check-in
  Sleep / PVT
  Nutrition
```

## Current Implementation (Work In Progress)

The app now has a first-pass Health module. Current work-in-progress behavior includes:

- sleep check-ins with duration, quality, energy, and notes,
- completed-session PVT persistence with response metrics,
- a one-minute in-app PVT test flow,
- lightweight meal and workout logs inside Health,
- Health history and delete flows,
- neutral rolling 7/30-day trend summaries for sleep/PVT, nutrition, and workouts.

Still pending:

- manual QA for the real-time PVT tap flow,
- Home and Routine prompts for Health check-ins,
- richer review surfaces,
- planner adaptation based on user-approved Health context.

## Design Principles

- Personal trend tracking, not medical advice.
- Lightweight daily capture over exhaustive data entry.
- Morning routine integration is central.
- Use Health data to adapt planning, not to shame the user.
- Keep subdomain records structured enough for pattern review.

## Open Questions

- Should Health get its own tab, or live under Today until it has enough depth?
- Should the morning PVT be mandatory inside a routine or optional but prominently suggested?
- How much night-before context should be structured versus free-text?
- Should Health summaries be daily, weekly, or both?

## Status

Active work in progress. Sleep / PVT and Nutrition remain Health-owned work in progress. Health also still contains the older generic workout log, while the standalone Fitness module now owns structured exercise progression.
