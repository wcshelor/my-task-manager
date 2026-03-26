# src/__init__.py
from .models import Task, UserPreferences
from .task_manager import (
    add_task,
    delete_task, 
    mark_task_complete, 
    mark_task_incomplete,
    change_task_title,
    change_task_deadline,
    list_tasks
)
from .preferences import (
    get_preferences,
    update_preferences,
    load_preferences,
    save_preferences
)
from .scheduler import (
    ScheduleGenerator,
    TaskSession
) 