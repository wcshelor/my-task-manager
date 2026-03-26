import json
from pathlib import Path
from typing import Dict, Any, Set
from .models import UserPreferences

# Path to store preferences
DEFAULT_PREFERENCES_FILE = "data/preferences.json"

def save_preferences(preferences: UserPreferences, path: str = DEFAULT_PREFERENCES_FILE) -> None:
    """Save user preferences to a JSON file"""
    # Ensure the directory exists
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    
    # Convert to dictionary (with special handling for sets)
    pref_dict = preferences_to_dict(preferences)
    
    # Save to file
    with p.open("w", encoding="utf-8") as f:
        json.dump(pref_dict, f, indent=2)

def load_preferences(path: str = DEFAULT_PREFERENCES_FILE) -> UserPreferences:
    """Load user preferences from a JSON file or return defaults"""
    p = Path(path)
    
    # If file doesn't exist, return default preferences
    if not p.exists():
        return UserPreferences()
    
    try:
        with p.open("r", encoding="utf-8") as f:
            pref_dict = json.load(f)
            return dict_to_preferences(pref_dict)
    except (json.JSONDecodeError, KeyError):
        # If file exists but is invalid, return defaults
        return UserPreferences()

def preferences_to_dict(preferences: UserPreferences) -> Dict[str, Any]:
    """Convert UserPreferences object to a dictionary for JSON storage"""
    # Convert the work_days set to a list for JSON serialization
    pref_dict = {
        "working_hours_start": preferences.working_hours_start,
        "working_hours_end": preferences.working_hours_end,
        "work_days": list(preferences.work_days),
        "prefer_focused_work": preferences.prefer_focused_work,
        "max_work_duration": preferences.max_work_duration,
        "break_duration": preferences.break_duration,
        "sync_with_apple_calendar": preferences.sync_with_apple_calendar,
        "default_task_priority": preferences.default_task_priority,
        "default_task_is_splittable": preferences.default_task_is_splittable,
        "default_task_max_sessions": preferences.default_task_max_sessions,
        "default_task_min_session_time": preferences.default_task_min_session_time
    }
    return pref_dict

def dict_to_preferences(pref_dict: Dict[str, Any]) -> UserPreferences:
    """Convert a dictionary to UserPreferences object"""
    # Convert the work_days list back to a set
    work_days_set = set(pref_dict.get("work_days", [0, 1, 2, 3, 4]))
    
    return UserPreferences(
        working_hours_start=pref_dict.get("working_hours_start", 9),
        working_hours_end=pref_dict.get("working_hours_end", 17),
        work_days=work_days_set,
        prefer_focused_work=pref_dict.get("prefer_focused_work", True),
        max_work_duration=pref_dict.get("max_work_duration", 2.0),
        break_duration=pref_dict.get("break_duration", 0.25),
        sync_with_apple_calendar=pref_dict.get("sync_with_apple_calendar", False),
        default_task_priority=pref_dict.get("default_task_priority", 2),
        default_task_is_splittable=pref_dict.get("default_task_is_splittable", True),
        default_task_max_sessions=pref_dict.get("default_task_max_sessions", 3),
        default_task_min_session_time=pref_dict.get("default_task_min_session_time", 0.5)
    )

# Global preferences instance that can be accessed throughout the app
_preferences = None

def get_preferences() -> UserPreferences:
    """Get the current preferences, loading from file if needed"""
    global _preferences
    if _preferences is None:
        _preferences = load_preferences()
    return _preferences

def update_preferences(new_preferences: UserPreferences) -> None:
    """Update and save the current preferences"""
    global _preferences
    _preferences = new_preferences
    save_preferences(_preferences) 