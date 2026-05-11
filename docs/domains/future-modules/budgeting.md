# Budgeting Domain

## Purpose

Budgeting should help the user understand spending patterns and make better purchase decisions without turning the app into a full accounting system.

The first version should focus on personal spending awareness, optional purchase friction, and connections to Shopping, Wish List, Nutrition, and Vices.

## Product Shape

The app should support lightweight spending records:

- amount
- category
- necessity level
- notes
- optional link to a shopping or wish-list item

This is not intended to replace a bank, accounting app, or full budget spreadsheet at first.

## Possible Objects

- `ExpenseLog`
- `BudgetCategory`
- `MonthlyBudget`
- `PurchaseDecision`

Start with `ExpenseLog` and simple categories. Add monthly budgets or decision flows only after basic logging is useful.

## Possible Expense Fields

An `ExpenseLog` might include:

- timestamp
- amount
- category
- merchant or place
- necessity: necessary, useful, optional, luxury
- payment context, optional
- linked shopping item
- linked wish-list item
- notes

## Purchase Friction

Budgeting can provide a pause flow for uncertain purchases, especially from the wish list.

Possible prompts:

- Why do I want this?
- What problem does it solve?
- Is there a cheaper alternative?
- What happens if I wait?
- Does this conflict with a current promise or budget goal?

This overlaps with Promises and Vices when spending is a habit the user wants to reduce.

## Interaction With Shopping / Wish List

Shopping can provide estimated and actual costs.

Wish List can provide optional purchases that need a waiting period or review before becoming real purchases.

Budgeting can summarize:

- necessary spending
- useful spending
- optional spending
- luxury spending
- repeated categories

## Interaction With Today / Planner

Today can show budget check-ins sparingly:

- weekly spending review
- pending purchase decisions
- active budget promises

Planner should not schedule budget records directly. If a review needs time, it should become a task or scheduled block through the Planner.

## Implementation Sketch

```text
Models/
  BudgetingModels.swift
  ExpenseLogModels.swift

Persistence/
  SwiftDataModels/
    ExpenseLogRecord.swift
    BudgetCategoryRecord.swift
  Repositories/
    BudgetingRepository.swift
  SwiftDataRepositories/
    SwiftDataBudgetingRepository.swift

Features/Budgeting/
  Expense log
  Spending summary
  Purchase decision review
```

Avoid external financial integrations in the first pass.

## Design Principles

- Start manual and lightweight.
- Prefer decision support over accounting completeness.
- Keep budget feedback factual and non-shaming.
- Connect optional purchases to waiting periods and reflection.

## Open Questions

- Should budget categories be fixed, user-defined, or both?
- Should the first version include monthly caps?
- Should repeated expenses be modeled separately?
- Should impulsive spending be tracked here, Vices, or both?

## Status

Planning only. No budgeting model, persistence, or UI exists yet.
