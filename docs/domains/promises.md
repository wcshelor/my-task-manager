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

## Interaction With Home / Planner

Home surfaces active promises, due check-ins, and simple kept/missed history. Tasks and Planner show compact active-promise presence.

Promises should not write directly to Apple Calendar. Future scheduled promise support should flow through Planner / ScheduledBlock if it is ever needed.

## Promise Breaking / Renegotiation Flow

Breaking a promise should be possible, but it should not be a single careless tap.

The app should add friction before the promise is marked missed or renegotiated. The goal is honest reflection and recovery, not punishment.

Possible prompts:

- What promise are you about to break?
- What changed since you made it?
- What excuse or friction is showing up?
- Is there a smaller version you can still keep?
- Do you want to delay this decision briefly?
- What should future-you remember about this moment?

Possible future outcomes:

- kept
- missed
- renegotiated
- deferred
- reset promise created

This flow should be especially important when other domains would conflict with an active promise. For example, a Vices Tracking log that would break a smoking limit should route through this flow before the event is logged.

## Status

Implemented in Swift with app-owned SwiftData persistence, in-app check-ins, kept/missed history, and reset-promise support.

Promise breaking / renegotiation friction is planning only and is not implemented yet.
