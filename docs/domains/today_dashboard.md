# Today Dashboard Domain

## Purpose

The Today tab should become the future home screen / secretary dashboard. It should answer: what matters now, what is scheduled, what needs attention, and what recovery path is available if the day is going poorly.

## Possible Cards

- today's scheduled blocks
- urgent tasks
- routine status
- PVT/check-in status
- top task suggestion
- quick brain dump
- suggested piano practice
- recovery prompt

## Interaction With Tasks / Planner

Today should aggregate state from other domains instead of becoming the owner of their business logic. Task actions should delegate to task repositories/view models. Planning actions should delegate to the planner.

## Status

Scaffold only. Do not add an empty visible Today tab until there is enough useful content to avoid broken UX.
