# src/task_manager.py
from datetime import datetime
from typing import List
from .models import Task, TaskStatus
from .utils import load_tasks, save_tasks

def add_task(task: Task) -> Task:
    tasks = load_tasks()
    tasks.append(task)
    save_tasks(tasks)
    return task

def delete_task(task_id: str) -> None:
    tasks = load_tasks()
    tasks = [task for task in tasks if task.id != task_id]
    save_tasks(tasks)

def mark_task_complete(task_id: str) -> None:
    tasks = load_tasks()
    for task in tasks:
        if task.id == task_id:
            task.status = TaskStatus.DONE
            break
    save_tasks(tasks)

def mark_task_incomplete(task_id: str) -> None:
    tasks = load_tasks()
    for task in tasks:
        if task.id == task_id:
            task.status = TaskStatus.ACTIVE
            break
    save_tasks(tasks)
    
def change_task_title(task_id: str, title: str) -> None:
    tasks = load_tasks()
    for task in tasks:
        if task.id == task_id:
            task.title = title
            break
    save_tasks(tasks)

def change_task_deadline(task_id: str, deadline: datetime) -> None:
    tasks = load_tasks()
    for task in tasks:
        if task.id == task_id:
            task.deadline = deadline
            break
    save_tasks(tasks)

def list_tasks() -> List[Task]:
    tasks = load_tasks()
    return tasks
