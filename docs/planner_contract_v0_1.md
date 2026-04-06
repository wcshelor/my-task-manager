# Planner Contract (v0.1)

This document describes the current Python planner-ranking reference, not the full frozen product workflow.

For the product-level contract and next Swift milestone, see `docs/product_direction.md`.

## Inputs
- One selected free gap as `TimeInterval` (from `src.gap_detection`) after higher-level planning constraints and calendar availability have already been normalized upstream.
- Active `Task` candidates.
- Active `WorkModeTemplate` candidates.
- Optional `now` timestamp for deterministic urgency scoring in tests/callers.

## Outputs
- `PlannerSelectionResult` containing:
  - `ranked_suggestions`
  - `best_suggestion`
  - `alternatives` (up to 3)
  - `rejected_candidates` with eligibility reasons

## Scoring Dimensions Used (v0.1)
- `urgency_due_date`
- `priority_level`
- `fit_to_gap`
- `minimum_useful_duration`
- `splittability`
- `work_mode_eligibility`

## Intentionally Not Used in v0.1
- Focus-project inference.
- Project membership as an inferred prioritization signal.
- Any adaptive/personalized or learned behavior.
