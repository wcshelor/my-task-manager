#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
import tempfile
import sys
from typing import Callable

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from src.calendar_manager import CalendarManager
from src.calendar_read import FIELD_SEPARATOR, parse_apple_event_records
from src.gap_detection import TimeInterval, find_free_gaps
from src.models import (
    EnergyLevel,
    Event,
    EventSource,
    PriorityLevel,
    Project,
    ScheduledBlock,
    ScheduledBlockCreationMethod,
    ScheduledBlockSourceType,
    Task,
    TaskStatus,
    UserPreferences,
    WorkModeTemplate,
)
from src.planner import select_candidates_for_gap
import src.scheduler as scheduler_module
import src.task_manager as task_manager_module
import src.utils as utils_module


@dataclass
class CheckResult:
    name: str
    ok: bool
    detail: str


def _run_check(name: str, fn: Callable[[], str]) -> CheckResult:
    try:
        detail = fn()
        return CheckResult(name=name, ok=True, detail=detail)
    except Exception as exc:  # noqa: BLE001
        return CheckResult(name=name, ok=False, detail=f"{type(exc).__name__}: {exc}")


def _models_roundtrip() -> str:
    project = Project(name="BERThoven")
    task = Task(
        title="Finish report",
        project_id=project.id,
        status=TaskStatus.ACTIVE,
        due_date=datetime(2026, 3, 25, 12, 0),
        priority_level=PriorityLevel.HIGH,
        energy_level=EnergyLevel.HIGH,
        estimated_minutes=90,
        min_block_minutes=30,
        is_splittable=True,
        tags=["Docs"],
    )
    work_mode = WorkModeTemplate(
        title="Work on BERThoven",
        project_id=project.id,
        default_estimated_minutes=60,
        min_block_minutes=30,
    )
    event = Event(
        title="Lecture",
        start_time=datetime(2026, 3, 20, 10, 0),
        end_time=datetime(2026, 3, 20, 11, 0),
        source=EventSource.APPLE_CALENDAR,
    )
    block = ScheduledBlock(
        start_time=datetime(2026, 3, 20, 12, 0),
        end_time=datetime(2026, 3, 20, 13, 0),
        source_type=ScheduledBlockSourceType.TASK,
        task_id=task.id,
        creation_method=ScheduledBlockCreationMethod.SUGGESTED,
    )

    assert Task.from_dict(task.to_dict()).to_dict() == task.to_dict()
    assert Event.from_dict(event.to_dict()).to_dict() == event.to_dict()
    assert ScheduledBlock.from_dict(block.to_dict()).to_dict() == block.to_dict()

    return f"project={project.name}, task={task.title}, work_mode={work_mode.title}"


def _gap_detection() -> str:
    window_start = datetime(2026, 3, 18, 9, 0)
    window_end = datetime(2026, 3, 18, 17, 0)
    events = [
        Event(
            title="Busy 1",
            start_time=datetime(2026, 3, 18, 10, 0),
            end_time=datetime(2026, 3, 18, 11, 0),
            source=EventSource.APPLE_CALENDAR,
        ),
        Event(
            title="Busy 2",
            start_time=datetime(2026, 3, 18, 13, 0),
            end_time=datetime(2026, 3, 18, 14, 0),
            source=EventSource.APPLE_CALENDAR,
        ),
    ]
    gaps = find_free_gaps(events, window_start, window_end)

    assert len(gaps) == 3
    assert gaps[0] == TimeInterval(window_start, datetime(2026, 3, 18, 10, 0))

    return f"{len(gaps)} gaps found"


def _planner_selection() -> str:
    now = datetime(2026, 3, 18, 9, 0)
    gap = TimeInterval(start_time=now, end_time=now + timedelta(hours=2))
    tasks = [
        Task(
            title="Soon due",
            status=TaskStatus.ACTIVE,
            due_date=now + timedelta(hours=6),
            priority_level=PriorityLevel.MEDIUM,
            estimated_minutes=60,
            min_block_minutes=15,
        ),
        Task(
            title="Later task",
            status=TaskStatus.ACTIVE,
            due_date=now + timedelta(days=7),
            priority_level=PriorityLevel.HIGHEST,
            estimated_minutes=60,
            min_block_minutes=15,
        ),
    ]
    work_modes = [
        WorkModeTemplate(
            title="Admin catch-up",
            default_estimated_minutes=45,
            min_block_minutes=15,
            is_active=True,
        )
    ]
    result = select_candidates_for_gap(gap, tasks, work_modes, now=now)

    assert result.best_suggestion is not None
    assert result.best_suggestion.title == "Soon due"

    return f"best={result.best_suggestion.title}, suggestions={len(result.ranked_suggestions)}"


def _calendar_record_parse() -> str:
    row = (
        f"abc123{FIELD_SEPARATOR}Work{FIELD_SEPARATOR}Review"
        f"{FIELD_SEPARATOR}1774556400{FIELD_SEPARATOR}1774560000"
    )
    events = parse_apple_event_records(row)

    assert len(events) == 1
    assert events[0].title == "Review"

    return events[0].title


def _utils_roundtrip() -> str:
    temp_path = Path(tempfile.gettempdir()) / "task_manager_smoke_tasks.json"
    utils_module.save_tasks([Task(title="Smoke task")], temp_path)
    loaded = utils_module.load_tasks(temp_path)

    assert len(loaded) == 1
    assert loaded[0].title == "Smoke task"

    return f"roundtrip via {temp_path.name}"


def _task_manager_add() -> str:
    temp_path = Path(tempfile.gettempdir()) / "task_manager_smoke_add.json"
    original_load = task_manager_module.load_tasks
    original_save = task_manager_module.save_tasks
    try:
        task_manager_module.load_tasks = lambda: []
        task_manager_module.save_tasks = lambda tasks: utils_module.save_tasks(tasks, temp_path)
        task_manager_module.add_task(Task(title="Smoke add", status=TaskStatus.ACTIVE))
    finally:
        task_manager_module.load_tasks = original_load
        task_manager_module.save_tasks = original_save

    return f"added via {temp_path.name}"


def _calendar_task_event() -> str:
    manager = CalendarManager()
    event = manager.create_task_event(Task(title="Task event"), datetime(2026, 3, 18, 9, 0), 1.0)

    assert event.title
    return event.title


def _scheduler_generation() -> str:
    class FakeCalendarManager:
        def get_free_time_blocks(self, start_date, end_date, min_duration=0.5):
            return [(start_date, start_date + timedelta(hours=2))]

    original_get_preferences = scheduler_module.get_preferences
    original_get_calendar_manager = scheduler_module.get_calendar_manager
    try:
        scheduler_module.get_preferences = lambda: UserPreferences()
        scheduler_module.get_calendar_manager = lambda: FakeCalendarManager()
        generator = scheduler_module.ScheduleGenerator(
            tasks=[Task(title="Schedule me", status=TaskStatus.ACTIVE)]
        )
        sessions = generator.generate_schedule(start_date=datetime(2026, 3, 18, 9, 0), days_ahead=1)
    finally:
        scheduler_module.get_preferences = original_get_preferences
        scheduler_module.get_calendar_manager = original_get_calendar_manager

    return f"{len(sessions)} sessions"


def main() -> int:
    checks = [
        ("models_roundtrip", _models_roundtrip),
        ("gap_detection", _gap_detection),
        ("planner_selection", _planner_selection),
        ("calendar_record_parse", _calendar_record_parse),
        ("utils_roundtrip", _utils_roundtrip),
        ("task_manager_add", _task_manager_add),
        ("calendar_task_event", _calendar_task_event),
        ("scheduler_generation", _scheduler_generation),
    ]

    results = [_run_check(name, fn) for name, fn in checks]

    print("Core Smoke Check")
    print("================")
    for result in results:
        status = "PASS" if result.ok else "FAIL"
        print(f"{status:4} {result.name}: {result.detail}")

    passed = sum(1 for result in results if result.ok)
    failed = len(results) - passed
    print()
    print(f"Summary: {passed} passed, {failed} failed")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
