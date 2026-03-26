#!/usr/bin/env python3
# src/scheduler.py
from datetime import datetime, timedelta
from typing import List, Dict, Tuple, Optional, Any
import heapq
from dataclasses import dataclass

from .models import Task, TaskStatus, UserPreferences
from .calendar_manager import CalendarEvent, get_calendar_manager
from .preferences import get_preferences
from .task_manager import list_tasks

@dataclass
class TaskSession:
    """Represents a scheduled session for a task"""
    task_id: str
    task_title: str
    start_time: datetime
    end_time: datetime
    session_number: int = 1
    is_break: bool = False
    
    @property
    def duration_hours(self) -> float:
        """Get session duration in hours"""
        return (self.end_time - self.start_time).total_seconds() / 3600
        
    def to_calendar_event(self) -> CalendarEvent:
        """Convert task session to calendar event"""
        title = "[Break]" if self.is_break else f"{self.task_title}"
        description = "Scheduled break" if self.is_break else f"Session {self.session_number}"
        
        return CalendarEvent(
            title=title,
            start_time=self.start_time,
            end_time=self.end_time,
            description=description,
            is_task_event=not self.is_break,
            task_id=self.task_id if not self.is_break else None,
            is_suggestion=True
        )


class ScheduleGenerator:
    """Generates optimized schedules based on tasks and free time blocks"""
    
    def __init__(self, tasks=None, start_date=None, end_date=None):
        # Use default values if parameters not provided
        self.tasks = tasks if tasks is not None else list_tasks()
        self.start_date = start_date if start_date is not None else datetime.now()
        self.end_date = end_date if end_date is not None else (datetime.now() + timedelta(days=7))
        self.preferences = get_preferences()
        self.calendar = get_calendar_manager()
        
        # Track accumulated mental effort for each day
        self.daily_effort = {}  # key: date string, value: accumulated effort
        
        # User task sequencing preference (True = prefer similar tasks consecutively)
        self.prefer_similar_tasks = False
        
        # Last scheduled task category (for task sequencing)
        self.last_task_category = None
        
    def generate_schedule(self, tasks=None, start_date=None, days_ahead=7, prefer_similar_tasks=False) -> List[TaskSession]:
        """Generate an optimized schedule of task sessions"""
        # Update parameters if provided
        if tasks is not None:
            self.tasks = tasks
        if start_date is not None:
            self.start_date = start_date
        if days_ahead is not None:
            self.end_date = self.start_date + timedelta(days=days_ahead)
            
        self.prefer_similar_tasks = prefer_similar_tasks
        self.daily_effort = {}
        self.last_task_category = None
        
        # Get all available time blocks
        free_blocks = self.calendar.get_free_time_blocks(
            self.start_date, 
            self.end_date,
            min_duration=0.25  # Consider blocks of at least 15 minutes
        )
        
        # Filter to non-completed, non-blocked tasks
        available_tasks = [
            t
            for t in self.tasks
            if t.status == TaskStatus.ACTIVE and t.get_remaining_time() > 0 and not self._is_blocked(t)
        ]
        
        # Schedule tasks into time blocks
        scheduled_sessions = []
        
        # Sort blocks chronologically
        free_blocks.sort(key=lambda block: block[0])  
        
        for block_start, block_end in free_blocks:
            # Get the date string for tracking daily effort
            day_key = block_start.strftime("%Y-%m-%d")
            if day_key not in self.daily_effort:
                self.daily_effort[day_key] = 0.0
                
            # Get block size in hours
            block_size = (block_end - block_start).total_seconds() / 3600
            
            # Skip blocks that are too small (less than 15 minutes)
            if block_size < 0.25:
                continue
                
            # Calculate block score - lower score means "fresher" mental state
            block_score = self._calculate_block_score(block_start, self.daily_effort[day_key])
            
            # Get best task for this block
            best_task, duration = self._find_best_task_for_block(
                available_tasks, 
                block_start, 
                block_size, 
                block_score
            )
            
            if best_task:
                # Create a session for this task
                session_count = best_task.sessions_completed + 1
                end_time = block_start + timedelta(hours=duration)
                
                session = TaskSession(
                    task_id=best_task.id,
                    task_title=best_task.title,
                    start_time=block_start,
                    end_time=end_time,
                    session_number=session_count
                )
                scheduled_sessions.append(session)
                
                # Update task state
                best_task.sessions_completed += 1
                best_task.actual_time_spent += duration
                
                # Update accumulated effort for the day
                effort_value = self._get_effort_value(best_task.effort)
                self.daily_effort[day_key] += effort_value * duration
                
                # Update last category
                self.last_task_category = best_task.category
                
                # Add break if needed and if there's time left
                remaining_time = block_size - duration
                if (remaining_time >= self.preferences.break_duration and 
                    duration >= self.preferences.max_work_duration):
                    
                    # Add a break
                    break_start = end_time
                    break_end = break_start + timedelta(hours=self.preferences.break_duration)
                    
                    # But make sure the break doesn't exceed the block end time
                    if break_end <= block_end:
                        break_session = TaskSession(
                            task_id="",
                            task_title="Break",
                            start_time=break_start,
                            end_time=break_end,
                            is_break=True
                        )
                        scheduled_sessions.append(break_session)
                        
                        # Adjust the next potential start time
                        block_start = break_end
                        block_size = (block_end - block_start).total_seconds() / 3600
                    
                    # We could potentially fit another task after the break,
                    # but for simplicity, we'll stop here for now
                
                # If task is now complete, remove from available tasks
                if best_task.actual_time_spent >= best_task.est_time:
                    best_task.status = TaskStatus.DONE
                    available_tasks.remove(best_task)
                    
                    # Recalculate which tasks are now unblocked
                    for task in list(available_tasks):
                        if not self._is_blocked(task):
                            continue
                        if not self._is_blocked(task, ignore_recently_completed=True):
                            # This task was just unblocked
                            pass  # Could add some bonus points for newly unblocked tasks
            
        return scheduled_sessions
                    
    def _calculate_block_score(self, block_time: datetime, accumulated_effort: float) -> float:
        """
        Calculate a score for a time block based on accumulated mental effort
        Lower score is better (represents "fresher" mental state)
        """
        # Base score is the accumulated effort so far
        score = accumulated_effort
        
        # Consider time of day (assumes people are fresher in the morning)
        hour = block_time.hour
        if 8 <= hour <= 11:  # Morning hours get a bonus
            score -= 1.0
        elif 14 <= hour <= 16:  # Post-lunch dip penalty
            score += 1.0
            
        return max(0, score)  # Ensure score is never negative
        
    def _find_best_task_for_block(
        self, 
        tasks: List[Task], 
        block_start: datetime, 
        block_size: float,
        block_score: float
    ) -> Tuple[Optional[Task], float]:
        """
        Find the best task for a given time block
        Returns (best_task, duration) or (None, 0) if no suitable task
        """
        if not tasks:
            return None, 0
            
        # Calculate scores for each task
        task_scores = []
        for i, task in enumerate(tasks):
            # Skip tasks that can't fit in this block (unless splittable)
            next_session_time = task.get_next_session_time()
            
            if next_session_time > block_size and not task.is_splittable:
                continue
                
            # Determine duration for this task's session
            duration = min(next_session_time, block_size)
            if task.is_splittable:
                duration = min(duration, task.min_session_time)
                duration = max(0.25, duration)  # Minimum 15 minutes
                
            # Calculate task score (higher is better)
            score = self._calculate_task_score(task, block_start, block_score)
            
            # Create a tuple (negative score for max-heap, unique index, task, duration)
            # Using unique index to prevent comparing Task objects directly
            task_scores.append((-score, i, task, duration))
            
        if not task_scores:
            return None, 0
            
        # Find task with highest score
        heapq.heapify(task_scores)
        neg_score, _, best_task, duration = heapq.heappop(task_scores)
        
        return best_task, duration
        
    def _calculate_task_score(self, task: Task, block_time: datetime, block_score: float) -> float:
        """
        Calculate a score for a task based on various factors
        Higher score means the task is more suitable for scheduling
        """
        # Start with priority as base score (inverted: 1=highest, 5=lowest)
        # Convert to 5=highest, 1=lowest for scoring
        score = 6 - task.priority
        
        # Deadline factor
        if task.deadline:
            days_to_deadline = (task.deadline - block_time).total_seconds() / (24 * 3600)
            
            if days_to_deadline <= 0:  # Overdue
                score += 10  # Very high score for overdue tasks
            elif days_to_deadline <= 1:  # Due within 24 hours
                score += 8
            elif days_to_deadline <= 2:  # Due within 48 hours
                score += 6
            elif days_to_deadline <= 7:  # Due within a week
                score += 3
                
        # Task size factor - prefer to start larger tasks earlier
        remaining_time = task.get_remaining_time()
        if remaining_time >= 8:  # Large task (8+ hours)
            score += 2
        elif remaining_time >= 4:  # Medium task (4-8 hours)
            score += 1
            
        # Mental effort matching - prefer low-effort tasks when mental fatigue is high
        if block_score >= 4:  # High accumulated fatigue
            # Adjust score based on task effort
            if task.effort == "Low":
                score += 1  # Bonus for low-effort tasks when tired
            elif task.effort == "High":
                score -= 1  # Penalty for high-effort tasks when tired
                
        # Task sequencing preference
        if self.prefer_similar_tasks and self.last_task_category == task.category:
            score += 0.5  # Small bonus for continuing with similar tasks
        elif not self.prefer_similar_tasks and self.last_task_category != task.category:
            score += 0.5  # Small bonus for switching task types
            
        return score
    
    def _is_blocked(self, task: Task, ignore_recently_completed: bool = False) -> bool:
        """Check if a task is blocked by dependencies"""
        if not task.dependencies:
            return False
            
        for dep_id in task.dependencies:
            # Find the dependency task
            dep_task = next((t for t in self.tasks if t.id == dep_id), None)
            if dep_task is None:
                continue
            if ignore_recently_completed and dep_task.completed:
                continue
            if not dep_task.completed:
                return True
                
        return False
        
    def _get_effort_value(self, effort: str) -> float:
        """Convert effort string to numeric value"""
        effort_map = {
            "Low": 1.0,
            "Medium": 1.5,
            "High": 2.0
        }
        return effort_map.get(effort, 1.0)

    def create_calendar_events(self, sessions: List[TaskSession], tasks: List[Task]) -> List[CalendarEvent]:
        """Convert task sessions to calendar events"""
        events = []
        
        # Create a mapping of task IDs to tasks for quick lookup
        task_map = {t.id: t for t in tasks}
        
        for session in sessions:
            # Convert the session to a calendar event
            event = session.to_calendar_event()
            
            # Add more details if it's a task event
            if not session.is_break and session.task_id in task_map:
                task = task_map[session.task_id]
                
                # Add more information to the description
                description = f"Task: {task.title}\n"
                if task.notes:
                    description += f"Notes: {task.notes}\n"
                description += f"Effort: {task.effort}\n"
                description += f"Priority: {task.priority}\n"
                description += f"Session {session.session_number} of {task.max_sessions if task.is_splittable else 1}\n"
                description += f"Task ID: {task.id}"
                
                event.description = description
            
            events.append(event)
            
        return events 
