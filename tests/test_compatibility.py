import json
from datetime import datetime, timedelta

from src.calendar_manager import CalendarManager
from src.models import EnergyLevel, PriorityLevel, Task, TaskStatus, UserPreferences
import src.scheduler as scheduler_module
import src.task_manager as task_manager_module
import src.utils as utils_module


def test_load_tasks_accepts_legacy_task_schema(tmp_path) -> None:
    path = tmp_path / "legacy_tasks.json"
    path.write_text(
        json.dumps(
            [
                {
                    "id": "legacy-1",
                    "title": "Legacy task",
                    "deadline": "2026-03-28T09:00:00",
                    "est_time": 1.5,
                    "effort": "High",
                    "notes": "Imported note",
                    "completed": False,
                    "dependencies": ["dep-1"],
                    "is_splittable": True,
                    "max_sessions": 3,
                    "min_session_time": 0.5,
                    "category": "Admin",
                    "priority": 2,
                    "actual_time_spent": 0.25,
                    "sessions_completed": 1,
                }
            ]
        ),
        encoding="utf-8",
    )

    loaded = utils_module.load_tasks(path)

    assert len(loaded) == 1
    task = loaded[0]
    assert task.title == "Legacy task"
    assert task.deadline == datetime(2026, 3, 28, 9, 0)
    assert task.description == "Imported note"
    assert task.estimated_minutes == 90
    assert task.min_block_minutes == 30
    assert task.energy_level == EnergyLevel.HIGH
    assert task.priority_level == PriorityLevel.HIGH
    assert task.status == TaskStatus.ACTIVE
    assert task.dependencies == ["dep-1"]
    assert task.actual_time_spent == 0.25
    assert task.sessions_completed == 1


def test_utils_roundtrip_uses_current_task_schema(tmp_path) -> None:
    path = tmp_path / "tasks.json"
    task = Task(
        title="Smoke task",
        status=TaskStatus.ACTIVE,
        estimated_minutes=45,
        min_block_minutes=15,
    )

    utils_module.save_tasks([task], path)
    loaded = utils_module.load_tasks(path)

    assert len(loaded) == 1
    assert loaded[0].to_dict() == task.to_dict()


def test_task_manager_add_task_supports_current_task_model(monkeypatch, tmp_path) -> None:
    saved = {}

    def fake_save(tasks):
        saved["path"] = tmp_path / "tasks.json"
        saved["tasks"] = tasks

    monkeypatch.setattr(task_manager_module, "load_tasks", lambda: [])
    monkeypatch.setattr(task_manager_module, "save_tasks", fake_save)

    task_manager_module.add_task(Task(title="Smoke add", status=TaskStatus.ACTIVE))

    assert "tasks" in saved
    assert len(saved["tasks"]) == 1
    assert saved["tasks"][0].title == "Smoke add"


def test_calendar_manager_create_task_event_supports_current_task_model() -> None:
    manager = CalendarManager()

    event = manager.create_task_event(
        Task(title="Task event", status=TaskStatus.ACTIVE),
        datetime(2026, 3, 18, 9, 0),
        1.0,
    )

    assert event.title == "[Task] Task event"
    assert "Task: Task event" in event.description
    assert "Priority: 3" in event.description


def test_scheduler_generation_supports_current_task_model(monkeypatch) -> None:
    class FakeCalendarManager:
        def get_free_time_blocks(self, start_date, end_date, min_duration=0.5):
            return [(start_date, start_date + timedelta(hours=2))]

    monkeypatch.setattr(scheduler_module, "get_preferences", lambda: UserPreferences())
    monkeypatch.setattr(scheduler_module, "get_calendar_manager", lambda: FakeCalendarManager())

    generator = scheduler_module.ScheduleGenerator(
        tasks=[Task(title="Schedule me", status=TaskStatus.ACTIVE)]
    )

    sessions = generator.generate_schedule(
        start_date=datetime(2026, 3, 18, 9, 0),
        days_ahead=1,
    )

    assert len(sessions) == 1
    assert sessions[0].task_title == "Schedule me"
