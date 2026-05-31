# Vices Tracking Domain

## Purpose

Vices Tracking helps the user become more mindful about habits they want to reduce, delay, understand, or renegotiate.

This should not be a generic shame counter. The useful behavior is a pause before acting, a clear log of what happened, and enough pattern data to understand triggers over time.

The first concrete use case is smoking, but the domain should allow the user to define additional vices or habits they want to cut back on.

## Product Shape

The user should be able to create custom vices, similar to creating routines. Each vice can define its own tracking traits and friction rules.

Examples:

- smoking
- alcohol
- impulsive spending
- social media
- late-night snacking
- avoidance scrolling

For each vice, the app should support:

- a pre-action check-in
- a logged event
- optional goals or limits
- optional delay prompts
- optional reflection after the event
- pattern review over time

## Possible Vice Traits

A user-defined vice could include:

- name
- icon or color
- unit of measurement, such as joint, drink, cigarette, session, purchase, or custom text
- goal type, such as daily limit, weekly limit, time window, abstinence, or mindful-use only
- trigger categories
- default reflection prompts
- delay duration before logging
- severity or concern level
- whether the app should require a pre-log before the event

## Possible Log Fields

A `ViceLog` might include:

- vice id
- timestamp
- amount or unit count
- context
- trigger
- craving level
- mood before
- intention or reason
- whether this aligns with the current goal
- whether a delay was attempted
- notes
- optional follow-up reflection

For smoking specifically, the flow should support logging before smoking and declaring the intention before the event.

## Interaction With Promises

Vices Tracking should connect strongly to Promises when a vice has an active commitment.

Examples:

- "No smoking before 6pm"
- "No more than two drinks tonight"
- "No social media before finishing morning routine"
- "Wait 48 hours before luxury purchases"

If a log would break an active promise, the app should route through the Promise breaking / renegotiation flow rather than simply recording the event.

## Interaction With Home / Planner

Home can show:

- active vice goals
- current count against daily or weekly limits
- next check-in
- a quick pre-log button for the most relevant vice

Planner should not write vice events to Apple Calendar. If a reduction goal needs scheduled support, it should create tasks, reminders, routines, or planned recovery blocks through existing app-owned flows.

## Implementation Sketch

```text
Models/
  ViceModels.swift
  ViceLogModels.swift

Persistence/
  SwiftDataModels/
    ViceRecord.swift
    ViceLogRecord.swift
  Repositories/
    ViceRepository.swift
  SwiftDataRepositories/
    SwiftDataViceRepository.swift

Features/Vices/
  Vice list
  Vice creation / editing
  Pre-action log flow
  Pattern review
```

Start with one durable custom vice model and one event log model. Avoid building a full analytics system in the first pass.

## Design Principles

- Track honestly without moralizing.
- Add friction before the action, not punishment after it.
- Prefer recovery and renegotiation over streak obsession.
- Make logging fast enough that the user will actually do it.
- Let the user customize vices because different habits need different prompts.

## Open Questions

- Should vices live under a broader `Life Logs` screen or have their own tab/surface?
- How much friction should be configurable per vice?
- Should goals be strict limits, soft intentions, or both?
- Should some vices support money amounts, such as impulsive spending?

## Status

Planning only. No vices model, persistence, or UI exists yet.
