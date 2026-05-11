# Future Home Widgets

## Purpose

The home screen should become a modular command board. Full modules should still have their own pages, while home widgets provide shortcuts, summaries, and lightweight controls for the parts of the app the user wants present today.

Widgets can represent either:

- a whole module, usually opening that module's main page
- a specific feature, sub-module, record, status, or action from a module

## Widget Model Ideas

### Sizes

- Small: one status, one action, or one destination
- Large: richer summary, short list, progress view, or primary workflow entry

Additional sizes should wait until the small / large system proves too limiting.

### Add Widget Flow

The Add Widget screen can list modules first. Tapping a module's primary add control adds the generic module widget. Expanding a module reveals feature widgets and sub-module widgets.

Example:

```text
Promises
  Add Promises
  Show Widgets
    Active Promise
    Due Check-ins
    Promise History
```

Some widgets should add immediately. Others need configuration, such as choosing a project, routine, budget category, person, instrument, or health metric.

### Editing

- Long press a widget to enter edit mode
- Drag widgets to reorder
- Remove widgets from the board
- Resize between small and large when supported
- Configure widgets that are tied to a specific project, routine, person, category, or metric
- Plus button at the bottom opens Add Widget

## Global / Cross-Module Widgets

### Command Center

- Today's Focus: one top suggested action across all modules
- Now: current event, active promise, current routine step, or next task
- Next Best Action: one recommended next step based on time, energy, and urgency
- Recovery Mode: low-friction reset path when the day is going poorly
- Daily Brief: short morning summary of calendar, tasks, routines, promises, and health
- Evening Review: quick review of what happened today
- Open Loops: combined list of unresolved captures, promises, overdue tasks, and stale project items
- Momentum: recent completions across tasks, routines, practice, and promises
- Friction Alert: highlights the part of the system most likely to fail today
- Quick Actions: configurable row of favorite actions
- Search Everything: universal search entry point
- Recent Activity: latest logs, completions, captures, and changes
- Important Dates: birthdays, deadlines, renewals, and scheduled commitments

### Capture

- Quick Capture: write a thought without choosing a destination first
- Voice Capture: record or dictate a thought
- Inbox Count: pending captures and oldest capture age
- Review Inbox: jump directly into inbox review
- Project-Tagged Captures: pending captures already attached to projects
- Capture Streak: days with at least one useful capture
- Unsorted Ideas: captures that have no project, tag, or conversion

## Tasks Widgets

### Module Widget

- Tasks: active count, overdue count, and tap-through to the Tasks page

### Feature Widgets

- Add Task: quick task creation
- Due Today: tasks due today
- Overdue Tasks: overdue task count and list
- Urgent Tasks: high-priority active tasks
- Low Energy Tasks: tasks matching low energy
- Deep Work Tasks: tasks marked for focused work
- Quick Wins: short tasks under a configured minute threshold
- Waiting Tasks: tasks blocked by someone or something else
- Tagged Tasks: tasks for a selected tag
- Task Group: tasks for a selected group
- Next Task: one recommended task
- Task Search: jump into filtered search
- Recently Completed: recent task completions
- Stale Tasks: tasks not updated in a while
- Recurring Tasks: recurring or repeating obligations once task evolution exists
- Subtasks: progress for a selected parent task once subtasks exist
- Task Sequence: next item in a configured task sequence

## Planner / Calendar Widgets

### Module Widget

- Planner: today's event count, planned work blocks, and tap-through to Planner

### Feature Widgets

- Today's Events: next few calendar events
- Next Event: compact current / next event card
- Free Time: next open block of time
- Plan the Day: generate or open daily planning
- Plan Next Free Slot: pick work for the next available slot
- Scheduled Blocks: accepted work blocks for today
- Draft Suggestions: pending planner suggestions
- Calendar Permission: status and fix path if permissions are missing
- Writable Calendar: selected write calendar status
- Morning Brief: calendar, tasks, and scheduling summary
- Week Overview: upcoming busy periods and planning gaps
- Month Overview: lightweight month planning entry point
- Reconcile Calendar: alert when external calendar changes affect accepted blocks
- Focus Block: current accepted scheduled block with task action
- Planning Filters: jump into saved planning filter presets

## Projects Widgets

### Module Widget

- Projects: active project count, pinned count, and tap-through to Projects

### Feature Widgets

- Pinned Projects: list of pinned projects
- Pinned Project: selected project summary
- Project Next Task: next task for a selected project
- Project Inbox: captures and project items for a selected project
- Project Maybe List: maybe items for a selected project
- Project Notes: notes for a selected project
- Project Progress: active tasks versus completed tasks
- Project Review: projects needing review
- Stale Projects: projects with no recent movement
- Create Project: fast project creation
- Project Quick Capture: capture directly into a selected project
- Project Tasks: task list scoped to a selected project
- Project Decisions: unresolved decisions or maybe items
- Project Pressure: high-pressure project items

## Promises Widgets

### Module Widget

- Promises: active promises, due check-ins, and tap-through to Promises

### Feature Widgets

- Active Promise: most important active promise
- Due Check-ins: promises due for check-in
- Promise Quick Add: create a promise quickly
- Promise Check-in: direct check-in for the next due promise
- Promise History: kept and missed counts
- Kept Streak: recent kept-promise streak
- Reset Promise: create a reset after a miss
- Breaking Friction: future flow before logging an action that would break a promise
- Promise Presence: compact reminder for use across app surfaces
- Specific Promise: pin one selected promise until resolved
- Promise Reflection: review recent missed promises and common friction

## Routines Widgets

### Module Widget

- Routines: active routines today and completion summary

### Feature Widgets

- Today's Routines: all routines active today
- Specific Routine: progress for a selected routine
- Morning Routine: configured morning routine
- Evening Routine: configured evening routine
- Current Routine Step: next incomplete step
- Start Routine: one-tap start for a selected routine
- Routine Streak: completion trend for a selected routine
- Routine Builder: create a new routine
- Missed Routine Recovery: restart or simplify a missed routine
- Weekday Routines: routines active on the current weekday
- Routine Checklist: large widget with several steps visible

## Health Widgets

### Module Widget

- Health: daily health status and tap-through to Health

### Feature Widgets

- Morning Health Check-in: sleep, tiredness, and readiness input
- Sleep Summary: duration, quality, and bedtime context
- PVT Test: start daily psychomotor vigilance test
- PVT Result: reaction time and lapse summary
- Low Energy Warning: suggests lighter planning when sleep or PVT is poor
- Caffeine Context: log caffeine and see timing
- Alcohol Context: log alcohol context for sleep and energy patterns
- Cannabis Context: log cannabis context for sleep and motivation patterns
- Health Trends: simple trend across sleep, PVT, routines, and mood
- Recovery Suggestion: suggested lower-pressure day structure
- Medication / Supplement Log: lightweight daily status if added later
- Symptoms Log: quick symptom capture if added later

## Fitness Widgets

### Module Widget

- Fitness: planned workout, latest workout, and tap-through to Fitness

### Feature Widgets

- Planned Workout: today's workout plan
- Start Workout: open workout logging
- Workout Log: quick log completed workout
- Strength Progress: selected lift or movement trend
- Cardio Progress: selected run, bike, or endurance metric
- Mobility Routine: start selected mobility routine
- Active Program: current training program status
- Rest Day: recovery status and next workout
- Exercise PRs: recent personal records
- Weekly Volume: weekly set, distance, or time summary

## Nutrition Widgets

### Module Widget

- Nutrition: today's meals and tap-through to Nutrition

### Feature Widgets

- Meal Quick Log: log a meal quickly
- Last Meal: time and type of last logged meal
- Protein Check: rough protein status if tracked
- Hydration Check: water status if tracked
- Late Meal Alert: evening meal awareness
- Grocery Tie-in: add missing food to shopping
- Eating Pattern: recent homemade / takeout / skipped pattern
- Caffeine with Meals: caffeine timing context
- Nutrition Notes: freeform food context

## Shopping Widgets

### Module Widget

- Shopping: active list count and tap-through to Shopping

### Feature Widgets

- Shopping Quick Add: add item to shopping list
- Active Shopping List: items for the next trip
- Store Trip: grouped list by store or trip
- Needed Soon: essentials running low
- Wish List: deferred wants
- Purchase Decision Queue: items waiting for a decision
- Shopping Capture: capture without categorizing yet
- Pantry / Household: repeat household items if added later
- Errand Bundle: shopping plus nearby errands if location support is added later
- Recently Bought: recent purchase log

## Budgeting Widgets

### Module Widget

- Budgeting: recent spending, decision queue, and tap-through to Budgeting

### Feature Widgets

- Expense Quick Log: add manual expense
- Today's Spending: spending logged today
- Week Spending: rough weekly total
- Category Spend: selected category summary
- Purchase Decision: review a pending purchase
- Wants Queue: discretionary purchases waiting for cooldown
- Recurring Bills: upcoming recurring expenses if added later
- Budget Alert: category approaching limit
- Savings Goal: progress toward a selected goal
- Recent Expenses: latest manual expense logs
- Cash Flow Check: lightweight income / expense overview if added later

## Vices Widgets

### Module Widget

- Vices: status for tracked vices and tap-through to Vices

### Feature Widgets

- Urge Log: log an urge before acting
- Mindful Pause: pre-action friction flow
- Limit Status: progress against daily or weekly limit
- Streak: days since selected vice
- Pattern Review: recent contexts and triggers
- Promise Conflict: warns when an action would break an active promise
- Replacement Action: suggested alternative action
- Reset After Slip: non-punitive recovery flow
- Specific Vice: status for one selected vice
- Trigger Tag: quick log common trigger

## People Memory Widgets

### Module Widget

- People: recent people, reminders, and tap-through to People Memory

### Feature Widgets

- Name Review: study names or faces
- Recently Met: people added recently
- Upcoming Interaction: people tied to upcoming calendar events
- Follow-up Reminder: people needing follow-up
- Person Note: pin one person's context
- Add Person: quick add person
- Relationship Tags: selected tag group
- Study Mode: spaced repetition for names or facts
- Conversation Prep: notes before meeting someone
- Birthday / Important Date: upcoming personal dates

## Music Practice Widgets

### Module Widget

- Music Practice: active pieces and recent practice

### Feature Widgets

- Start Practice: begin a practice session
- Active Piece: selected piece status
- Practice Routine: selected technical or repertoire routine
- Today's Practice Plan: suggested practice blocks
- Practice Log: quick log session
- Time Practiced: weekly practice minutes
- Piece Progress: learning / polishing / learned status
- Technical Skill: selected skill focus
- Repertoire Queue: pieces waiting for attention
- Practice Streak: recent practice consistency
- Metronome / Tempo Goal: target tempo for a section if added later

## Journaling / Reflection Widgets

### Module Widget

- Journal: recent entries and tap-through to Journaling

### Feature Widgets

- Quick Journal: start freeform entry
- Guided Reflection: answer today's prompt
- Evening Reflection: day review
- Mood Check-in: simple mood log
- Gratitude Prompt: lightweight positive reflection
- Friction Log: log what made progress hard
- Decision Journal: record a decision and reasoning
- Recent Entries: latest journal entries
- Follow-up Actions: actions extracted from reflections
- Search Journal: jump into journal search
- Unreviewed Reflections: entries waiting for follow-up

## Life Logs Widgets

### Module Widget

- Life Logs: recent logs and tap-through to generic logs

### Feature Widgets

- Quick Log: create a generic log entry
- Selected Log Type: quick add for a configured log type
- Recent Logs: latest entries
- Log Streak: days with logs for selected type
- Pattern Snapshot: simple trend for selected log
- Review Logs: open review mode
- Tagged Logs: logs for selected tag
- Convert Log Type: promote recurring log type into its own module

## Future Add Widget Gallery

The gallery should probably use this hierarchy:

```text
Add Widget

Favorites / Suggested
  Quick Capture
  Today’s Events
  Start Morning Routine
  Active Promise

Modules
  Tasks
    Add Tasks
    Due Today
    Quick Wins
    Low Energy Tasks

  Planner
    Add Planner
    Today’s Events
    Plan the Day
    Next Free Slot

  Projects
    Add Projects
    Pinned Project
    Project Inbox
    Project Next Task
```

Suggested widgets should be based on actual app state where possible. For example:

- if captures are piling up, suggest Inbox Count or Review Inbox
- if routines exist, suggest Today's Routines
- if promises are active, suggest Active Promise
- if projects are pinned, suggest Pinned Project
- if calendar access is granted, suggest Today's Events and Plan the Day
- if a future module has no data yet, suggest its quick-add or setup widget

## Open Questions

- Should the top of Home include a non-removable smart Now area?
- Should widgets be arranged as one vertical list, a two-column grid on larger screens, or a mixed layout?
- Should every module automatically get a module widget, or should modules opt in explicitly?
- Should widget configuration live in app settings, a dedicated home layout repository, or module-owned preferences?
- Should hidden widgets preserve configuration when removed?
- Should module pages have their own mini widget systems later, or should only Home be customizable?
