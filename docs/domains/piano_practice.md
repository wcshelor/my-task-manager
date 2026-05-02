# Piano Practice Domain

## Purpose

Help the user practice piano deliberately, track progress, and choose a useful session based on available time and energy. This should stay lightweight and personal rather than becoming a full music-learning platform.

## Likely Objects

- `PieceGoal`
- `PracticeSkill`
- `PracticeSession`

Possible `PieceGoal` fields:

- title
- composer
- status
- priority
- difficulty estimate
- notes
- target sections

Possible `PracticeSkill` fields:

- name
- category
- priority
- notes

Possible `PracticeSession` fields:

- date
- duration
- pieces practiced
- skills practiced
- notes
- what improved
- what needs work
- next step

## Practice Mode

A simple practice mode could ask for available time and energy, then suggest a session structure:

- warmup or technique
- active piece work
- targeted problem section
- review or play-through
- quick log

## Interaction With Tasks / Planner

Practice goals may create tasks. Practice sessions should be app-owned durable data. Scheduled practice time should go through the planner / scheduled-block system.

## Status

Scaffold only. No practice logging or practice mode exists yet.
