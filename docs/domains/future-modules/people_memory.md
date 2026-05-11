# People Memory Domain

## Purpose

People Memory helps the user remember names, faces, contexts, and useful details about people they meet.

This should feel like a private memory aid, not a professional CRM. The core job is to make it easy to capture a person quickly, find them later, and optionally study names so they stick.

## Product Shape

The first version should support:

- quick person capture
- searchable people list
- reusable tags
- memorable detail notes
- where / when met
- lightweight study mode
- future export for Anki or CSV

The system should help the user distinguish people without requiring an awkward amount of data entry.

## Possible Objects

- `PersonMemory`
- `PersonTag`
- `PersonMeetingContext`
- `PeopleStudyCard`
- `PeopleStudySession`

Start with `PersonMemory` and reusable `PersonTag`.

## Possible Person Fields

A `PersonMemory` might include:

- name
- pronunciation note
- where met
- when met
- context, such as class, party, event, work, neighborhood, mutual friend, or travel
- memorable detail
- notes
- tags
- review priority
- last reviewed date
- created date
- updated date

Avoid making photos required in the first pass. Photos may be useful later, but they raise privacy and storage questions.

## Tag System

Tags should be reusable first-class objects, not just loose text.

The add-person screen should support:

- common tag chips
- recent tag chips
- relevant tag suggestions
- tag search
- create-new-tag flow
- selected / unselected visual state

The tag list should not show every tag by default. It should prioritize the most common, recent, or contextually relevant tags, with search for the full set.

Starter tags could include:

- hair color: black hair, brown hair, blond hair, red hair, gray hair
- height / build: tall, short
- context: class, party, work, gym, cafe, concert, neighborhood
- relationship: mutual friend, acquaintance, colleague
- memory hooks: glasses, beard, accent, musician, programmer

Starter tags should be editable or removable later. They are a convenience, not a fixed taxonomy.

## Study Mode

Study should be lightweight at first.

Possible quiz modes:

- show context/details, recall name
- show name, recall where met
- quiz by tag or meeting context
- review people not reviewed recently

Anki export can come later. A simple CSV export with name, context, details, and tags may be enough for a first export path.

## Interaction With Today / Tasks / Planner

Today can eventually surface light review prompts if the user wants them, such as "review 5 names."

People Memory may create tasks, for example:

- follow up with someone
- send a message
- remember to ask about a detail

People Memory should not write directly to Apple Calendar. If a social follow-up needs time, it should become a task or scheduled block through the Planner.

## Interaction With Journaling

Journal entries may link to people. This should make it easier to find entries involving a person without turning People Memory into a full relationship tracker.

## Implementation Sketch

```text
Models/
  PeopleMemoryModels.swift

Persistence/
  SwiftDataModels/
    PersonMemoryRecord.swift
    PersonTagRecord.swift
  Repositories/
    PeopleMemoryRepository.swift
  SwiftDataRepositories/
    SwiftDataPeopleMemoryRepository.swift

Features/PeopleMemory/
  People list
  Add / edit person
  Tag picker
  Study mode
  Export
```

Keep tag ranking and study-card selection outside SwiftUI so they can be tested.

## Design Principles

- Make capture fast enough to use immediately after meeting someone.
- Make tags useful without overwhelming the add screen.
- Keep the tone private and practical.
- Avoid overbuilding social-network or CRM behavior.
- Treat study mode as optional memory support.

## Open Questions

- Should photos be supported later?
- Should people be linkable to Apple Contacts, or stay app-owned only?
- Should location be structured or just part of meeting context text?
- What is the minimum Anki export format worth supporting?

## Status

Planning only. No People Memory model, persistence, or UI exists yet.
