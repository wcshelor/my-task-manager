# Calendar Block Focus

## What It Is

Calendar Block Focus is the app-owned intention layer for a calendar event or work block.

It answers:

- which project this block belongs to
- which tasks the user intended to work on
- what the user meant to do during the block
- whether the user explicitly said no focus was needed

User-facing language should stay simple:

- **Focus**
- **Block Focus**
- **Project block**
- **Suggested tasks**

Avoid internal wording like annotation records, inference objects, or metadata.

## Relationship To EventKit

Block Focus is driven by EventKit events but is stored in SwiftData.

- EventKit supplies the event title, dates, and identifiers.
- Block Focus stores a snapshot of the event so it remains useful if the calendar event later changes or disappears.
- Block Focus never writes back to Apple Calendar.

This keeps manual calendar planning intact while adding app-owned context around the event.

## Project Recognition

The app can infer a project from the event title using simple deterministic matching.

Current matching behavior:

- normalize title and project names
- exact match wins
- meaningful phrase containment can match a project
- short generic names should be avoided to reduce false positives
- ambiguous matches should stay unresolved until the user picks one

If a user confirms a project, that choice is persisted for the same event so the app does not keep asking.

## Suggested Tasks

When a project is linked, the app can surface suggested tasks for that block.

Ranking stays simple and deterministic:

- open tasks first
- tasks from the linked project first
- due soon first
- higher priority first
- shorter estimated work that fits the block
- recent updates as a tie-breaker

The user can select zero, one, or multiple tasks.

## Relationship To Debrief

Block Focus is not the Debrief.

- Block Focus is the pre-event intention layer.
- Debrief is the after-event reflection layer.

When a Work Block Debrief exists for a block that has Block Focus, the Debrief can surface the selected tasks again and capture per-task outcomes such as completed, partly done, still open, blocked, or not touched.

## Project Activity

Projects can surface Block Focus activity in compact form:

- upcoming linked blocks
- recent Debriefs linked to the project
- recent task outcomes from those Debriefs

This is meant to be lightweight trend surfacing, not a full project-management dashboard.

## Storage

Block Focus records live in SwiftData.

Expected repository behavior:

- fetch by event identifier and calendar identifier
- create or update a focus record for an event
- set or clear the linked project
- update selected tasks
- update the intention note
- mark no focus needed
- fetch by date range
- fetch by linked project

