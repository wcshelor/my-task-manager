# Personal Task Manager App — v0.1 Product Report

## Purpose

This app is a personal task-planning system for iPhone centered around one main idea:

**Tasks represent things that could be done, calendar events represent time that is already committed, and the planner suggests how to use remaining free time.**

The app is not meant to replace Apple Calendar. Instead, Apple Calendar should function as the **primary source of truth for time**, while this app manages the user's **intentions, tasks, projects, and planning suggestions**.

The app should feel like a collaborative planning assistant rather than an authoritarian scheduler. It should propose useful blocks of work, allow quick rejection/regeneration, and integrate smoothly with the user's real calendar.

---

## Core Product Vision

Version 0.1 should deliver a working personal planning tool with five main object types:

1. **Project**
2. **Task**
3. **Work-Mode Template**
4. **Event**
5. **Scheduled Block**

These objects work together as follows:

- **Projects** group related work.
- **Tasks** represent concrete actionable items.
- **Work-Mode Templates** represent vague, reusable, schedulable forms of work such as “Work on BERThoven” or “Piano practice.”
- **Events** represent fixed calendar commitments, primarily imported from Apple Calendar.
- **Scheduled Blocks** represent a task or work-mode placed into a specific time slot.

The planner should read the calendar, identify free gaps, and suggest how to fill those gaps using tasks and/or work modes.

---

## Guiding Product Principles

### 1. Calendar owns time, task manager owns intention

Apple Calendar should be treated as the authoritative time layer. The task manager should not attempt to replace it.

### 2. Suggestions, not control

The system should recommend schedules rather than force them. The user should be able to reject and regenerate suggestions easily.

### 3. Clear separation of object types

A task is not the same thing as a project, and a task is not the same thing as a scheduled calendar block. This distinction is essential to avoid architectural confusion later.

### 4. Start simple, but structure for growth

v0.1 should focus on strong core functionality rather than advanced intelligence. However, the data model should be designed so future scheduling sophistication can be added without needing a total rewrite.

### 5. Calendar integration must be stable from the start

Because the app depends on Apple Calendar, compliance, permissions, reliability, and smooth syncing behavior are central concerns from the very beginning.

---

## Current State

This repository is currently a **domain and planning prototype**, not yet a finished product application.

It already contains meaningful core logic, and the active unit suite plus the core smoke check are currently passing. But it should still be understood as a backend/prototype codebase rather than a user-ready app.

### What exists today

- Active Python modules in `src/` define the current v0.1 object model and planner-related logic.
- The repo has working coverage for model serialization, gap detection, planner candidate selection, calendar record parsing, and compatibility surfaces.
- Local JSON-backed persistence exists for tasks, events, and preferences.
- There is a macOS-oriented Apple Calendar prototyping surface in the repo today, suitable for experimentation and testing.
- Manual exploration is currently service-level: tests, smoke checks, scripts, and REPL-style inspection.

### What does not exist yet

- There is currently **no active non-legacy GUI or app entrypoint** in the repository.
- There is not yet a finished end-to-end user flow for:
  - entering tasks and work modes
  - seeing planner suggestions in a real UI
  - accepting or rejecting suggestions
  - writing accepted suggestions back into Apple Calendar through a production-grade sync layer
- The current Apple Calendar connection is still a prototype surface, not a final reliability-grade integration.
- The repo is not yet a shippable iPhone product.

### What is left to do to reach the desired product

1. **Build a basic real UI/app shell**
   - task list and task editor
   - work-mode list/editor
   - planner screen
   - suggestion accept/reject/regenerate flow
   - settings, permissions, and calendar-selection screens

2. **Finish the full data/application layer**
   - clean CRUD flows for all five core object types
   - persistence and migrations/versioning
   - clear repository/service boundaries instead of scattered prototype helpers

3. **Complete the planner loop end-to-end**
   - import calendar events
   - detect free gaps
   - rank candidate suggestions
   - accept a suggestion
   - create/update scheduled blocks and calendar events consistently

4. **Deliver a reliability-grade Apple Calendar integration**
   - permission handling
   - calendar selection
   - read/write/update/delete support
   - recurring events
   - timezone and DST correctness
   - external identifier mapping
   - reconciliation after direct edits/deletes in Calendar

5. **Choose and build the real shipping client**
   - If the target remains iPhone, the final product will likely require a native Apple client layer rather than this Python repo alone.
   - In that framing, this repository is best treated as the prototype/specification layer for the planner, data model, and scheduling behavior.

6. **Add stronger product-level testing**
   - sync/integration tests
   - permission-state tests
   - recurring-event and timezone edge cases
   - manual test matrices against real Apple Calendar accounts

In short: the repo is now in a solid **prototype and core-logic** state, but the major remaining work is the **user-facing app shell**, the **end-to-end planner workflow**, and a **production-grade Apple Calendar integration**.

---

## Object Model

## 1. Project

A **Project** is a larger category or area of work/life that can contain tasks and work modes.

Examples:
- BERThoven
- German
- Health
- Choir
- Life Admin

Projects provide organization and context. Tasks may belong to a project, but they do not have to.

### Recommended v0.1 fields for Project
- `id`
- `name`
- `description` (optional)
- `color` (optional)
- `isActive`

### v0.1 behavior
- A project can contain multiple tasks.
- A project can contain multiple work-mode templates.
- A task may belong to one project or to no project.
- A project can be marked active/inactive.

---

## 2. Task

A **Task** is a concrete actionable item with a reasonably clear completion condition.

Examples:
- Email Fabian
- Buy dish soap
- Finish BERThoven README
- Call Bürgeramt
- Clean desk

Tasks are the core actionable units in the system.

### Recommended v0.1 fields for Task

#### Identity and content
- `id`
- `title`
- `description` (optional)

#### Classification
- `status`
  - inbox
  - active
  - done
  - archived
- `projectId` (optional)
- `parentTaskId` (optional, for subtasks)

#### Planning-related fields
- `dueDate` (optional)
- `priorityLevel`
- `energyLevel`
- `estimatedMinutes`
- `minBlockMinutes`
- `isSplittable`

#### Recurrence and tagging
- `isRecurring`
- `recurrenceRule` (optional)
- `tags` (optional list)

### Core v0.1 task traits that matter most

The most important traits for v0.1 are:

- **title**
- **description**
- **due date**
- **priority level**
- **energy level**
- **estimated duration**
- **minimum useful block length**
- **project membership**
- **subtask relationship**
- **recurrence**
- **tags**
- **status**

These traits are not all equally important to the planner, but they give the app enough structure to make meaningful scheduling suggestions.

### Notes on task design

A task should remain distinct from the time block where it is scheduled. One task may be scheduled multiple times across different blocks if it is splittable or rescheduled.

Subtasks should be allowed in v0.1, but only through a simple parent-child structure:
- Task
  - Subtask

No deep unlimited nesting is necessary in the first version.

---

## 3. Work-Mode Template

A **Work-Mode Template** represents vague, reusable, schedulable work that deserves calendar time even when there is no specific concrete task attached.

Examples:
- Work on BERThoven
- Piano practice
- German review
- Inbox cleanup
- Admin catch-up

This object exists because many important activities are not single concrete tasks. The planner must still be able to schedule them intelligently.

### Recommended v0.1 fields for Work-Mode Template
- `id`
- `title`
- `description` (optional)
- `projectId` (optional)
- `defaultEstimatedMinutes`
- `minBlockMinutes`
- `priorityLevel`
- `energyLevel`
- `tags` (optional list)
- `isActive`

### v0.1 behavior
- Work modes can be considered by the planner alongside tasks.
- They can be scheduled into free gaps just like tasks.
- They do not necessarily have a “done” state in the same sense as a concrete task.
- They provide the system a way to recommend meaningful work even when no specific task has been entered.

---

## 4. Event

An **Event** is a fixed calendar item, primarily imported from Apple Calendar.

Examples:
- Lecture
- Doctor appointment
- Choir rehearsal
- Dinner
- Travel

Events represent constraints on the planner. They occupy time that the planner must work around.

### Recommended v0.1 fields for Event
- `id`
- `title`
- `startTime`
- `endTime`
- `source`
- `calendarEventId`

### v0.1 behavior
- Events are read from Apple Calendar.
- Events are treated as fixed commitments.
- Free gaps are calculated between these events.
- The app may later distinguish between imported events and app-created blocks, but in v0.1 the important point is that imported calendar items constrain available time.

---

## 5. Scheduled Block

A **Scheduled Block** is a specific reservation of time for a task or work-mode template.

Examples:
- Tuesday 14:00–15:00: Work on BERThoven
- Thursday 09:30–10:00: Call Bürgeramt
- Saturday 11:00–12:00: Piano practice

A scheduled block is not the same as the task itself. It is the time-specific instance.

### Recommended v0.1 fields for Scheduled Block
- `id`
- `startTime`
- `endTime`
- `sourceType`
  - task
  - workMode
- `taskId` (optional)
- `workModeId` (optional)
- `calendarEventId` (optional)
- `creationMethod`
  - manual
  - suggested
  - acceptedSuggestion

### v0.1 behavior
- A scheduled block links a task or work mode to a time range.
- It may optionally be written back into Apple Calendar.
- Removing a scheduled block should not automatically delete the underlying task.
- The planner should produce scheduled block suggestions rather than directly mutating core task data.

---

## Relationship Between the Object Types

The full model can be described like this:

- A **Project** contains related **Tasks** and **Work-Mode Templates**.
- A **Task** may optionally belong to a **Project** and may optionally be a subtask of another **Task**.
- A **Work-Mode Template** may optionally belong to a **Project**.
- An **Event** comes from the calendar and blocks off time.
- A **Scheduled Block** places a **Task** or **Work-Mode Template** into time.

This separation is one of the most important architectural decisions in v0.1.

---

## Core v0.1 Functionality

## 1. Task storage and management

The app must let the user:
- create tasks
- edit tasks
- mark tasks done
- archive tasks
- attach optional traits/tags
- optionally assign tasks to projects
- optionally create subtasks
- optionally define recurrence

This is the foundational data layer of the app.

### Minimum task entry UI should support
- title
- description
- due date
- priority
- energy
- estimated duration
- minimum useful duration
- project
- tags
- recurring or not
- splittable or not

Some of these can be optional in the UI, but the app should support them internally.

---

## 2. Project storage and management

The app must let the user:
- create projects
- edit project names and descriptions
- assign tasks to projects
- browse tasks by project

Projects should act as organizational anchors rather than complicated entities in v0.1.

---

## 3. Work-mode template management

The app must let the user:
- create work modes
- assign them to projects if relevant
- define their default duration and minimum useful block
- define energy and priority traits

These are critical because many valuable suggestions will involve “work on project X” rather than only narrow concrete tasks.

---

## 4. Apple Calendar sync and event ingestion

This is a major pillar of v0.1.

The app must:
- request the correct Apple Calendar permissions
- read calendar events reliably
- display or interpret upcoming events
- identify free gaps between events
- treat Apple Calendar as the source of truth for committed time

### Important implementation priorities
- Use Apple-approved APIs and patterns correctly
- Respect user privacy and permission constraints
- Handle denied/revoked permissions gracefully
- Avoid duplicate event import behavior
- Ensure timezone handling is correct
- Ensure calendar reads are stable and predictable
- Ensure app-created scheduled blocks can coexist smoothly with existing Apple Calendar content

### Product requirement
Calendar integration is not a “nice extra.” It is a core dependency of the product. Therefore, v0.1 must prioritize smooth functioning with Apple Calendar from the beginning.

---

## 5. Gap detection

The system must be able to:
- inspect the user’s calendar
- find free time intervals between events
- represent those intervals in a way the planner can use

This is the bridge between the fixed calendar and the task suggestion system.

### v0.1 expectation
The user should be able to look at their calendar and identify a gap, or tap/select a gap, and ask the app for a suggestion.

---

## 6. Planner / suggestion engine

The planner is the core intelligence layer of the app.

Its role in v0.1 is not to build a perfect life plan. Its role is:

**Given a free time gap, propose a plausible use of that time based on the available tasks, work modes, and their traits.**

### Inputs to the planner
- selected free time gap
- active tasks
- active work modes
- due dates
- priority levels
- energy levels
- estimated durations
- minimum useful block sizes
- project relationships
- splittability

### Basic planner behavior in v0.1
The planner should:
1. Look at the selected gap
2. Filter out tasks/work modes that do not fit
3. Score remaining options
4. Return one or more suggestions

### Examples of planner reasoning
For a 3-hour gap, the planner may consider:
- one large BERThoven work block
- several menial tasks followed by one deep-work block
- one urgent concrete task due soon
- one reusable work mode such as “Admin cleanup”

### Important v0.1 constraint
The planner must be steady, interpretable, and debuggable. It does not need machine learning.

---

## Suggested planner scoring dimensions for v0.1

The planner should likely consider at least:

- **Urgency**  
  Is the due date close?

- **Priority**  
  Is the task marked as important?

- **Fit to gap**  
  Does it fit well into the available time?

- **Minimum useful duration**  
  Is the gap long enough for this to be worthwhile?

- **Energy match**  
  Does the task’s energy requirement fit the situation?  
  Even if contextual energy modeling is primitive in v0.1, the field should already exist.

- **Project relevance**  
  Does this belong to an active ongoing project?

- **Splittability**  
  Can this task be placed into a partial block?

### v0.1 recommendation
The planner should use explicit scoring rules rather than opaque “AI magic.” This will make it much easier to refine behavior later.

---

## 7. Reject and regenerate workflow

This is a central UX principle.

The user should be able to:
- receive a suggestion
- reject it quickly
- request another suggestion

The app should feel collaborative, not bossy.

### Why this matters
Even a decent planner will often produce suggestions that are technically reasonable but not what the user wants in that moment. A low-friction regeneration flow is therefore essential.

### v0.1 behavior
At minimum:
- show one main suggestion
- provide one or more alternatives
- allow the user to reject and request another proposal

---

## 8. Creating scheduled blocks from suggestions

Once the user accepts a suggestion, the app should be able to convert it into a **Scheduled Block**.

Ideally in v0.1:
- the block is stored internally
- and, if feasible and stable, it is also written into Apple Calendar

This must be done carefully to avoid confusion with normal calendar events.

### Important note
If writing into Apple Calendar is included in v0.1, it must be handled very cleanly. A sloppy sync experience would damage trust in the app immediately.

---

## What a Completed v0.1 Looks Like

A completed v0.1 should feel like this:

### The user can:
- create projects
- create tasks with meaningful planning traits
- create reusable work-mode templates
- connect the app to Apple Calendar
- read events from the calendar
- identify free time gaps
- tap/select a gap
- ask the planner for a suggestion
- receive a reasonable recommendation based on tasks and work modes
- reject/regenerate suggestions
- accept a suggestion and turn it into a scheduled block

### The app should already feel coherent in these ways
- clear distinction between projects, tasks, events, and time blocks
- Apple Calendar functioning reliably as the real time layer
- tasks rich enough to support intelligent suggestions
- work modes available for vague but important work
- scheduling framed as assistance rather than enforcement

### A good v0.1 does **not** need:
- real reinforcement learning
- full-day autopilot scheduling
- heavy analytics
- complex habit prediction
- advanced natural language parsing
- deeply nested project/task systems

It needs to be simple, stable, and clearly structured.

---

## Things Explicitly Out of Scope for v0.1

To keep the first version realistic, the following should be treated as future features unless they come nearly for free:

- reinforcement learning or adaptive personalization
- fully automatic day planning
- long-term learning of user preferences
- advanced recurrence logic beyond practical basics
- highly complex subtask trees
- cross-device collaboration
- elaborate productivity statistics
- AI-generated task descriptions
- advanced context-awareness such as location-based scheduling
- highly dynamic reprioritization based on behavioral history

These ideas are valuable, but not necessary for the first meaningful version.

---

## Key Technical and Product Risks

## 1. Calendar integration complexity
Apple Calendar integration is central and must be stable. Permissions, event fetching, event writing, timezone handling, and user trust all matter.

## 2. Overcomplicating the data model
It is tempting to attach dozens of fields and edge cases to tasks. v0.1 should keep only the traits that materially help the planner.

## 3. Planner over-ambition
A weak but understandable planner is better than an over-clever brittle one.

## 4. UX confusion between tasks and scheduled blocks
The app must keep clear what is:
- an unscheduled task
- a fixed calendar event
- an accepted planned block

## 5. Excessive automation
The app should not feel like it is taking over the user’s life. The suggestion/regeneration model is important for keeping the tool pleasant and trustworthy.

---

## Suggested v0.1 User Experience Flow

A likely good first user flow:

1. User creates projects such as BERThoven, German, Health.
2. User creates concrete tasks and optional subtasks.
3. User creates reusable work modes such as “Work on BERThoven.”
4. User grants Apple Calendar access.
5. App reads calendar events and detects free gaps.
6. User taps a gap.
7. App proposes one or more suggestions.
8. User accepts one or rejects/regenerates.
9. Accepted suggestion becomes a scheduled block.
10. Scheduled block is stored internally and optionally reflected in Apple Calendar.

This is already a powerful and focused product loop.

---

## Next Versions: Suggested Roadmap

## v0.2
Focus: stronger planning composition

Possible additions:
- better multi-task composition for long gaps
- cleaner handling of breaks
- better prioritization among urgent small tasks vs deep work
- better alternative generation
- better calendar writing/editing flows

## v0.3
Focus: smarter task structure and scheduling flexibility

Possible additions:
- stronger recurring-task support
- richer subtask workflows
- progress tracking on split tasks
- better handling of rolling project tasks
- manually pinning or protecting suggested blocks

## v0.4
Focus: user preference adaptation

Possible additions:
- basic personalization from accept/reject history
- remembering preferred block lengths by project or task type
- time-of-day preferences
- recurring suggestion patterns

This does not need full reinforcement learning yet. Simple preference adjustment based on user behavior may be enough.

## Later versions
Possible additions:
- full-day or full-week scheduling suggestions
- more advanced learning systems
- natural language task entry
- stronger analytics and review systems
- smart batching of similar tasks
- proactive but non-intrusive suggestions

---

## Final Summary

Version 0.1 should establish the app’s architecture and trustworthiness.

The most important decisions already made are:

- Apple Calendar is the source of truth for time
- the app should be suggestion-based, not controlling
- projects, tasks, work modes, events, and scheduled blocks are distinct objects
- task traits must be rich enough to support planning but not so rich that the model becomes bloated
- v0.1 should focus on stability, clarity, and a strong core loop rather than advanced intelligence

If built well, v0.1 will already provide something genuinely valuable:

**a personal planning assistant that understands tasks, respects the real calendar, and helps fill open time with plausible, useful work.**
