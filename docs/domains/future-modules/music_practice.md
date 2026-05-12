# Music Practice Domain

## Purpose

Music Practice helps the user practice instruments deliberately, track practice time, manage repertoire or goal pieces, and keep useful notes about what to work on next.

This replaces the narrower Piano Practice concept. Piano can be the first use case, but the domain should support music practice more generally.

The module should feel like a lightweight music task manager and practice log, not a full music-learning platform.

## Product Shape

The first version should support:

- practice session logging
- instruments
- pieces / songs / repertoire goals
- practice routines
- skills / techniques
- notes about what improved and what needs work
- links to routines and tasks

The app should help answer:

- What am I currently practicing?
- How many hours have I practiced?
- What pieces are on my music to-do list?
- What should I work on next?
- Is a practice routine stale or ready to move on from?

## Possible Objects

- `Instrument`
- `MusicPracticeSession`
- `MusicPieceGoal`
- `MusicSkill`
- `MusicPracticeRoutine`
- `PracticeRoutineStep`

Start with practice sessions, piece goals, and routines.

## Possible Piece / Goal Fields

A `MusicPieceGoal` might include:

- title
- composer / artist
- instrument
- status: idea, learning, polishing, maintenance, paused, complete
- priority
- difficulty estimate
- notes
- target sections
- next step
- last practiced date

## Possible Practice Routine Fields

A `MusicPracticeRoutine` might include:

- name
- instrument
- purpose
- estimated duration
- ordered steps
- active / paused status
- notes
- last used date

Practice routines should be user-authored. They can be linked to the broader Routines domain when the user wants them to recur on specific days.

## Possible Session Fields

A `MusicPracticeSession` might include:

- date
- duration
- instrument
- pieces practiced
- skills practiced
- routine used
- notes
- what improved
- what needs work
- next step
- energy or focus level

## Practice Mode

A simple practice mode could ask for available time and energy, then suggest a session structure:

- warmup or technique
- active piece work
- targeted problem section
- review or play-through
- quick log

This should stay rule-based at first. The app can suggest moving on when a routine has been repeated many times, a goal has not changed in a while, or the user repeatedly logs the same next step.

## Interaction With Routines / Tasks / Planner

Routines can remind the user to practice or run a specific practice routine.

Music goals may create tasks, such as:

- work on a specific section
- print or organize sheet music
- record a run-through
- schedule practice time

Scheduled practice time should go through Planner / ScheduledBlock. Music Practice should not write directly to Apple Calendar.

## Implementation Sketch

```text
Models/
  MusicPracticeModels.swift

Persistence/
  SwiftDataModels/
    InstrumentRecord.swift
    MusicPieceGoalRecord.swift
    MusicPracticeRoutineRecord.swift
    MusicPracticeSessionRecord.swift
  Repositories/
    MusicPracticeRepository.swift
  SwiftDataRepositories/
    SwiftDataMusicPracticeRepository.swift

Features/MusicPractice/
  Practice dashboard
  Practice log
  Piece goals
  Practice routines
  Practice mode
```

Keep practice suggestion logic outside SwiftUI.

## Design Principles

- Keep it lightweight and personal.
- Support piano without hard-coding the whole domain around piano.
- Track enough structure to make future practice easier.
- Link to Routines and Tasks without duplicating their behavior.
- Prefer useful logs and next steps over complex music pedagogy.

## Open Questions

- Should instruments be required, or optional until the user has more than one?
- Should practice hours have weekly/monthly goals?
- Should pieces and skills share one "practice target" model, or stay separate?
- What rules should suggest moving on from a routine?

## Status

First foundation implemented in the Swift app:

- `PracticePiece` and `PracticeSession` domain models
- SwiftData records and repository
- `MusicPracticeViewModel`
- simple Home module entry, session logging, piece capture, and recent summary UI
- targeted model, repository, and view model tests

Still incomplete: routines, skills, practice mode, task links, planner integration, and richer repertoire review.
