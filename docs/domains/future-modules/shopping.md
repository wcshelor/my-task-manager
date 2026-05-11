# Shopping Domain

## Purpose

Shopping helps the user collect things they intend to buy, group them into practical trips, and separate necessary purchases from vague wants.

This should be more structured than ordinary tasks because shopping items have categories, store types, urgency, and possible links to meals, household routines, budgeting, and wish-list decisions.

## Product Shape

The first version should support:

- quick item capture
- category labels
- store or store-type labels
- urgency / necessity labels
- bought / skipped / archived status
- grouped shopping trip suggestions

Examples:

- grocery items grouped into a grocery trip
- pharmacy items grouped into a drugstore trip
- household supplies grouped by store type
- online-only items grouped separately

## Shopping vs Wish List

Shopping list and wish list should be related but distinct.

Shopping list:

- items the user intends to buy
- includes necessities and near-term practical purchases
- optimized around trips and errands

Wish list:

- items the user is considering
- includes luxury, optional, or uncertain purchases
- optimized around decision quality and budget awareness

Some wish-list items may eventually move into the shopping list after a waiting period or decision.

## Possible Item Fields

A `ShoppingItem` might include:

- title
- notes
- category
- store type
- specific store, optional
- urgency: need soon, next trip, someday
- necessity: necessary, useful, optional
- status
- estimated cost
- source domain, such as nutrition, routine, task, or manual
- created date
- purchased date

## Possible Wish List Fields

A `WishListItem` might include:

- title
- notes
- category
- estimated cost
- desire level
- usefulness level
- waiting period
- decision status
- reason wanted
- cheaper alternative
- reviewed date

## Interaction With Tasks / Planner

Shopping items can create or inform errand tasks, but not every item should become a task.

Planner should schedule shopping trips, not individual grocery items. A suggested shopping trip can be based on item urgency, store type, and calendar availability.

Shopping should not write directly to Apple Calendar. Any scheduled trip should flow through the existing Planner / ScheduledBlock system.

## Interaction With Nutrition / Budgeting

Nutrition can generate shopping items from meal plans or missing staples.

Budgeting can consume estimated and actual purchase costs, especially for optional or wish-list items.

## Implementation Sketch

```text
Models/
  ShoppingModels.swift
  WishListModels.swift

Persistence/
  SwiftDataModels/
    ShoppingItemRecord.swift
    WishListItemRecord.swift
  Repositories/
    ShoppingRepository.swift
  SwiftDataRepositories/
    SwiftDataShoppingRepository.swift

Features/Shopping/
  Shopping list
  Trip grouping
  Wish list
```

Start with shopping items. Add wish-list decision support as a second step if needed.

## Design Principles

- Optimize for real trips and errands.
- Keep necessities visually distinct from optional purchases.
- Do not clutter Tasks with every shopping item.
- Let Budgeting participate without making Shopping feel like accounting.

## Open Questions

- Should wish list live inside Shopping or Budgeting?
- Should item categories be fixed, user-defined, or both?
- Should store types be user-defined?
- Should repeated purchases become templates?

## Status

Planning only. No shopping or wish-list model, persistence, or UI exists yet.
