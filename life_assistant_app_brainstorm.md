# Life Assistant App Brainstorm

## Core Vision

This app is evolving from a task manager into a personal planning hub: a lightweight secretary for tasks, planning, routines, reminders, and self-regulation.

The guiding idea:

> Help me capture what matters, plan when to do it, execute routines that keep me stable, and understand patterns in my energy, sleep, and productivity.

---

## Product Spine

Every feature should support at least one of these functions:

| Function | Meaning |
|---|---|
| **Capture** | Get obligations, ideas, errands, and admin out of my head quickly |
| **Plan** | Turn tasks into realistic time blocks around my calendar |
| **Execute** | Help me actually do the next thing, especially with routines/checklists |
| **Recover** | Help me reset when I am tired, scattered, behind, or low-energy |
| **Understand patterns** | Show useful trends in sleep, focus, routines, task completion, and lifestyle |

If an idea does not clearly serve one of these, it should be treated cautiously.

---

## Current Major Modules

The app should be modular: each area can start simple, but the architecture should allow new “life domains” to be added over time without turning the whole thing into clutter.

A useful distinction:

| Type | Meaning | Examples |
|---|---|---|
| **Action systems** | Help me decide and do things | Tasks, Planner, Routines, Piano Practice Mode |
| **Tracking systems** | Help me record what happened | Sleep, food, workouts, practice logs, mood |
| **Reflection systems** | Help me think through things | Journaling, anti-spiral mode, weekly reviews |
| **Growth systems** | Help me deliberately improve skills over time | Piano repertoire, gym progression, meditation, language learning |

The app should eventually feel like one coherent system for organizing life, not a pile of separate trackers.

### 1. Tasks

Purpose: capture and organize things I need to do.

Current/desired concepts:

- task title
- notes
- due date
- estimated duration
- priority
- energy level
- work mode
- tags
- subtasks
- separable tasks / minimum chunk size
- completion / archive / scheduled state

### 2. Planner / Calendar

Purpose: turn tasks into actual planned time.

Core idea:

- Apple Calendar provides busy-time input
- app suggests task blocks
- user accepts/rejects suggestions
- accepted suggestions become scheduled blocks and are written to Apple Calendar

Future planner ideas:

- plan next 2 hours
- plan rest of today
- plan tomorrow
- plan next week
- low-energy planning mode
- admin-only planning mode
- errands planning mode
- deep-work planning mode
- multi-task packing into longer free slots
- alternative suggestions after rejection

### 3. Routines

Purpose: support recurring morning/night/custom checklists.

Initial ideas:

- Morning Routine
- Night Routine
- custom routines
- daily checklist completion
- completion progress: e.g. 3/5 done
- gentle streaks
- skip option without punishment
- optional links from routine items to tasks

Possible routine items:

- sunlight
- water
- meditation
- PVT test
- quick room reset
- plan day
- prepare clothes / bag
- brush teeth
- screen-off wind-down
- journaling

### 4. Sleep / PVT Tracker

Purpose: measure sleepiness / vigilance and connect it to planning.

Initial ideas:

- daily psychomotor vigilance test after waking
- reaction time storage
- lapses count
- basic trend visualization
- subjective sleep check-in
- sleep duration
- tiredness rating
- caffeine / alcohol / cannabis context

Future connection to planner:

- if PVT is bad, suggest lower-energy tasks
- if sleep was poor, avoid overloading the day
- if routines were skipped, suggest recovery mode

### 5. Today Dashboard

Purpose: make the app feel like a secretary.

Possible cards:

- today’s scheduled blocks
- urgent tasks
- morning routine status
- night routine reminder
- PVT/check-in status
- top suggested task
- quick brain dump
- “plan my next free slot”
- suggested piano practice session
- suggested recovery / anti-spiral prompt when appropriate

### 6. Piano Practice Mode

Purpose: help me practice piano more deliberately, track growth, and organize musical goals.

This should not become a full music-learning platform. It should be a lightweight personal practice assistant.

Core ideas:

- list of pieces I want to learn
- list of active pieces I am currently practicing
- list of technical skills I want to improve
- practice session logging
- basic practice routine generation
- optional connection to tasks and routines

Possible data objects:

```text
PieceGoal
- id
- title
- composer
- catalog / opus number if relevant
- status: someday / learning / polishing / learned / paused
- priority
- difficulty estimate
- notes
- target sections

PracticeSkill
- id
- name
- category: technique / sight-reading / improvisation / theory / repertoire / memorization
- notes
- priority

PracticeSession
- id
- date
- duration
- piecesPracticed
- skillsPracticed
- notes
- whatImproved
- whatNeedsWork
- nextStep
```

Possible practice mode flow:

1. Choose available time: 15 / 30 / 45 / 60 minutes.
2. Choose energy/focus level.
3. App suggests a basic session:
   - warmup / technique
   - active piece work
   - targeted problem section
   - review / play-through
   - quick log at the end
4. User records what happened.
5. App saves the session and updates piece/skill progress.

Possible practice session templates:

- “Light maintenance practice”
- “Deep work on one hard section”
- “Repertoire review”
- “Technique-focused session”
- “Sight-reading / exploration session”
- “Low-energy musical contact”

How this fits the product spine:

| Function | How Piano Mode supports it |
|---|---|
| **Capture** | Save pieces and skills I want to work on |
| **Plan** | Suggest what to practice based on time/energy/goals |
| **Execute** | Give a simple practice structure |
| **Recover** | Offer low-pressure musical contact when energy is low |
| **Understand patterns** | Track practice frequency, time, repertoire progress, recurring obstacles |

### 7. General Life Logs / Record Keeping

Purpose: let the app track different parts of life in a modular way.

This should be designed carefully. The goal is not to track everything obsessively. The goal is to create useful records that help me notice patterns, stay organized, and support growth.

Potential tracking domains:

- sleep health
- PVT / alertness
- food / meals
- gym workouts
- weights, reps, exercises
- piano practice
- meditation
- mood / emotional state
- cannabis reduction / lifestyle changes
- caffeine / alcohol context
- routines
- general daily notes

Possible generic logging architecture:

```text
LogEntry
- id
- date
- domain: sleep / food / workout / piano / mood / custom
- title
- notes
- tags
- numericMetrics
- linkedTaskId
- linkedRoutineId
```

But for domains with special needs, create dedicated models:

```text
WorkoutSession
- exercises
- sets
- reps
- weights
- perceived effort

MealLog
- meal type
- rough contents
- notes

MoodCheckIn
- mood rating
- energy rating
- stress rating
- notes
```

Design principle:

> Use generic logs for simple notes, but dedicated models for domains that need structured data.

### 8. Gym / Workout Tracking

Purpose: track physical training and progression.

Initial ideas:

- workout session log
- exercise list
- sets / reps / weight
- notes on form or pain
- perceived effort
- simple progress history per exercise
- optional planned workouts

Possible data objects:

```text
Exercise
- id
- name
- category
- notes

WorkoutSession
- id
- date
- duration
- exercises
- notes

WorkoutSet
- exerciseId
- weight
- reps
- perceivedEffort
- notes
```

Keep it simple at first. Do not try to clone a full fitness app. The useful version is:

> “What did I do last time, and what should I try today?”

### 9. Food / Meal Tracking

Purpose: rough record keeping around eating, not obsessive calorie tracking unless intentionally added later.

Possible first version:

- quick meal note
- rough category: breakfast / lunch / dinner / snack / smoothie
- optional protein estimate
- optional notes: stomach comfort, energy afterward, cravings

Potential connection:

- smoothie routine
- gym recovery
- stomach discomfort patterns
- sleep / energy patterns

### 10. Emotional Reflection / Anti-Spiral Journaling

Purpose: help me think clearly when I am emotionally activated, anxious, ashamed, sad, stuck, or spiraling.

This should be a structured journaling mode, not just a blank text box.

Possible anti-spiral prompt flow:

1. What happened?
2. What am I feeling in my body?
3. What story am I telling myself?
4. What are the facts I actually know?
5. What am I afraid this means?
6. Is there a kinder or more realistic interpretation?
7. What is one small useful action?
8. What can wait until tomorrow?

Possible data object:

```text
ReflectionEntry
- id
- date
- mode: antiSpiral / gratitude / review / freeJournal
- promptAnswers
- moodBefore
- moodAfter
- tags
- linkedTaskId
```

Tone principle:

> The app should help me slow down and think, not psychoanalyze me or pretend to be a therapist.

Possible reflection modes:

- Anti-spiral
- Evening review
- Weekly review
- Decision journal
- Gratitude / good things log
- “What am I avoiding?”
- “What actually matters today?”

---

## Modular Architecture Idea

The app could eventually have a shared foundation for different life domains:

```text
LifeDomain
- tasks
- routines
- planner
- sleep
- piano
- workouts
- food
- mood/reflection
```

Each domain can optionally provide:

```text
DomainItem        // something being worked on or tracked
DomainLogEntry    // record of something that happened
DomainGoal        // longer-term aim
DomainSession     // focused execution period
DomainInsight     // pattern or summary
```

Examples:

| Domain | Item | Session / Log | Goal |
|---|---|---|---|
| Piano | Piece / Skill | PracticeSession | Learn piece / improve skill |
| Gym | Exercise | WorkoutSession | Increase strength / consistency |
| Sleep | SleepCheckIn | PVTSession | Improve sleep consistency |
| Food | Meal | MealLog | Better energy / digestion |
| Reflection | Prompt set | ReflectionEntry | Emotional regulation |
| Tasks | Task | ScheduledBlock | Finish project/admin |

This could keep the app extensible without making every feature totally custom from scratch.

---

## Idea Inbox

Add raw ideas here first. Later, sort them into modules.

-

---

## Evaluated Ideas

Use this section for ideas after deciding where they fit.

| Idea | Module | Function | Keep / Later / Reject | Notes |
|---|---|---|---|---|
| Morning and night routines | Routines | Execute / Recover | Keep | Should be a separate tab with light gamification |
| PVT sleep tracker integration | Sleep / PVT | Understand patterns / Plan | Keep, but later | Best after routines and Today dashboard exist |
| Today dashboard | Today | Plan / Execute / Recover | Keep | This may become the main home screen |

---

## Design Principles

- Keep it personal-use first.
- Optimize for actual daily use over looking impressive.
- Avoid feature sprawl.
- Do not turn the app into a guilt machine.
- Prefer gentle nudges, checklists, and recovery paths.
- Keep Apple Calendar as the external calendar source of truth.
- Keep tasks, routines, check-ins, and scheduled blocks as app-owned data.
- Build rule-based assistant behavior before trying heavy AI integration.

---

## Open Questions

- Should “Today” become the first/default tab?
- Should Sleep/PVT be its own tab or live inside Today/Routines?
- How much gamification is motivating versus annoying?
- Should routines generate tasks, or should they stay separate checklist objects?
- Should routine items be schedulable into Apple Calendar?
- How should low-energy mode affect planner suggestions?
- What should sync first: tasks only, or tasks + routines + check-ins?

---

## Next Concrete Build Candidate

First sensible expansion:

> Add a first-pass Routines feature as a separate tab, with Routine, RoutineItem, and RoutineCompletion models, simple SwiftData persistence, and a daily checklist UI.

Do **not** integrate PVT or heavy gamification yet.

