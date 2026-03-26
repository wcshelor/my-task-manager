from datetime import datetime

from src.gap_detection import TimeInterval, find_free_gaps
from src.models import Event, EventSource


def _event(start_hour: int, end_hour: int) -> Event:
    return Event(
        title=f"Event {start_hour}-{end_hour}",
        start_time=datetime(2026, 3, 18, start_hour, 0),
        end_time=datetime(2026, 3, 18, end_hour, 0),
        source=EventSource.APPLE_CALENDAR,
    )


def _window(start_hour: int, end_hour: int) -> tuple[datetime, datetime]:
    return (
        datetime(2026, 3, 18, start_hour, 0),
        datetime(2026, 3, 18, end_hour, 0),
    )


def test_find_free_gaps_no_events_returns_full_window() -> None:
    window_start, window_end = _window(9, 17)

    gaps = find_free_gaps([], window_start, window_end)

    assert gaps == [TimeInterval(start_time=window_start, end_time=window_end)]


def test_find_free_gaps_back_to_back_events_have_no_internal_gap() -> None:
    window_start, window_end = _window(9, 12)
    events = [_event(9, 10), _event(10, 11)]

    gaps = find_free_gaps(events, window_start, window_end)

    assert gaps == [TimeInterval(start_time=datetime(2026, 3, 18, 11, 0), end_time=window_end)]


def test_find_free_gaps_sorts_and_merges_overlapping_events() -> None:
    window_start, window_end = _window(8, 15)
    events = [
        _event(13, 14),
        _event(10, 12),
        _event(9, 11),
    ]

    gaps = find_free_gaps(events, window_start, window_end)

    assert gaps == [
        TimeInterval(start_time=datetime(2026, 3, 18, 8, 0), end_time=datetime(2026, 3, 18, 9, 0)),
        TimeInterval(start_time=datetime(2026, 3, 18, 12, 0), end_time=datetime(2026, 3, 18, 13, 0)),
        TimeInterval(start_time=datetime(2026, 3, 18, 14, 0), end_time=datetime(2026, 3, 18, 15, 0)),
    ]


def test_find_free_gaps_clips_events_partially_outside_window() -> None:
    window_start, window_end = _window(9, 17)
    events = [
        Event(
            title="Spills into window",
            start_time=datetime(2026, 3, 18, 7, 0),
            end_time=datetime(2026, 3, 18, 9, 30),
            source=EventSource.APPLE_CALENDAR,
        ),
        Event(
            title="Spills out of window",
            start_time=datetime(2026, 3, 18, 16, 30),
            end_time=datetime(2026, 3, 18, 18, 0),
            source=EventSource.APPLE_CALENDAR,
        ),
    ]

    gaps = find_free_gaps(events, window_start, window_end)

    assert gaps == [
        TimeInterval(
            start_time=datetime(2026, 3, 18, 9, 30),
            end_time=datetime(2026, 3, 18, 16, 30),
        )
    ]


def test_find_free_gaps_event_fully_contains_another_event() -> None:
    window_start, window_end = _window(8, 16)
    events = [
        _event(9, 15),
        _event(10, 11),
    ]

    gaps = find_free_gaps(events, window_start, window_end)

    assert gaps == [
        TimeInterval(start_time=datetime(2026, 3, 18, 8, 0), end_time=datetime(2026, 3, 18, 9, 0)),
        TimeInterval(start_time=datetime(2026, 3, 18, 15, 0), end_time=datetime(2026, 3, 18, 16, 0)),
    ]
