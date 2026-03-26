from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import subprocess
from typing import Callable, List, Optional, Protocol, Sequence

from .models import Event, EventSource, ValidationError


RECORD_SEPARATOR = "\x1e"
FIELD_SEPARATOR = "\x1f"


class CalendarIntegrationError(RuntimeError):
    """Base exception for calendar read integration failures."""


class CalendarPermissionError(CalendarIntegrationError):
    """Raised when the app cannot access Apple Calendar."""


class CalendarExecutionError(CalendarIntegrationError):
    """Raised when osascript execution fails."""


class CalendarDataError(CalendarIntegrationError):
    """Raised when Apple Calendar returns malformed data."""


@dataclass(frozen=True)
class CalendarAccessStatus:
    granted: bool
    error_code: Optional[int] = None
    message: str = ""


class CalendarEventFetcher(Protocol):
    def fetch_events(
        self,
        start_time: datetime,
        end_time: datetime,
        calendar_names: Optional[Sequence[str]] = None,
    ) -> List[Event]:
        ...


@dataclass(frozen=True)
class ScriptResult:
    returncode: int
    stdout: str
    stderr: str


class ScriptRunner(Protocol):
    def __call__(self, script: str, timeout_seconds: int = 20) -> ScriptResult:
        ...


def default_script_runner(script: str, timeout_seconds: int = 20) -> ScriptResult:
    completed = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        timeout=timeout_seconds,
        check=False,
    )
    return ScriptResult(
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )


class AppleCalendarReader:
    """
    Read-only Apple Calendar integration for v0.1.

    Responsibilities:
    - Check calendar access.
    - List available calendars.
    - Fetch events in a date range and map into internal Event models.
    """

    def __init__(self, runner: Optional[ScriptRunner] = None):
        self._runner = runner or default_script_runner

    def get_access_status(self) -> CalendarAccessStatus:
        result = self._run_script(_build_permission_check_script(), timeout_seconds=10)
        output = result.stdout.strip()

        if output.startswith("OK|"):
            return CalendarAccessStatus(granted=True, message="Calendar access granted")

        if output.startswith("ERROR|"):
            parts = output.split("|", 2)
            code = _safe_int(parts[1]) if len(parts) > 1 else None
            message = parts[2] if len(parts) > 2 else "Unknown Calendar permission error"
            return CalendarAccessStatus(granted=False, error_code=code, message=message)

        return CalendarAccessStatus(
            granted=False,
            message=f"Unexpected permission-check response: {output or '<empty>'}",
        )

    def list_calendars(self) -> List[str]:
        status = self.get_access_status()
        if not status.granted:
            raise CalendarPermissionError(_permission_message(status))

        result = self._run_script(_build_list_calendars_script(), timeout_seconds=15)
        output = result.stdout.strip()
        if not output:
            return []

        if output.startswith("ERROR|"):
            raise CalendarDataError(f"Failed to list calendars: {output}")

        return [name for name in output.split(RECORD_SEPARATOR) if name]

    def fetch_events(
        self,
        start_time: datetime,
        end_time: datetime,
        calendar_names: Optional[Sequence[str]] = None,
    ) -> List[Event]:
        if end_time <= start_time:
            raise ValueError("end_time must be after start_time")

        status = self.get_access_status()
        if not status.granted:
            raise CalendarPermissionError(_permission_message(status))

        script = _build_fetch_events_script(
            start_epoch=int(start_time.timestamp()),
            end_epoch=int(end_time.timestamp()),
            calendar_names=list(calendar_names) if calendar_names else [],
        )
        result = self._run_script(script, timeout_seconds=25)
        output = result.stdout.strip()

        if not output:
            return []
        if output.startswith("ERROR|NO_CALENDARS|"):
            return []
        if output.startswith("ERROR|"):
            raise CalendarDataError(f"Calendar read failed: {output}")

        return parse_apple_event_records(output)

    def _run_script(self, script: str, timeout_seconds: int) -> ScriptResult:
        result = self._runner(script, timeout_seconds)
        if result.returncode != 0:
            stderr = result.stderr.strip()
            raise CalendarExecutionError(stderr or "osascript returned non-zero exit status")
        return result


def parse_apple_event_records(raw_output: str) -> List[Event]:
    events: List[Event] = []
    lines = [line for line in raw_output.split(RECORD_SEPARATOR) if line]
    for line in lines:
        fields = line.split(FIELD_SEPARATOR)
        if len(fields) != 5:
            raise CalendarDataError(f"Malformed event record: {line!r}")

        calendar_event_id, _calendar_name, title, start_ts, end_ts = fields
        start_time = datetime.fromtimestamp(float(start_ts))
        end_time = datetime.fromtimestamp(float(end_ts))

        try:
            event = Event(
                title=title,
                start_time=start_time,
                end_time=end_time,
                source=EventSource.APPLE_CALENDAR,
                calendar_event_id=calendar_event_id or None,
            )
        except (ValidationError, ValueError) as exc:
            raise CalendarDataError(f"Invalid calendar event data: {line!r}") from exc

        events.append(event)

    return events


def _permission_message(status: CalendarAccessStatus) -> str:
    detail = status.message or "Calendar access denied"
    return (
        "Apple Calendar access is not available. "
        f"Details: {detail}. "
        "Grant Calendar permission to the host app (Terminal/IDE) in macOS Privacy settings."
    )


def _safe_int(value: str) -> Optional[int]:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _escape_applescript_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _build_permission_check_script() -> str:
    return """
tell application "Calendar"
    try
        set calCount to count of calendars
        return "OK|" & calCount
    on error errMsg number errNum
        return "ERROR|" & errNum & "|" & errMsg
    end try
end tell
""".strip()


def _build_list_calendars_script() -> str:
    return f"""
tell application "Calendar"
    try
        set rs to ASCII character 30
        set namesList to {{}}
        repeat with cal in calendars
            set end of namesList to (name of cal as string)
        end repeat
        set AppleScript's text item delimiters to rs
        set outText to namesList as string
        set AppleScript's text item delimiters to ""
        return outText
    on error errMsg number errNum
        return "ERROR|" & errNum & "|" & errMsg
    end try
end tell
""".strip()


def _build_fetch_events_script(
    start_epoch: int,
    end_epoch: int,
    calendar_names: Sequence[str],
) -> str:
    if calendar_names:
        escaped_names = ", ".join(f'"{_escape_applescript_string(name)}"' for name in calendar_names)
        selected_names_block = f"set selectedNames to {{{escaped_names}}}"
        target_calendars_block = """
        set targetCalendars to {}
        repeat with calName in selectedNames
            try
                set end of targetCalendars to calendar (calName as string)
            on error
                -- Ignore unknown calendar names
            end try
        end repeat
        if (count of targetCalendars) = 0 then
            return "ERROR|NO_CALENDARS|No matching calendars found"
        end if
        """.strip()
    else:
        selected_names_block = "set selectedNames to {}"
        target_calendars_block = "set targetCalendars to calendars"

    return f"""
tell application "Calendar"
    try
        set rs to ASCII character 30
        set fs to ASCII character 31
        set epochZero to date "Thursday, January 1, 1970 at 12:00:00 AM"
        set startDate to epochZero + {start_epoch}
        set endDate to epochZero + {end_epoch}

        {selected_names_block}
        {target_calendars_block}

        set outputRows to {{}}

        repeat with cal in targetCalendars
            set calName to (name of cal as string)
            set relevantEvents to (every event of cal whose end date > startDate and start date < endDate)
            repeat with evt in relevantEvents
                set uidText to ""
                try
                    set uidText to (uid of evt as string)
                end try
                set titleText to ""
                try
                    set titleText to (summary of evt as string)
                end try
                set titleText to my sanitizeField(titleText)
                set startTs to ((start date of evt) - epochZero) as integer
                set endTs to ((end date of evt) - epochZero) as integer
                set rowText to uidText & fs & calName & fs & titleText & fs & (startTs as string) & fs & (endTs as string)
                set end of outputRows to rowText
            end repeat
        end repeat

        set AppleScript's text item delimiters to rs
        set outText to outputRows as string
        set AppleScript's text item delimiters to ""
        return outText
    on error errMsg number errNum
        return "ERROR|" & errNum & "|" & errMsg
    end try
end tell

on sanitizeField(inputText)
    set t to inputText as string
    set t to my replaceText(return, " ", t)
    set t to my replaceText(linefeed, " ", t)
    set t to my replaceText(tab, " ", t)
    set t to my replaceText(ASCII character 30, " ", t)
    set t to my replaceText(ASCII character 31, " ", t)
    return t
end sanitizeField

on replaceText(findText, replaceWith, sourceText)
    set AppleScript's text item delimiters to findText
    set chunks to text items of sourceText
    set AppleScript's text item delimiters to replaceWith
    set replacedText to chunks as string
    set AppleScript's text item delimiters to ""
    return replacedText
end replaceText
""".strip()
