# Promises Domain

## Purpose

Promises help the user make a clear commitment to themselves, keep it present while using the app, and check in honestly without turning the app into a shame system.

## Current Objects

- `Promise`
- `PromiseStatus`
- `PromiseOutcome`

Current fields include:

- title
- notes
- start time
- check-in time
- why it matters
- expected friction or excuse
- kept/missed outcome
- reflection
- optional parent promise for reset promises

## Interaction With Today / Planner

Today surfaces active promises, due check-ins, and simple kept/missed history. Tasks and Calendar show compact active-promise presence.

Promises should not write directly to Apple Calendar. Future scheduled promise support should flow through Planner / ScheduledBlock if it is ever needed.

## Status

Implemented in Swift with app-owned SwiftData persistence, in-app check-ins, kept/missed history, and reset-promise support.
