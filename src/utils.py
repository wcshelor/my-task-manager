# src/utils.py
import json
from typing import List
from pathlib import Path

from .models import Task, ValidationError

DEFAULT_TASKS_FILE = Path(__file__).parent.parent / "data" / "tasks.json"

def load_tasks(path: str = DEFAULT_TASKS_FILE) -> List[Task]:
    p = Path(path)

    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        # Create an empty tasks file with a valid JSON array
        with p.open("w", encoding="utf-8") as f:
            json.dump([], f)
        return []
    
    try:
        with p.open("r", encoding="utf-8") as f:
            data_list = json.load(f)
    except json.JSONDecodeError:
        # If the file exists but has invalid JSON, initialize it with an empty array
        with p.open("w", encoding="utf-8") as f:
            json.dump([], f)
        return []

    if not isinstance(data_list, list):
        return []

    tasks: List[Task] = []
    for data in data_list:
        if not isinstance(data, dict):
            continue
        try:
            tasks.append(Task.from_dict(data))
        except (KeyError, TypeError, ValidationError, ValueError):
            continue

    return tasks

def save_tasks(tasks: List[Task], path: str = DEFAULT_TASKS_FILE) -> None:
    # 1. Convert each Task to a dict
    data_list = [_task_to_dict(t) for t in tasks]

    # 2. Ensure the folder exists (e.g. "data/")
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)

    # 3. Open the file for writing (overwriting any old data)
    with p.open("w", encoding="utf-8") as f:
        # json.dump writes the list-of-dicts to the file as JSON text
        json.dump(data_list, f, indent=2)

def _task_to_dict(task: Task) -> dict:
    return task.to_dict()
