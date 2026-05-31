# Debriefs

## What Debriefs Are

A Debrief is a lightweight reflection attached to a calendar event that already happened.

Debriefs exist to help the user:

- synthesize what happened
- keep a record they can revisit
- capture follow-ups, ideas, promises, and reminders before they disappear
- close the loop instead of letting events vanish

User-facing language is **Debrief**.

## Calendar Relationship

Debriefs are primarily driven by external EventKit calendar events.

- EventKit is used to read ended events that may need a Debrief.
- Debriefs do not write events back to Apple Calendar.
- Debriefs are app-owned SwiftData records.

This keeps calendar integration read-oriented while preserving app-owned reflection data.

## Core Loop

Calendar event -> lived experience -> Debrief -> captures/notes/follow-ups -> trend-ready data.

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

## Templates In MVP

### Work Block

Essential questions:

- Did you do what you planned?
- How productive did it feel?
- What happened?

Optional detail includes blockers, block length fit, energy/focus ratings, and next step.

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
