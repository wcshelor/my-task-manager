# Journaling & Reflection Domain

## Purpose

Journaling & Reflection gives the user a place to write through the day, vent, log events, think through emotional issues, and create follow-up actions when useful.

The app should provide minimal hard-coded guidance without pretending to be a therapist. The main value is structured personal recall, emotional decompression, and thoughtful recovery.

This replaces the narrower Reflection / anti-spiral sketch.

## Product Shape

The first version should support:

- freeform journal entries
- guided prompt modes
- tags
- search
- entry types
- optional mood / energy fields
- links to tasks, promises, people, Health, or vices
- optional follow-up action capture

The system should make entries easy to find again by date, tag, person, theme, and text search.

## Possible Entry Types

- daily dump
- event log
- vent
- emotional issue walkthrough
- anti-spiral reflection
- decision reflection
- gratitude / positive log
- follow-up review

Entry types should provide optional structure, not force the user into a rigid workflow.

## Possible Objects

- `JournalEntry`
- `JournalPromptTemplate`
- `JournalTag`
- `JournalLinkedItem`
- `JournalFollowUpAction`

Start with `JournalEntry` and tags. Prompt templates can be hard-coded before they become user-editable.

## Possible Entry Fields

A `JournalEntry` might include:

- date
- entry type
- title
- freeform body
- guided answers
- tags
- mood
- energy
- related people
- linked task
- linked promise
- linked Health context
- linked vice log
- follow-up action
- important-later marker
- created date
- updated date

## Minimal Guided Flows

### Daily Dump

- What happened today?
- What felt important?
- What do I want to remember?
- Is there anything I need to do next?

### Vent

- What am I upset about?
- What am I feeling?
- What do I want to say without filtering?
- What would help me calm down or move forward?

### Emotional Issue

- What happened?
- What am I feeling?
- What story am I telling myself?
- What facts do I actually know?
- Is there a kinder or more realistic interpretation?
- What is one small useful action?
- What can wait?

### Decision Reflection

- What decision am I considering?
- What are the real options?
- What am I optimizing for?
- What is the cost of waiting?
- What is the smallest reversible next step?

## Retrieval / Organization

The module should support finding entries by:

- full-text search
- date
- entry type
- tag
- person
- linked task or promise
- mood / energy
- important-later marker

This does not need advanced semantic search at first. Good structured filters plus text search are enough for an MVP.

## Interaction With Other Domains

Journaling may produce a small useful action that becomes a task.

Journal entries may link to:

- People Memory records
- Promises
- Vices logs
- Health check-ins
- Tasks
- Planner blocks

Journaling should not write directly to Apple Calendar. If reflection produces something scheduled, it should flow through Tasks or Planner.

## Implementation Sketch

```text
Models/
  JournalingReflectionModels.swift

Persistence/
  SwiftDataModels/
    JournalEntryRecord.swift
    JournalTagRecord.swift
  Repositories/
    JournalingReflectionRepository.swift
  SwiftDataRepositories/
    SwiftDataJournalingReflectionRepository.swift

Features/JournalingReflection/
  Entry list
  New entry
  Guided flows
  Search / filters
  Follow-up action capture
```

Keep prompt flow definitions and follow-up extraction outside SwiftUI views.

## Design Principles

- Freeform writing should always be available.
- Guidance should be minimal and optional.
- Avoid medical or therapeutic claims.
- Make retrieval a first-class part of the feature.
- Let entries create tasks or links without turning journaling into task management.

## Open Questions

- Should prompt templates be user-editable?
- Should entries support markdown?
- Should mood / energy be required, optional, or hidden by default?
- Should People Memory links be available in the first version?

## Status

Planning only. No Journaling & Reflection model, persistence, or UI exists yet.
