from datetime import datetime

import pytest

from src.calendar_read import (
    FIELD_SEPARATOR,
    RECORD_SEPARATOR,
    AppleCalendarReader,
    CalendarDataError,
    CalendarExecutionError,
    CalendarPermissionError,
    ScriptResult,
    parse_apple_event_records,
)
from src.models import EventSource


class QueueRunner:
    def __init__(self, results):
        self._results = list(results)

    def __call__(self, script: str, timeout_seconds: int = 20) -> ScriptResult:
        if not self._results:
            raise AssertionError("No more queued script results")
        return self._results.pop(0)


def test_list_calendars_success() -> None:
    runner = QueueRunner(
        [
            ScriptResult(returncode=0, stdout="OK|2", stderr=""),
            ScriptResult(returncode=0, stdout=f"Work{RECORD_SEPARATOR}School", stderr=""),
        ]
    )
    reader = AppleCalendarReader(runner=runner)

    calendars = reader.list_calendars()

    assert calendars == ["Work", "School"]


def test_fetch_events_maps_to_internal_event_model() -> None:
    start_ts = 1_774_556_400
    end_ts = 1_774_560_000
    event_row = (
        f"abc123{FIELD_SEPARATOR}Work{FIELD_SEPARATOR}Weekly Review"
        f"{FIELD_SEPARATOR}{start_ts}{FIELD_SEPARATOR}{end_ts}"
    )
    runner = QueueRunner(
        [
            ScriptResult(returncode=0, stdout="OK|2", stderr=""),
            ScriptResult(returncode=0, stdout=event_row, stderr=""),
        ]
    )
    reader = AppleCalendarReader(runner=runner)

    events = reader.fetch_events(
        start_time=datetime.fromtimestamp(start_ts - 3600),
        end_time=datetime.fromtimestamp(end_ts + 3600),
        calendar_names=["Work"],
    )

    assert len(events) == 1
    assert events[0].title == "Weekly Review"
    assert events[0].calendar_event_id == "abc123"
    assert events[0].source == EventSource.APPLE_CALENDAR
    assert events[0].start_time == datetime.fromtimestamp(start_ts)
    assert events[0].end_time == datetime.fromtimestamp(end_ts)


def test_fetch_events_permission_denied() -> None:
    runner = QueueRunner(
        [
            ScriptResult(returncode=0, stdout="ERROR|-1743|Not authorized", stderr=""),
        ]
    )
    reader = AppleCalendarReader(runner=runner)

    with pytest.raises(CalendarPermissionError):
        reader.fetch_events(
            start_time=datetime(2026, 3, 18, 9, 0),
            end_time=datetime(2026, 3, 18, 10, 0),
        )


def test_parse_records_rejects_malformed_row() -> None:
    malformed = "too-few-fields"
    with pytest.raises(CalendarDataError):
        parse_apple_event_records(malformed)


def test_non_zero_osascript_exit_raises_execution_error() -> None:
    runner = QueueRunner(
        [
            ScriptResult(returncode=1, stdout="", stderr="execution error: Calendar got an error"),
        ]
    )
    reader = AppleCalendarReader(runner=runner)

    with pytest.raises(CalendarExecutionError):
        reader.get_access_status()
