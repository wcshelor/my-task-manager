# Task Evolution Domain

## Purpose

Tasks should keep fast capture as the default while supporting more detailed planning when a task becomes real work.

This domain is an evolution of the existing task system, not a separate feature area. The goal is to support larger obligations, recurring responsibilities, subtasks, and task sequences without making every new task feel heavy.

## Product Shape

The task system should support two modes:

- quick capture for getting something out of the user's head
- expanded detail for tasks that need structure, planning, or follow-through

Detailed task creation should stay optional. The default path should remain title-first with lightweight metadata available when needed.

## Current Implemented Foundation

The app already has a lightweight project and capture foundation:

- `Project`
- `ProjectTaskSummary`
- `ProjectItem`
- `CaptureItem`
- SwiftData repositories and records for projects, captures, and project items
- a top-level Projects tab
- Home widgets for pinned projects and project next task
- inbox review that can convert captures to tasks, project items, or shopping items

This is not a full task-evolution system yet.

## Possible Future Capabilities

- recurring tasks for obligations that regenerate on a schedule
- richer task groups or project behavior for larger areas of work
- subtasks for concrete checklists under a larger task
- prerequisites for tasks that cannot be started until other tasks are done
- sequences for work that naturally happens step by step

## Suggested Model Direction

Current tasks already include:

- title
- notes
- status
- estimated minutes
- due date
- priority
- energy level
- work mode
- loose task group
- optional project link
- tags

Possible future objects:

- richer `TaskProject` / `TaskGroup` behavior if the current lightweight `Project` model is not enough
- `Subtask`
- `TaskRecurrenceRule`
- `TaskDependency`
- `TaskSequence`

Avoid introducing all of these at once. The likely next step is to clarify whether the current `Project` model is sufficient, then add subtasks, then recurrence, then prerequisites and sequences.

## Interaction With Home / Planner

Home should show only the parts of this structure that matter now:

- due or overdue tasks
- active task sequences with a clear next step
- recurring tasks generated for today
- project tasks that are ready to act on

Planner should continue to schedule concrete tasks or next actions, not vague projects. If a large task has subtasks or a sequence, Planner should prefer the next actionable item.

## Implementation Sketch

Start inside the existing task domain:

```text
Models/
  MyTask.swift
  TaskProjectModels.swift
  SubtaskModels.swift

Persistence/
  SwiftDataModels/
    TaskRecord.swift
    TaskProjectRecord.swift
    SubtaskRecord.swift
  Repositories/
    TaskRepository.swift
  SwiftDataRepositories/
    SwiftDataTaskRepository.swift

Features/Tasks/
  Task detail and editing flows
```

Keep recurrence and dependency logic outside SwiftUI views so planner behavior can be tested.

## Open Questions

- Should projects be visible as their own top-level screen, or only as filters/groups inside Tasks?
- Should subtasks be scheduleable individually, or should they remain checklist items under a parent task?
- Should recurrence create future task records immediately, or generate only the next due instance?
- How strict should prerequisites be: hard blocking, soft warning, or planner hint?

## Status

Partially implemented foundation. Existing tasks, lightweight projects, captures, project items, and project-linked tasks are implemented. Subtasks, recurrence, prerequisites, task sequences, and any richer task/project model remain planned.
