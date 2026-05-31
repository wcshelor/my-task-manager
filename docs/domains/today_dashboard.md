# Home / Today Dashboard Domain

## Purpose

Home is the app's current home screen / secretary dashboard. Older docs may call this surface Today. It answers: what matters now, what is scheduled, what needs attention, and what recovery path is available if the day is going poorly.

## Current Implemented Surface

- persisted, reorderable Home widget board
- quick capture and inbox review
- pinned project and project-next-task widgets
- today's calendar overview, next event, and Plan the Day widgets
- active promises, due promise check-ins, and simple promise history
- today's routines and current routine step widgets
- Shopping module and Shopping Quick Add widgets
- Health, Music Practice, Fitness, and People module widgets
- lightweight pending Debrief summaries that can show linked project names and focus-task counts when available

## Possible Future Cards

- urgent tasks
- richer Health morning check-in status
- PVT / sleep quality status
- planned workout
- top task suggestion
- quick brain dump
- suggested piano practice
- recovery prompt

## Interaction With Tasks / Planner

Home should aggregate state from other domains instead of becoming the owner of their business logic. Task actions should delegate to task repositories/view models. Planning actions should delegate to the planner. Block Focus editing and task selection belong on project or event detail surfaces, not inside Home widgets.

## Status

Implemented as the first tab under the `Home` label with a persisted widget board and module entry points. Home should continue to aggregate domain state instead of owning domain rules.
