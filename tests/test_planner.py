from datetime import datetime, timedelta

from src.gap_detection import TimeInterval
from src.models import PriorityLevel, Task, TaskStatus, WorkModeTemplate
from src.planner import CandidateType, select_candidates_for_gap


def _gap(start_hour: int, end_hour: int) -> TimeInterval:
    return TimeInterval(
        start_time=datetime(2026, 3, 18, start_hour, 0),
        end_time=datetime(2026, 3, 18, end_hour, 0),
    )


def test_select_candidates_filters_ineligible_items() -> None:
    gap = _gap(9, 10)
    tasks = [
        Task(
            title="Done Task",
            status=TaskStatus.DONE,
            estimated_minutes=30,
            min_block_minutes=15,
        ),
        Task(
            title="Too Large Unsplittable",
            status=TaskStatus.ACTIVE,
            estimated_minutes=120,
            min_block_minutes=30,
            is_splittable=False,
        ),
        Task(
            title="Split Candidate",
            status=TaskStatus.ACTIVE,
            estimated_minutes=120,
            min_block_minutes=30,
            is_splittable=True,
        ),
    ]
    work_modes = [
        WorkModeTemplate(
            title="Inactive Mode",
            default_estimated_minutes=30,
            min_block_minutes=15,
            is_active=False,
        )
    ]

    result = select_candidates_for_gap(gap, tasks, work_modes)

    assert len(result.ranked_suggestions) == 1
    assert result.best_suggestion is not None
    assert result.best_suggestion.title == "Split Candidate"
    assert len(result.rejected_candidates) == 3


def test_select_candidates_prioritizes_urgent_deadline() -> None:
    now = datetime(2026, 3, 18, 8, 0)
    gap = TimeInterval(start_time=now, end_time=now + timedelta(hours=2))

    tasks = [
        Task(
            title="High Priority Later",
            status=TaskStatus.ACTIVE,
            priority_level=PriorityLevel.HIGHEST,
            due_date=now + timedelta(days=10),
            estimated_minutes=60,
            min_block_minutes=15,
        ),
        Task(
            title="Soon Due",
            status=TaskStatus.ACTIVE,
            priority_level=PriorityLevel.MEDIUM,
            due_date=now + timedelta(hours=12),
            estimated_minutes=60,
            min_block_minutes=15,
        ),
    ]

    result = select_candidates_for_gap(gap, tasks, [])

    assert result.best_suggestion is not None
    assert result.best_suggestion.title == "Soon Due"


def test_select_candidates_returns_best_and_three_alternatives() -> None:
    gap = _gap(9, 11)
    tasks = [
        Task(
            title="Task A",
            status=TaskStatus.ACTIVE,
            estimated_minutes=90,
            min_block_minutes=30,
            priority_level=PriorityLevel.HIGH,
        ),
        Task(
            title="Task B",
            status=TaskStatus.ACTIVE,
            estimated_minutes=60,
            min_block_minutes=30,
            priority_level=PriorityLevel.MEDIUM,
        ),
        Task(
            title="Task C",
            status=TaskStatus.ACTIVE,
            estimated_minutes=30,
            min_block_minutes=15,
            priority_level=PriorityLevel.LOW,
        ),
    ]
    work_modes = [
        WorkModeTemplate(
            title="Focus Mode",
            default_estimated_minutes=120,
            min_block_minutes=30,
            priority_level=PriorityLevel.MEDIUM,
            is_active=True,
        )
    ]

    result = select_candidates_for_gap(gap, tasks, work_modes)

    assert result.best_suggestion is not None
    assert len(result.ranked_suggestions) == 4
    assert len(result.alternatives) == 3

    expected_dimensions = {
        "urgency_due_date",
        "priority_level",
        "fit_to_gap",
        "minimum_useful_duration",
        "work_mode_eligibility",
        "splittability",
    }
    for suggestion in result.ranked_suggestions:
        dimensions = {item.dimension for item in suggestion.score_components}
        assert dimensions == expected_dimensions
        assert all(item.reason for item in suggestion.score_components)


def test_select_candidates_returns_empty_when_gap_too_short() -> None:
    # TimeInterval validation requires positive range, so use 9:00-9:20.
    gap = TimeInterval(
        start_time=datetime(2026, 3, 18, 9, 0),
        end_time=datetime(2026, 3, 18, 9, 20),
    )
    tasks = [
        Task(
            title="Task Needs 30m",
            status=TaskStatus.ACTIVE,
            estimated_minutes=30,
            min_block_minutes=30,
        )
    ]
    work_modes = [
        WorkModeTemplate(
            title="Mode Needs 30m",
            default_estimated_minutes=45,
            min_block_minutes=30,
            is_active=True,
        )
    ]

    result = select_candidates_for_gap(gap, tasks, work_modes)

    assert result.best_suggestion is None
    assert result.ranked_suggestions == ()
    assert result.alternatives == ()
    assert len(result.rejected_candidates) == 2


def test_select_candidates_does_not_use_project_membership_for_scoring() -> None:
    now = datetime(2026, 3, 18, 9, 0)
    gap = TimeInterval(start_time=now, end_time=now + timedelta(hours=2))

    tasks = []
    work_modes = [
        WorkModeTemplate(
            title="Backend Focus",
            project_id="project-backend",
            default_estimated_minutes=60,
            min_block_minutes=30,
            priority_level=PriorityLevel.MEDIUM,
            is_active=True,
        ),
        WorkModeTemplate(
            title="Docs Focus",
            project_id="project-docs",
            default_estimated_minutes=60,
            min_block_minutes=30,
            priority_level=PriorityLevel.MEDIUM,
            is_active=True,
        ),
    ]

    result = select_candidates_for_gap(gap, tasks, work_modes, now=now)
    work_mode_scores = {
        suggestion.title: suggestion.total_score
        for suggestion in result.ranked_suggestions
        if suggestion.candidate_type == CandidateType.WORK_MODE
    }

    assert work_mode_scores["Backend Focus"] == work_mode_scores["Docs Focus"]
