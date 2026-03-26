from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional, Sequence, Tuple

from .gap_detection import TimeInterval
from .models import PriorityLevel, Task, TaskStatus, WorkModeTemplate


class CandidateType(str, Enum):
    TASK = "task"
    WORK_MODE = "workMode"


@dataclass(frozen=True)
class ScoreComponent:
    dimension: str
    score: float
    reason: str


@dataclass(frozen=True)
class PlannerSuggestion:
    candidate_type: CandidateType
    candidate_id: str
    title: str
    project_id: Optional[str]
    start_time: datetime
    end_time: datetime
    scheduled_minutes: int
    total_score: float
    score_components: Tuple[ScoreComponent, ...]


@dataclass(frozen=True)
class CandidateRejection:
    candidate_type: CandidateType
    candidate_id: str
    title: str
    reasons: Tuple[str, ...]


@dataclass(frozen=True)
class PlannerSelectionResult:
    gap: TimeInterval
    ranked_suggestions: Tuple[PlannerSuggestion, ...]
    best_suggestion: Optional[PlannerSuggestion]
    alternatives: Tuple[PlannerSuggestion, ...]
    rejected_candidates: Tuple[CandidateRejection, ...]


_PRIORITY_SCORES = {
    PriorityLevel.HIGHEST: 20.0,
    PriorityLevel.HIGH: 16.0,
    PriorityLevel.MEDIUM: 12.0,
    PriorityLevel.LOW: 8.0,
    PriorityLevel.LOWEST: 4.0,
}


def select_candidates_for_gap(
    gap: TimeInterval,
    tasks: Sequence[Task],
    work_modes: Sequence[WorkModeTemplate],
    now: Optional[datetime] = None,
    max_alternatives: int = 3,
) -> PlannerSelectionResult:
    """
    Rank task/work-mode suggestions for one selected free gap.

    The gap must come from gap detection, which remains the source of free-time computation.
    v0.1 scoring uses only explicit dimensions and does not infer project-level priority.
    """
    reference_time = now or gap.start_time
    available_minutes = _minutes_between(gap.start_time, gap.end_time)
    alternatives_limit = max(0, min(max_alternatives, 3))

    suggestions: list[PlannerSuggestion] = []
    rejections: list[CandidateRejection] = []

    for task in tasks:
        suggestion, rejection = _evaluate_task_candidate(
            task=task,
            gap=gap,
            available_minutes=available_minutes,
            reference_time=reference_time,
        )
        if suggestion:
            suggestions.append(suggestion)
        if rejection:
            rejections.append(rejection)

    for work_mode in work_modes:
        suggestion, rejection = _evaluate_work_mode_candidate(
            work_mode=work_mode,
            gap=gap,
            available_minutes=available_minutes,
        )
        if suggestion:
            suggestions.append(suggestion)
        if rejection:
            rejections.append(rejection)

    ranked_suggestions = tuple(
        sorted(
            suggestions,
            key=lambda item: (-item.total_score, -item.scheduled_minutes, item.title.lower()),
        )
    )
    best_suggestion = ranked_suggestions[0] if ranked_suggestions else None
    alternatives = ranked_suggestions[1 : 1 + alternatives_limit]

    return PlannerSelectionResult(
        gap=gap,
        ranked_suggestions=ranked_suggestions,
        best_suggestion=best_suggestion,
        alternatives=alternatives,
        rejected_candidates=tuple(rejections),
    )


def _evaluate_task_candidate(
    task: Task,
    gap: TimeInterval,
    available_minutes: int,
    reference_time: datetime,
) -> tuple[Optional[PlannerSuggestion], Optional[CandidateRejection]]:
    reasons: list[str] = []

    if task.status != TaskStatus.ACTIVE:
        reasons.append(f"status is '{task.status.value}'")

    if available_minutes < task.min_block_minutes:
        reasons.append(
            f"gap {available_minutes}m is shorter than min block {task.min_block_minutes}m"
        )

    split_needed = task.estimated_minutes > available_minutes
    if split_needed and not task.is_splittable:
        reasons.append(
            "estimated duration exceeds gap and task is not splittable"
        )

    if reasons:
        return None, CandidateRejection(
            candidate_type=CandidateType.TASK,
            candidate_id=task.id,
            title=task.title,
            reasons=tuple(reasons),
        )

    scheduled_minutes = min(task.estimated_minutes, available_minutes)
    if scheduled_minutes < task.min_block_minutes:
        return None, CandidateRejection(
            candidate_type=CandidateType.TASK,
            candidate_id=task.id,
            title=task.title,
            reasons=("scheduled duration is below minimum useful block",),
        )

    components = (
        _urgency_component_for_task(task, reference_time),
        _priority_component(task.priority_level),
        _fit_to_gap_component(scheduled_minutes, available_minutes),
        _min_useful_duration_component(
            scheduled_minutes=scheduled_minutes,
            minimum_minutes=task.min_block_minutes,
            available_minutes=available_minutes,
        ),
        ScoreComponent(
            dimension="work_mode_eligibility",
            score=6.0,
            reason="Task candidate is directly schedulable in this gap",
        ),
        _splittability_component_for_task(split_needed, task.is_splittable),
    )

    total_score = round(sum(component.score for component in components), 2)

    return PlannerSuggestion(
        candidate_type=CandidateType.TASK,
        candidate_id=task.id,
        title=task.title,
        project_id=task.project_id,
        start_time=gap.start_time,
        end_time=gap.start_time + timedelta(minutes=scheduled_minutes),
        scheduled_minutes=scheduled_minutes,
        total_score=total_score,
        score_components=components,
    ), None


def _evaluate_work_mode_candidate(
    work_mode: WorkModeTemplate,
    gap: TimeInterval,
    available_minutes: int,
) -> tuple[Optional[PlannerSuggestion], Optional[CandidateRejection]]:
    reasons: list[str] = []

    if not work_mode.is_active:
        reasons.append("work mode is inactive")

    if available_minutes < work_mode.min_block_minutes:
        reasons.append(
            f"gap {available_minutes}m is shorter than min block {work_mode.min_block_minutes}m"
        )

    if reasons:
        return None, CandidateRejection(
            candidate_type=CandidateType.WORK_MODE,
            candidate_id=work_mode.id,
            title=work_mode.title,
            reasons=tuple(reasons),
        )

    scheduled_minutes = min(work_mode.default_estimated_minutes, available_minutes)
    if scheduled_minutes < work_mode.min_block_minutes:
        return None, CandidateRejection(
            candidate_type=CandidateType.WORK_MODE,
            candidate_id=work_mode.id,
            title=work_mode.title,
            reasons=("scheduled duration is below minimum useful block",),
        )

    components = (
        _urgency_component_for_work_mode(),
        _priority_component(work_mode.priority_level),
        _fit_to_gap_component(scheduled_minutes, available_minutes),
        _min_useful_duration_component(
            scheduled_minutes=scheduled_minutes,
            minimum_minutes=work_mode.min_block_minutes,
            available_minutes=available_minutes,
        ),
        ScoreComponent(
            dimension="work_mode_eligibility",
            score=10.0,
            reason="Active work mode template is eligible",
        ),
        _splittability_component_for_work_mode(
            default_minutes=work_mode.default_estimated_minutes,
            available_minutes=available_minutes,
        ),
    )

    total_score = round(sum(component.score for component in components), 2)

    return PlannerSuggestion(
        candidate_type=CandidateType.WORK_MODE,
        candidate_id=work_mode.id,
        title=work_mode.title,
        project_id=work_mode.project_id,
        start_time=gap.start_time,
        end_time=gap.start_time + timedelta(minutes=scheduled_minutes),
        scheduled_minutes=scheduled_minutes,
        total_score=total_score,
        score_components=components,
    ), None


def _priority_component(priority_level: PriorityLevel) -> ScoreComponent:
    return ScoreComponent(
        dimension="priority_level",
        score=_PRIORITY_SCORES[priority_level],
        reason=f"Priority {priority_level.name.lower()}",
    )


def _urgency_component_for_task(task: Task, reference_time: datetime) -> ScoreComponent:
    if task.due_date is None:
        return ScoreComponent(
            dimension="urgency_due_date",
            score=10.0,
            reason="No due date set",
        )

    hours_to_due = (task.due_date - reference_time).total_seconds() / 3600

    if hours_to_due <= 0:
        return ScoreComponent(
            dimension="urgency_due_date",
            score=30.0,
            reason="Overdue task",
        )
    if hours_to_due <= 24:
        return ScoreComponent(
            dimension="urgency_due_date",
            score=26.0,
            reason="Due within 24 hours",
        )
    if hours_to_due <= 72:
        return ScoreComponent(
            dimension="urgency_due_date",
            score=22.0,
            reason="Due within 3 days",
        )
    if hours_to_due <= 168:
        return ScoreComponent(
            dimension="urgency_due_date",
            score=16.0,
            reason="Due within 7 days",
        )
    return ScoreComponent(
        dimension="urgency_due_date",
        score=8.0,
        reason="Due later than 7 days",
    )


def _urgency_component_for_work_mode() -> ScoreComponent:
    return ScoreComponent(
        dimension="urgency_due_date",
        score=6.0,
        reason="Work modes have no due date in v0.1",
    )


def _fit_to_gap_component(scheduled_minutes: int, available_minutes: int) -> ScoreComponent:
    fill_ratio = scheduled_minutes / available_minutes
    score = round(20.0 * fill_ratio, 2)
    return ScoreComponent(
        dimension="fit_to_gap",
        score=score,
        reason=f"Uses {scheduled_minutes} of {available_minutes} minutes in the gap",
    )


def _min_useful_duration_component(
    scheduled_minutes: int,
    minimum_minutes: int,
    available_minutes: int,
) -> ScoreComponent:
    if available_minutes <= minimum_minutes:
        score = 10.0
    else:
        usable_ratio = (scheduled_minutes - minimum_minutes) / (available_minutes - minimum_minutes)
        usable_ratio = max(0.0, min(1.0, usable_ratio))
        score = round(6.0 + (4.0 * usable_ratio), 2)

    return ScoreComponent(
        dimension="minimum_useful_duration",
        score=score,
        reason=f"Minimum useful block {minimum_minutes} minutes",
    )


def _splittability_component_for_task(split_needed: bool, is_splittable: bool) -> ScoreComponent:
    if split_needed and is_splittable:
        return ScoreComponent(
            dimension="splittability",
            score=7.0,
            reason="Task can be split to fit this gap",
        )
    if not split_needed and is_splittable:
        return ScoreComponent(
            dimension="splittability",
            score=9.0,
            reason="Fits in one block and can still be split later if needed",
        )
    return ScoreComponent(
        dimension="splittability",
        score=8.0,
        reason="Fits in one block without splitting",
    )


def _splittability_component_for_work_mode(
    default_minutes: int,
    available_minutes: int,
) -> ScoreComponent:
    if default_minutes > available_minutes:
        return ScoreComponent(
            dimension="splittability",
            score=7.0,
            reason="Template session trimmed to fit the selected gap",
        )
    return ScoreComponent(
        dimension="splittability",
        score=9.0,
        reason="Template duration fits fully in this gap",
    )


def _minutes_between(start_time: datetime, end_time: datetime) -> int:
    return int((end_time - start_time).total_seconds() // 60)
