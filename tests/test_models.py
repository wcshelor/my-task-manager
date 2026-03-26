from datetime import datetime, timedelta

import pytest

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
    ValidationError,
    WorkModeTemplate,
)


def test_model_creation_happy_path() -> None:
    project = Project(name="BERThoven", description="Main project")
    task = Task(
        title="Finish README",
        project_id=project.id,
        status=TaskStatus.ACTIVE,
        due_date=datetime(2026, 3, 25, 12, 0),
        priority_level=PriorityLevel.HIGH,
        energy_level=EnergyLevel.HIGH,
        estimated_minutes=90,
        min_block_minutes=30,
        is_splittable=True,
        tags=["Docs", "docs", " "],
    )
    work_mode = WorkModeTemplate(
        title="Work on BERThoven",
        project_id=project.id,
        default_estimated_minutes=120,
        min_block_minutes=45,
    )
    event = Event(
        title="Doctor Appointment",
        start_time=datetime(2026, 3, 20, 10, 0),
        end_time=datetime(2026, 3, 20, 11, 0),
        source=EventSource.APPLE_CALENDAR,
    )
    block = ScheduledBlock(
        start_time=datetime(2026, 3, 20, 12, 0),
        end_time=datetime(2026, 3, 20, 13, 0),
        source_type=ScheduledBlockSourceType.TASK,
        task_id=task.id,
        creation_method=ScheduledBlockCreationMethod.ACCEPTED_SUGGESTION,
    )

    assert project.name == "BERThoven"
    assert task.tags == ["Docs"]
    assert work_mode.project_id == project.id
    assert event.duration_minutes == 60
    assert block.duration_minutes == 60


def test_task_serialization_roundtrip() -> None:
    task = Task(
        title="Call Burgeramt",
        description="Ask for appointment",
        status=TaskStatus.ACTIVE,
        due_date=datetime(2026, 3, 30, 9, 30),
        priority_level=PriorityLevel.HIGHEST,
        energy_level=EnergyLevel.MEDIUM,
        estimated_minutes=45,
        min_block_minutes=15,
        is_splittable=True,
        is_recurring=True,
        recurrence_rule="FREQ=WEEKLY",
        tags=["Errands"],
    )

    payload = task.to_dict()
    rebuilt = Task.from_dict(payload)

    assert rebuilt.to_dict() == payload
    assert rebuilt.status == TaskStatus.ACTIVE
    assert rebuilt.priority_level == PriorityLevel.HIGHEST


def test_task_deadline_alias_maps_to_due_date() -> None:
    deadline = datetime(2026, 4, 2, 17, 30)
    task = Task(title="Ship report", due_date=deadline)

    assert task.deadline == deadline
    assert task.due_date == deadline

    updated_deadline = datetime(2026, 4, 3, 9, 0)
    task.deadline = updated_deadline

    assert task.deadline == updated_deadline
    assert task.due_date == updated_deadline


def test_task_from_dict_accepts_legacy_deadline_key() -> None:
    task = Task.from_dict(
        {
            "title": "Legacy import",
            "deadline": "2026-04-05T12:00:00",
            "estimatedMinutes": 45,
            "minBlockMinutes": 15,
        }
    )

    assert task.deadline == datetime(2026, 4, 5, 12, 0)


def test_event_serialization_roundtrip() -> None:
    event = Event(
        title="Lecture",
        start_time=datetime(2026, 3, 21, 14, 0),
        end_time=datetime(2026, 3, 21, 16, 30),
        source=EventSource.APPLE_CALENDAR,
        calendar_event_id="abc123",
    )

    payload = event.to_dict()
    rebuilt = Event.from_dict(payload)

    assert rebuilt.to_dict() == payload
    assert rebuilt.duration_minutes == 150


def test_validation_errors() -> None:
    with pytest.raises(ValidationError):
        Task(title="Bad task", estimated_minutes=20, min_block_minutes=30)

    with pytest.raises(ValidationError):
        Task(
            title="Bad recurrence",
            estimated_minutes=30,
            min_block_minutes=15,
            is_recurring=False,
            recurrence_rule="FREQ=DAILY",
        )

    with pytest.raises(ValidationError):
        Event(
            title="Backwards event",
            start_time=datetime(2026, 3, 22, 10, 0),
            end_time=datetime(2026, 3, 22, 9, 0),
            source=EventSource.INTERNAL,
        )

    with pytest.raises(ValidationError):
        ScheduledBlock(
            start_time=datetime(2026, 3, 22, 10, 0),
            end_time=datetime(2026, 3, 22, 11, 0),
            source_type=ScheduledBlockSourceType.TASK,
            work_mode_id="wm-1",
        )


def test_scheduled_block_roundtrip_for_work_mode() -> None:
    now = datetime(2026, 3, 18, 8, 0)
    block = ScheduledBlock(
        start_time=now,
        end_time=now + timedelta(minutes=50),
        source_type=ScheduledBlockSourceType.WORK_MODE,
        work_mode_id="wm-123",
        creation_method=ScheduledBlockCreationMethod.SUGGESTED,
    )

    payload = block.to_dict()
    rebuilt = ScheduledBlock.from_dict(payload)

    assert rebuilt.to_dict() == payload
    assert rebuilt.source_type == ScheduledBlockSourceType.WORK_MODE
