# AGENTS.md

- Make the smallest correct change.
- Do not refactor unrelated code.
- Prefer existing patterns over new abstractions.

## Architecture

- Keep business logic outside SwiftUI views when possible.
- Keep planner logic testable and deterministic.
- SwiftData owns app data.
- EventKit writes should stay inside Planner / ScheduledBlock flows.

## Verification

- Prefer targeted tests/checks over full-suite runs.
- Do not run iPhone simulator tests by default.
- Prefer deterministic, non-simulator checks first (targeted test scopes and build checks).
- Use iPhone simulator testing sparingly, only when required for the change or for a larger milestone QA pass.
- Do not claim UI behavior was verified unless actually tested.
- Clearly state what still needs manual QA.

## Stop and ask before

- changing architecture,
- adding dependencies,
- touching sync behavior,
- changing persistence models broadly,
- editing many unrelated files.
