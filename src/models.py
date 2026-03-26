from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, time
from enum import Enum, IntEnum
from typing import Any, Dict, List, Optional, Set
from uuid import uuid4


class ValidationError(ValueError):
    """Raised when a model instance fails lightweight validation."""


class StrEnum(str, Enum):
    """Simple string enum helper for readable JSON serialization."""


class TaskStatus(StrEnum):
    INBOX = "inbox"
    ACTIVE = "active"
    DONE = "done"
    ARCHIVED = "archived"


class PriorityLevel(IntEnum):
    HIGHEST = 1
    HIGH = 2
    MEDIUM = 3
    LOW = 4
    LOWEST = 5


class EnergyLevel(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class EventSource(StrEnum):
    APPLE_CALENDAR = "appleCalendar"
    INTERNAL = "internal"


class ScheduledBlockSourceType(StrEnum):
    TASK = "task"
    WORK_MODE = "workMode"


class ScheduledBlockCreationMethod(StrEnum):
    MANUAL = "manual"
    SUGGESTED = "suggested"
    ACCEPTED_SUGGESTION = "acceptedSuggestion"


def _new_id() -> str:
    return str(uuid4())


def _parse_datetime(value: Optional[str]) -> Optional[datetime]:
    if value is None:
        return None
    return datetime.fromisoformat(value)


def _coerce_datetime(value: Optional[date | datetime], field_name: str) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime.combine(value, time.min)
    raise ValidationError(f"{field_name} must be a date or datetime")


def _required_non_empty(value: str, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValidationError(f"{field_name} must be a non-empty string")
    return normalized


def _validate_positive_minutes(value: int, field_name: str) -> int:
    if value <= 0:
        raise ValidationError(f"{field_name} must be greater than 0")
    return value


def _parse_legacy_hours(value: Any, field_name: str) -> int:
    try:
        hours = float(value)
    except (TypeError, ValueError) as exc:
        raise ValidationError(f"{field_name} must be numeric") from exc
    if hours <= 0:
        raise ValidationError(f"{field_name} must be greater than 0")
    return max(1, int(round(hours * 60)))


def _coerce_non_negative_float(value: Any, field_name: str, default: float = 0.0) -> float:
    if value is None:
        return default
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValidationError(f"{field_name} must be numeric") from exc
    if number < 0:
        raise ValidationError(f"{field_name} cannot be negative")
    return number


def _coerce_non_negative_int(value: Any, field_name: str, default: int = 0) -> int:
    if value is None:
        return default
    try:
        number = int(value)
    except (TypeError, ValueError) as exc:
        raise ValidationError(f"{field_name} must be an integer") from exc
    if number < 0:
        raise ValidationError(f"{field_name} cannot be negative")
    return number


def _energy_level_from_legacy_effort(value: Any) -> EnergyLevel:
    normalized = str(value).strip().lower()
    mapping = {
        "low": EnergyLevel.LOW,
        "medium": EnergyLevel.MEDIUM,
        "high": EnergyLevel.HIGH,
    }
    if normalized not in mapping:
        raise ValidationError("Task.effort must be one of: Low, Medium, High")
    return mapping[normalized]


def _normalize_tags(tags: List[str]) -> List[str]:
    normalized: List[str] = []
    seen: Set[str] = set()
    for tag in tags:
        candidate = tag.strip()
        if not candidate:
            continue
        lowered = candidate.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        normalized.append(candidate)
    return normalized


@dataclass
class Project:
    name: str
    id: str = field(default_factory=_new_id)
    description: Optional[str] = None
    color: Optional[str] = None
    is_active: bool = True

    def __post_init__(self) -> None:
        self.name = _required_non_empty(self.name, "Project.name")
        if self.description is not None:
            self.description = self.description.strip() or None
        if self.color is not None:
            self.color = self.color.strip() or None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "color": self.color,
            "isActive": self.is_active,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Project":
        return cls(
            id=data.get("id", _new_id()),
            name=data["name"],
            description=data.get("description"),
            color=data.get("color"),
            is_active=data.get("isActive", True),
        )


@dataclass
class Task:
    title: str
    id: str = field(default_factory=_new_id)
    description: Optional[str] = None
    status: TaskStatus = TaskStatus.INBOX
    project_id: Optional[str] = None
    parent_task_id: Optional[str] = None
    due_date: Optional[datetime] = None
    priority_level: PriorityLevel = PriorityLevel.MEDIUM
    energy_level: EnergyLevel = EnergyLevel.MEDIUM
    estimated_minutes: int = 30
    min_block_minutes: int = 15
    is_splittable: bool = True
    is_recurring: bool = False
    recurrence_rule: Optional[str] = None
    tags: List[str] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    max_sessions: int = 1
    actual_time_spent: float = 0.0
    sessions_completed: int = 0
    category: str = "Work"

    def __post_init__(self) -> None:
        self.title = _required_non_empty(self.title, "Task.title")
        if self.description is not None:
            self.description = self.description.strip() or None

        self.due_date = _coerce_datetime(self.due_date, "Task.due_date")

        self.estimated_minutes = _validate_positive_minutes(self.estimated_minutes, "Task.estimated_minutes")
        self.min_block_minutes = _validate_positive_minutes(self.min_block_minutes, "Task.min_block_minutes")
        if self.min_block_minutes > self.estimated_minutes:
            raise ValidationError("Task.min_block_minutes cannot exceed Task.estimated_minutes")

        if not isinstance(self.status, TaskStatus):
            self.status = TaskStatus(self.status)
        if not isinstance(self.priority_level, PriorityLevel):
            self.priority_level = PriorityLevel(self.priority_level)
        if not isinstance(self.energy_level, EnergyLevel):
            self.energy_level = EnergyLevel(self.energy_level)

        if self.project_id is not None:
            self.project_id = self.project_id.strip() or None
        if self.parent_task_id is not None:
            self.parent_task_id = self.parent_task_id.strip() or None

        if self.recurrence_rule is not None:
            self.recurrence_rule = self.recurrence_rule.strip() or None
            if not self.is_recurring:
                raise ValidationError("Task.recurrence_rule requires Task.is_recurring=True")

        self.tags = _normalize_tags(self.tags or [])
        self.dependencies = [
            str(dep).strip() for dep in (self.dependencies or []) if str(dep).strip()
        ]
        self.max_sessions = _coerce_non_negative_int(self.max_sessions, "Task.max_sessions", default=1)
        if self.max_sessions == 0:
            raise ValidationError("Task.max_sessions must be greater than 0")
        self.actual_time_spent = _coerce_non_negative_float(
            self.actual_time_spent,
            "Task.actual_time_spent",
            default=0.0,
        )
        self.sessions_completed = _coerce_non_negative_int(
            self.sessions_completed,
            "Task.sessions_completed",
            default=0,
        )
        self.category = (self.category or "").strip() or "Work"

    @property
    def deadline(self) -> Optional[datetime]:
        return self.due_date

    @deadline.setter
    def deadline(self, value: Optional[date | datetime]) -> None:
        self.due_date = _coerce_datetime(value, "Task.deadline")

    @property
    def notes(self) -> str:
        return self.description or ""

    @notes.setter
    def notes(self, value: Optional[str]) -> None:
        self.description = (value or "").strip() or None

    @property
    def completed(self) -> bool:
        return self.status == TaskStatus.DONE

    @completed.setter
    def completed(self, value: bool) -> None:
        self.status = TaskStatus.DONE if value else TaskStatus.ACTIVE

    @property
    def priority(self) -> int:
        return int(self.priority_level)

    @priority.setter
    def priority(self, value: int) -> None:
        self.priority_level = PriorityLevel(value)

    @property
    def effort(self) -> str:
        return self.energy_level.value.title()

    @effort.setter
    def effort(self, value: str) -> None:
        self.energy_level = _energy_level_from_legacy_effort(value)

    @property
    def est_time(self) -> float:
        return self.estimated_minutes / 60

    @est_time.setter
    def est_time(self, value: float) -> None:
        self.estimated_minutes = _parse_legacy_hours(value, "Task.est_time")
        if self.min_block_minutes > self.estimated_minutes:
            self.min_block_minutes = self.estimated_minutes

    @property
    def min_session_time(self) -> float:
        return self.min_block_minutes / 60

    @min_session_time.setter
    def min_session_time(self, value: float) -> None:
        self.min_block_minutes = min(
            _parse_legacy_hours(value, "Task.min_session_time"),
            self.estimated_minutes,
        )

    def get_remaining_time(self) -> float:
        return max(self.est_time - self.actual_time_spent, 0.0)

    def get_next_session_time(self) -> float:
        remaining = self.get_remaining_time()
        if not self.is_splittable:
            return remaining
        return min(remaining, self.min_session_time) if remaining else 0.0

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "status": self.status.value,
            "projectId": self.project_id,
            "parentTaskId": self.parent_task_id,
            "dueDate": self.due_date.isoformat() if self.due_date else None,
            "priorityLevel": int(self.priority_level),
            "energyLevel": self.energy_level.value,
            "estimatedMinutes": self.estimated_minutes,
            "minBlockMinutes": self.min_block_minutes,
            "isSplittable": self.is_splittable,
            "isRecurring": self.is_recurring,
            "recurrenceRule": self.recurrence_rule,
            "tags": self.tags,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Task":
        raw_due_date = data.get("dueDate", data.get("deadline"))
        legacy_completed = data.get("completed")
        raw_status = data.get("status")
        if raw_status is None:
            raw_status = TaskStatus.DONE.value if legacy_completed else TaskStatus.ACTIVE.value

        raw_priority = data.get("priorityLevel")
        if raw_priority is None:
            raw_priority = data.get("priority", PriorityLevel.MEDIUM)

        raw_energy = data.get("energyLevel")
        if raw_energy is None and "effort" in data:
            raw_energy = _energy_level_from_legacy_effort(data["effort"]).value
        if raw_energy is None:
            raw_energy = EnergyLevel.MEDIUM.value

        raw_estimated_minutes = data.get("estimatedMinutes")
        if raw_estimated_minutes is None and "est_time" in data:
            raw_estimated_minutes = _parse_legacy_hours(data["est_time"], "Task.est_time")
        if raw_estimated_minutes is None:
            raw_estimated_minutes = 30

        raw_min_block_minutes = data.get("minBlockMinutes")
        if raw_min_block_minutes is None and "min_session_time" in data:
            raw_min_block_minutes = _parse_legacy_hours(
                data["min_session_time"],
                "Task.min_session_time",
            )
        if raw_min_block_minutes is None:
            raw_min_block_minutes = 15

        description = data.get("description")
        if description is None and "notes" in data:
            description = data.get("notes")

        return cls(
            id=data.get("id", _new_id()),
            title=data["title"],
            description=description,
            status=TaskStatus(raw_status),
            project_id=data.get("projectId"),
            parent_task_id=data.get("parentTaskId"),
            due_date=_parse_datetime(raw_due_date),
            priority_level=PriorityLevel(raw_priority),
            energy_level=EnergyLevel(raw_energy),
            estimated_minutes=raw_estimated_minutes,
            min_block_minutes=min(raw_min_block_minutes, raw_estimated_minutes),
            is_splittable=data.get("isSplittable", data.get("is_splittable", True)),
            is_recurring=data.get("isRecurring", False),
            recurrence_rule=data.get("recurrenceRule"),
            tags=data.get("tags", []),
            dependencies=data.get("dependencies", []),
            max_sessions=data.get("max_sessions", 1),
            actual_time_spent=data.get("actual_time_spent", 0.0),
            sessions_completed=data.get("sessions_completed", 0),
            category=data.get("category", "Work"),
        )


@dataclass
class WorkModeTemplate:
    title: str
    id: str = field(default_factory=_new_id)
    description: Optional[str] = None
    project_id: Optional[str] = None
    default_estimated_minutes: int = 30
    min_block_minutes: int = 15
    priority_level: PriorityLevel = PriorityLevel.MEDIUM
    energy_level: EnergyLevel = EnergyLevel.MEDIUM
    tags: List[str] = field(default_factory=list)
    is_active: bool = True

    def __post_init__(self) -> None:
        self.title = _required_non_empty(self.title, "WorkModeTemplate.title")
        if self.description is not None:
            self.description = self.description.strip() or None
        if self.project_id is not None:
            self.project_id = self.project_id.strip() or None

        self.default_estimated_minutes = _validate_positive_minutes(
            self.default_estimated_minutes,
            "WorkModeTemplate.default_estimated_minutes",
        )
        self.min_block_minutes = _validate_positive_minutes(
            self.min_block_minutes,
            "WorkModeTemplate.min_block_minutes",
        )
        if self.min_block_minutes > self.default_estimated_minutes:
            raise ValidationError(
                "WorkModeTemplate.min_block_minutes cannot exceed default_estimated_minutes"
            )

        if not isinstance(self.priority_level, PriorityLevel):
            self.priority_level = PriorityLevel(self.priority_level)
        if not isinstance(self.energy_level, EnergyLevel):
            self.energy_level = EnergyLevel(self.energy_level)

        self.tags = _normalize_tags(self.tags)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "projectId": self.project_id,
            "defaultEstimatedMinutes": self.default_estimated_minutes,
            "minBlockMinutes": self.min_block_minutes,
            "priorityLevel": int(self.priority_level),
            "energyLevel": self.energy_level.value,
            "tags": self.tags,
            "isActive": self.is_active,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "WorkModeTemplate":
        return cls(
            id=data.get("id", _new_id()),
            title=data["title"],
            description=data.get("description"),
            project_id=data.get("projectId"),
            default_estimated_minutes=data.get("defaultEstimatedMinutes", 30),
            min_block_minutes=data.get("minBlockMinutes", 15),
            priority_level=PriorityLevel(data.get("priorityLevel", PriorityLevel.MEDIUM)),
            energy_level=EnergyLevel(data.get("energyLevel", EnergyLevel.MEDIUM.value)),
            tags=data.get("tags", []),
            is_active=data.get("isActive", True),
        )


@dataclass
class Event:
    title: str
    start_time: datetime
    end_time: datetime
    source: EventSource
    id: str = field(default_factory=_new_id)
    calendar_event_id: Optional[str] = None

    def __post_init__(self) -> None:
        self.title = _required_non_empty(self.title, "Event.title")
        if self.end_time <= self.start_time:
            raise ValidationError("Event.end_time must be after Event.start_time")
        if not isinstance(self.source, EventSource):
            self.source = EventSource(self.source)
        if self.calendar_event_id is not None:
            self.calendar_event_id = self.calendar_event_id.strip() or None

    @property
    def duration_minutes(self) -> int:
        return int((self.end_time - self.start_time).total_seconds() // 60)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "startTime": self.start_time.isoformat(),
            "endTime": self.end_time.isoformat(),
            "source": self.source.value,
            "calendarEventId": self.calendar_event_id,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Event":
        return cls(
            id=data.get("id", _new_id()),
            title=data["title"],
            start_time=datetime.fromisoformat(data["startTime"]),
            end_time=datetime.fromisoformat(data["endTime"]),
            source=EventSource(data["source"]),
            calendar_event_id=data.get("calendarEventId"),
        )


@dataclass
class ScheduledBlock:
    start_time: datetime
    end_time: datetime
    source_type: ScheduledBlockSourceType
    id: str = field(default_factory=_new_id)
    task_id: Optional[str] = None
    work_mode_id: Optional[str] = None
    calendar_event_id: Optional[str] = None
    creation_method: ScheduledBlockCreationMethod = ScheduledBlockCreationMethod.SUGGESTED

    def __post_init__(self) -> None:
        if self.end_time <= self.start_time:
            raise ValidationError("ScheduledBlock.end_time must be after start_time")
        if not isinstance(self.source_type, ScheduledBlockSourceType):
            self.source_type = ScheduledBlockSourceType(self.source_type)
        if not isinstance(self.creation_method, ScheduledBlockCreationMethod):
            self.creation_method = ScheduledBlockCreationMethod(self.creation_method)

        if self.task_id is not None:
            self.task_id = self.task_id.strip() or None
        if self.work_mode_id is not None:
            self.work_mode_id = self.work_mode_id.strip() or None
        if self.calendar_event_id is not None:
            self.calendar_event_id = self.calendar_event_id.strip() or None

        if self.source_type == ScheduledBlockSourceType.TASK:
            if not self.task_id:
                raise ValidationError("ScheduledBlock.task_id is required when source_type='task'")
            if self.work_mode_id:
                raise ValidationError("ScheduledBlock.work_mode_id must be empty when source_type='task'")
        else:
            if not self.work_mode_id:
                raise ValidationError("ScheduledBlock.work_mode_id is required when source_type='workMode'")
            if self.task_id:
                raise ValidationError("ScheduledBlock.task_id must be empty when source_type='workMode'")

    @property
    def duration_minutes(self) -> int:
        return int((self.end_time - self.start_time).total_seconds() // 60)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "startTime": self.start_time.isoformat(),
            "endTime": self.end_time.isoformat(),
            "sourceType": self.source_type.value,
            "taskId": self.task_id,
            "workModeId": self.work_mode_id,
            "calendarEventId": self.calendar_event_id,
            "creationMethod": self.creation_method.value,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ScheduledBlock":
        return cls(
            id=data.get("id", _new_id()),
            start_time=datetime.fromisoformat(data["startTime"]),
            end_time=datetime.fromisoformat(data["endTime"]),
            source_type=ScheduledBlockSourceType(data["sourceType"]),
            task_id=data.get("taskId"),
            work_mode_id=data.get("workModeId"),
            calendar_event_id=data.get("calendarEventId"),
            creation_method=ScheduledBlockCreationMethod(
                data.get("creationMethod", ScheduledBlockCreationMethod.SUGGESTED.value)
            ),
        )


# Compatibility model retained because existing repository modules import it.
@dataclass
class UserPreferences:
    working_hours_start: int = 9
    working_hours_end: int = 17
    work_days: Set[int] = field(default_factory=lambda: {0, 1, 2, 3, 4})
    prefer_focused_work: bool = True
    max_work_duration: float = 2.0
    break_duration: float = 0.25
    sync_with_apple_calendar: bool = False
    default_task_priority: int = 2
    default_task_is_splittable: bool = True
    default_task_max_sessions: int = 3
    default_task_min_session_time: float = 0.5
