from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Iterable, List

from .models import Event


@dataclass(frozen=True)
class TimeInterval:
    start_time: datetime
    end_time: datetime

    def __post_init__(self) -> None:
        if self.end_time <= self.start_time:
            raise ValueError("TimeInterval.end_time must be after TimeInterval.start_time")


def _validate_window(window_start: datetime, window_end: datetime) -> None:
    if window_end <= window_start:
        raise ValueError("window_end must be after window_start")


def merge_event_intervals(
    events: Iterable[Event], window_start: datetime, window_end: datetime
) -> List[TimeInterval]:
    """
    Build merged busy intervals clipped to the requested window.

    Back-to-back events are merged so no zero-length free gap appears.
    """
    _validate_window(window_start, window_end)

    clipped: List[TimeInterval] = []
    for event in events:
        clipped_start = max(event.start_time, window_start)
        clipped_end = min(event.end_time, window_end)
        if clipped_end > clipped_start:
            clipped.append(TimeInterval(start_time=clipped_start, end_time=clipped_end))

    if not clipped:
        return []

    clipped.sort(key=lambda interval: (interval.start_time, interval.end_time))

    merged: List[TimeInterval] = [clipped[0]]
    for current in clipped[1:]:
        previous = merged[-1]
        if current.start_time <= previous.end_time:
            merged[-1] = TimeInterval(
                start_time=previous.start_time,
                end_time=max(previous.end_time, current.end_time),
            )
        else:
            merged.append(current)

    return merged


def find_free_gaps(
    events: Iterable[Event], window_start: datetime, window_end: datetime
) -> List[TimeInterval]:
    """Return free intervals inside the requested window."""
    busy_intervals = merge_event_intervals(events, window_start, window_end)

    if not busy_intervals:
        return [TimeInterval(start_time=window_start, end_time=window_end)]

    free_gaps: List[TimeInterval] = []
    cursor = window_start

    for busy in busy_intervals:
        if busy.start_time > cursor:
            free_gaps.append(TimeInterval(start_time=cursor, end_time=busy.start_time))
        cursor = max(cursor, busy.end_time)

    if cursor < window_end:
        free_gaps.append(TimeInterval(start_time=cursor, end_time=window_end))

    return free_gaps
