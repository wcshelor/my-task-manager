# Debriefs

## What Debriefs Are

A Debrief is a lightweight reflection attached to a calendar event that already happened.

Debriefs exist to help the user:

- synthesize what happened
- keep a record they can revisit
- capture follow-ups, ideas, promises, and reminders before they disappear
- close the loop instead of letting events vanish

User-facing language is **Debrief**.

Block Focus is the separate intention layer that may exist before a Debrief. A Block Focus can link a calendar event to a project, suggest tasks, and store the user's intended focus for the block. Debriefs stay distinct from Block Focus: Debrief captures what actually happened after the event.

## Calendar Relationship

Debriefs are primarily driven by external EventKit calendar events.

- EventKit is used to read ended events that may need a Debrief.
- Debriefs do not write events back to Apple Calendar.
- Debriefs are app-owned SwiftData records.
- If a matching Block Focus exists, Debriefs can read its linked project, selected tasks, and intention note for prefilling or task-outcome capture.

This keeps calendar integration read-oriented while preserving app-owned reflection data.

## Core Loop

Calendar event -> lived experience -> Debrief -> captures/notes/follow-ups -> trend-ready data.

For project-linked Work Blocks the loop now also includes selected tasks and task outcomes, so a single Debrief can record what moved, what got blocked, and what should be marked complete.

## Home Relationship

Home surfaces pending Debriefs as a lightweight widget/card.

The Home surface shows:

- pending Debrief count
- up to a few waiting event titles
- a shortcut into the Debrief flow

Full Debrief workflows stay in a sheet/detail flow, not inside the Home widget.

## Capture / Inbox Relationship

Every Debrief includes a visible **Capture from this event** section.

Capture behavior:

- user adds one or more loose capture lines
- captures are written to the existing capture inbox
- captures are not forced into immediate classification

Debrief records store created capture IDs so follow-through can be traced later.

When a Work Block has a Block Focus with selected tasks, Debrief can show small task outcome cards for each selected task. Outcomes are stored in SwiftData so future project history can show completion, partial progress, blockers, and untouched tasks.

## Templates In MVP

### Work Block

Essential questions:

- Did you do what you planned?
- How productive did it feel?
- What happened?

Optional detail includes blockers, block length fit, energy/focus ratings, and next step.

Work Block Debriefs can also include:

- linked project context from Block Focus
- selected tasks from the block
- per-task outcomes such as completed, partly done, still open, blocked, or not touched
- an optional "mark task complete" action when the task was completed during the block

### Meeting

Essential questions:

- What were the main outcomes?
- Any follow-ups?
- How useful was this meeting?

Optional detail includes decisions, open questions, deadlines, preparedness, participants, and next-meeting reminders.

### Social

Essential questions:

- Anything worth remembering?
- Any follow-up?
- How did it feel?

Optional detail includes people, learned context, promises, next-time notes, and nourishing/obligatory feel.

## Queue Eligibility In MVP

Pending Debrief candidates are recent ended events that pass basic filters:

- ended within recent lookback window
- not all-day
- at least minimum duration
- not already Debriefed or marked no-Debrief-needed
- excludes obvious passive/system-like event titles when possible

Template suggestion is title-keyword based and always user-overridable.

## Trend Data Purpose

The model captures structured fields so future trends are possible without rebuilding history.

Examples:

- Work Block follow-through and blocker patterns
- task completion, partial progress, and blocker patterns by project
- Meeting usefulness and follow-up quality
- Social mood/follow-up patterns

MVP does not include a full analytics dashboard yet.

## Light Gamification

Debriefs support a small close-the-loop reward:

- loop closed
- all caught up
- Debriefs completed today

No shame-based scoring is used.

## Scope Notes

- Music Practice Debriefs are out of scope for now. Music Practice remains in its own module.
- Planner auto-generation/suggestion behavior remains available, but it is supporting behavior, not the center of the Debrief workflow.
