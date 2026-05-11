# Life Logs Domain

## Purpose

Support general record keeping for useful personal patterns without encouraging obsessive tracking.

Potential log domains:

- Health logs that do not yet need dedicated Health UI
- mood logs
- meditation logs
- generic log entries

## Modeling Rule

Use generic logs for simple notes, but dedicated models for domains that need structured data.

For example, a quick note that lunch felt heavy may be a generic log. Meal logs, workout logs, and PVT sessions should become structured Health records when they need trend analysis or planning behavior.

## Interaction With Tasks / Planner

Logs can provide context for planning and pattern review. They should not directly write to Apple Calendar. If a logged activity needs future scheduling, it should create or inform a task/planner flow.

## Status

Scaffold only. No life-log model, persistence, or UI exists yet.
