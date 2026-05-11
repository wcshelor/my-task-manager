# Health: Sleep / PVT Subdomain

## Purpose

Track sleepiness, vigilance, and daily context so planning can adapt to energy. This is part of the broader Health domain and is personal trend tracking, not medical advice.

The core concept is a morning psychomotor vigilance task that becomes part of the user's morning routine. The PVT should create a small objective signal that can be compared against subjective sleep quality and night-before context.

## Likely Records

- PVT session
- daily check-in
- sleep duration
- subjective tiredness
- night-before context
- lifestyle context such as caffeine, alcohol, cannabis, food timing, workouts, and other vice logs

Possible future PVT fields:

- session date
- reaction-time summary
- lapse count
- test duration
- notes

Possible daily check-in fields:

- sleep start/end or duration
- tiredness rating
- energy rating
- mood note
- subjective sleep quality
- bedtime consistency
- what the user did the night before
- late meal / heavy meal context
- caffeine/alcohol/cannabis context

## Interaction With Health

Sleep / PVT should be presented as part of the Health section alongside Nutrition and Fitness.

Health-level summaries can compare PVT and sleep data with:

- meal logs
- workout logs
- vice logs
- routine completion
- mood and energy

The first useful experience is likely a Health morning check-in that combines PVT, sleep quality, and a small amount of context.

## Interaction With Tasks / Planner

Sleep and PVT data can inform planner suggestions, especially low-energy planning modes. It should not directly mutate tasks or calendar events.

## Status

Scaffold only. No PVT implementation exists yet.
