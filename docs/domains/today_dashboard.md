# Today Dashboard Domain

## Purpose

The Today tab is the app's home screen / secretary dashboard. It answers: what matters now, what is scheduled, what needs attention, and what recovery path is available if the day is going poorly.

## Current Cards

- active promises
- due promise check-ins
- routine status
- simple promise history

## Possible Future Cards

- today's scheduled blocks
- urgent tasks
- Health morning check-in status
- PVT / sleep quality status
- planned workout
- top task suggestion
- quick brain dump
- suggested piano practice
- recovery prompt

## Interaction With Tasks / Planner

Today should aggregate state from other domains instead of becoming the owner of their business logic. Task actions should delegate to task repositories/view models. Planning actions should delegate to the planner.

## Status

Implemented as the first tab with Promises and Routines content. Today should continue to aggregate domain state instead of owning domain rules.
