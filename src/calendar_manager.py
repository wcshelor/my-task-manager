import datetime
import subprocess
import json
import re
from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path
from .models import Task, UserPreferences
from .preferences import get_preferences

# Calendar event representation
class CalendarEvent:
    def __init__(self, 
                 title: str,
                 start_time: datetime.datetime,
                 end_time: datetime.datetime,
                 location: str = "",
                 description: str = "",
                 calendar_name: str = "",
                 event_id: str = "",
                 is_task_event: bool = False,
                 task_id: Optional[str] = None,
                 is_suggestion: bool = False):
        self.title = title
        self.start_time = start_time
        self.end_time = end_time
        self.location = location
        self.description = description
        self.calendar_name = calendar_name
        self.event_id = event_id
        self.is_task_event = is_task_event
        self.task_id = task_id
        self.is_suggestion = is_suggestion
        
    @property
    def duration_hours(self) -> float:
        """Get event duration in hours"""
        delta = self.end_time - self.start_time
        return delta.total_seconds() / 3600
    
    def __str__(self) -> str:
        start_str = self.start_time.strftime("%Y-%m-%d %H:%M")
        end_str = self.end_time.strftime("%H:%M")
        return f"{self.title} ({start_str} - {end_str})"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            "title": self.title,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat(),
            "location": self.location,
            "description": self.description,
            "calendar_name": self.calendar_name,
            "event_id": self.event_id,
            "is_task_event": self.is_task_event,
            "task_id": self.task_id,
            "is_suggestion": self.is_suggestion
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'CalendarEvent':
        """Create from dictionary"""
        return cls(
            title=data["title"],
            start_time=datetime.datetime.fromisoformat(data["start_time"]),
            end_time=datetime.datetime.fromisoformat(data["end_time"]),
            location=data.get("location", ""),
            description=data.get("description", ""),
            calendar_name=data.get("calendar_name", ""),
            event_id=data.get("event_id", ""),
            is_task_event=data.get("is_task_event", False),
            task_id=data.get("task_id"),
            is_suggestion=data.get("is_suggestion", False)
        )


class CalendarManager:
    """Manages calendar operations and integration with Apple Calendar"""
    
    def __init__(self):
        self.preferences = get_preferences()
        self.cache_file = Path("data/calendar_cache.json")
        self.cache_expiry = datetime.timedelta(minutes=15)  # Cache valid for 15 minutes
        self.last_cache_update = None
        self.cached_events = []
        
    def get_events_for_date_range(self, 
                                 start_date: datetime.datetime,
                                 end_date: datetime.datetime) -> List[CalendarEvent]:
        """Get events for a specified date range, combining both local and Apple Calendar events"""
        events = []
        
        # Get local events
        local_events = self._get_local_events(start_date, end_date)
        events.extend(local_events)
        
        # Get Apple Calendar events if integration is enabled
        if self.preferences.sync_with_apple_calendar:
            apple_events = self._get_apple_calendar_events(start_date, end_date)
            events.extend(apple_events)
        
        # Sort by start time
        events.sort(key=lambda e: e.start_time)
        
        return events
    
    def get_free_time_blocks(self, 
                            start_date: datetime.datetime, 
                            end_date: datetime.datetime, 
                            min_duration: float = 0.5) -> List[Tuple[datetime.datetime, datetime.datetime]]:
        """Get available time blocks within the user's working hours"""
        events = self.get_events_for_date_range(start_date, end_date)
        prefs = get_preferences()
        
        free_blocks = []
        current_date = start_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_date = end_date.replace(hour=23, minute=59, second=59)
        
        while current_date <= end_date:
            # Check if this is a work day
            weekday = current_date.weekday()
            if weekday in prefs.work_days:
                # Set working hours for this day
                day_start = current_date.replace(hour=prefs.working_hours_start, minute=0, second=0)
                day_end = current_date.replace(hour=prefs.working_hours_end, minute=0, second=0)
                
                # Adjust if we're in the middle of the day range
                if current_date == start_date.replace(hour=0, minute=0, second=0, microsecond=0) and start_date > day_start:
                    day_start = start_date
                
                if current_date == end_date.replace(hour=0, minute=0, second=0, microsecond=0) and end_date < day_end:
                    day_end = end_date
                
                # Find free blocks within working hours
                day_events = [e for e in events if e.start_time.date() == current_date.date()]
                
                # Sort events by start time
                day_events.sort(key=lambda e: e.start_time)
                
                # Start with the beginning of working hours
                block_start = day_start
                
                # Process each event to find gaps
                for event in day_events:
                    # Skip events outside working hours
                    if event.end_time <= day_start or event.start_time >= day_end:
                        continue
                    
                    # If event starts after block_start, we have a free block
                    if event.start_time > block_start:
                        duration = (event.start_time - block_start).total_seconds() / 3600
                        if duration >= min_duration:
                            free_blocks.append((block_start, event.start_time))
                    
                    # Move block_start to end of this event
                    block_start = max(block_start, event.end_time)
                
                # Add final block if there's time left in the day
                if block_start < day_end:
                    duration = (day_end - block_start).total_seconds() / 3600
                    if duration >= min_duration:
                        free_blocks.append((block_start, day_end))
            
            # Move to next day
            current_date += datetime.timedelta(days=1)
        
        return free_blocks
    
    def create_task_event(self, task: Task, start_time: datetime.datetime, duration_hours: float) -> CalendarEvent:
        """Create a calendar event for a task"""
        end_time = start_time + datetime.timedelta(hours=duration_hours)
        
        # Create description with task details
        description = f"Task: {task.title}\n"
        if task.notes:
            description += f"Notes: {task.notes}\n"
        description += f"Effort: {task.effort}\n"
        description += f"Priority: {task.priority}\n"
        description += f"Session {task.sessions_completed + 1} of {task.max_sessions if task.is_splittable else 1}"
        
        event = CalendarEvent(
            title=f"[Task] {task.title}",
            start_time=start_time,
            end_time=end_time,
            description=description,
            is_task_event=True,
            task_id=task.id
        )
        
        return event
    
    def add_event_to_calendar(self, event: CalendarEvent, export_to_apple: bool = False) -> str:
        """Add event to the local calendar and optionally to Apple Calendar"""
        # Save to local storage
        self._save_local_event(event)
        
        # Export to Apple Calendar if requested and integration is enabled
        if export_to_apple and self.preferences.sync_with_apple_calendar:
            return self._add_to_apple_calendar(event)
        
        return ""
    
    def _get_local_events(self, start_date: datetime.datetime, end_date: datetime.datetime) -> List[CalendarEvent]:
        """Get events from local storage"""
        events_file = Path("data/events.json")
        
        if not events_file.exists():
            events_file.parent.mkdir(parents=True, exist_ok=True)
            with events_file.open("w") as f:
                json.dump([], f)
            return []
        
        try:
            with events_file.open("r") as f:
                events_data = json.load(f)
        except json.JSONDecodeError:
            return []
        
        events = []
        for data in events_data:
            try:
                event = CalendarEvent.from_dict(data)
                if start_date <= event.start_time <= end_date or start_date <= event.end_time <= end_date:
                    events.append(event)
            except (KeyError, ValueError):
                continue
        
        return events
    
    def _save_local_event(self, event: CalendarEvent) -> None:
        """Save event to local storage"""
        events_file = Path("data/events.json")
        
        # Ensure directory exists
        events_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Load existing events
        if events_file.exists():
            try:
                with events_file.open("r") as f:
                    events_data = json.load(f)
            except json.JSONDecodeError:
                events_data = []
        else:
            events_data = []
        
        # Add new event
        events_data.append(event.to_dict())
        
        # Save back to file
        with events_file.open("w") as f:
            json.dump(events_data, f, indent=2)
    
    def _get_apple_calendar_events(self, start_date: datetime.datetime, end_date: datetime.datetime) -> List[CalendarEvent]:
        """Get events from Apple Calendar using AppleScript"""
        # Check if we have a recent cache
        if self._is_cache_valid():
            cached = self._get_cached_events(start_date, end_date)
            if cached is not None:
                return cached
        
        events = []
        
        try:
            # Format dates for AppleScript
            start_str = start_date.strftime("%Y-%m-%d")
            end_str = end_date.strftime("%Y-%m-%d")
            
            # AppleScript to fetch calendar events
            script = f'''
            tell application "Calendar"
                set evList to {{}}
                set calEvents to events of calendars where start date ≥ date "{start_str}" and start date ≤ date "{end_str}"
                repeat with anEvent in calEvents
                    set eventProps to {{summary:summary of anEvent, start_date:start date of anEvent, end_date:end date of anEvent, description:description of anEvent, location:location of anEvent, calendar:name of calendar of anEvent, UID:uid of anEvent}}
                    copy eventProps to end of evList
                end repeat
                return evList
            end tell
            '''
            
            # Run AppleScript and get results
            proc = subprocess.Popen(['osascript', '-e', script], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            output, error = proc.communicate()
            
            # Parse the AppleScript output (this is simplified and may need improvement)
            if error:
                print(f"Error fetching Apple Calendar events: {error}")
                return []
                
            # Extract events from AppleScript output using regex
            event_pattern = r"summary:(.*?), start_date:(.*?), end_date:(.*?), description:(.*?), location:(.*?), calendar:(.*?), UID:(.*?)(?:, |$)"
            matches = re.findall(event_pattern, output)
            
            for match in matches:
                title, start, end, desc, loc, cal, uid = match
                
                try:
                    # Parse dates (may need adjustment based on actual format)
                    start_time = datetime.datetime.strptime(start, "%Y-%m-%d %H:%M:%S %z")
                    end_time = datetime.datetime.strptime(end, "%Y-%m-%d %H:%M:%S %z")
                    
                    # Check if this is one of our task events
                    is_task_event = title.startswith("[Task]")
                    task_id = None
                    
                    if is_task_event:
                        # Extract task ID from description if possible
                        task_match = re.search(r"Task ID: (\w+)", desc)
                        if task_match:
                            task_id = task_match.group(1)
                    
                    event = CalendarEvent(
                        title=title,
                        start_time=start_time,
                        end_time=end_time,
                        description=desc,
                        location=loc,
                        calendar_name=cal,
                        event_id=uid,
                        is_task_event=is_task_event,
                        task_id=task_id
                    )
                    events.append(event)
                except ValueError:
                    # Skip events with invalid date formats
                    continue
            
            # Update cache
            self._update_cache(events)
            
        except Exception as e:
            print(f"Error fetching Apple Calendar events: {e}")
        
        return events
    
    def _add_to_apple_calendar(self, event: CalendarEvent) -> str:
        """Add event to Apple Calendar using AppleScript"""
        try:
            # Format dates for AppleScript
            start_str = event.start_time.strftime("%Y-%m-%d %H:%M:%S")
            end_str = event.end_time.strftime("%Y-%m-%d %H:%M:%S")
            
            # Add task ID to description if it's a task event
            description = event.description
            if event.is_task_event and event.task_id:
                description += f"\nTask ID: {event.task_id}"
            
            # Escape quotes in strings
            title = event.title.replace('"', '\\"')
            description = description.replace('"', '\\"')
            location = event.location.replace('"', '\\"')
            
            # AppleScript to create calendar event
            script = f'''
            tell application "Calendar"
                tell calendar "Task Manager"
                    make new event with properties {{summary:"{title}", start date:date "{start_str}", end date:date "{end_str}", description:"{description}", location:"{location}"}}
                    set newEvent to the result
                    return uid of newEvent
                end tell
            end tell
            '''
            
            # Run AppleScript and get result (event UID)
            proc = subprocess.Popen(['osascript', '-e', script], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            output, error = proc.communicate()
            
            if error:
                print(f"Error adding event to Apple Calendar: {error}")
                return ""
            
            # Return the UID of the new event
            return output.strip()
            
        except Exception as e:
            print(f"Error adding event to Apple Calendar: {e}")
            return ""
    
    def _is_cache_valid(self) -> bool:
        """Check if the cache is still valid"""
        if self.last_cache_update is None:
            return False
            
        now = datetime.datetime.now()
        return (now - self.last_cache_update) < self.cache_expiry
    
    def _update_cache(self, events: List[CalendarEvent]) -> None:
        """Update the events cache"""
        self.cached_events = events
        self.last_cache_update = datetime.datetime.now()
        
        # Save to cache file
        self.cache_file.parent.mkdir(parents=True, exist_ok=True)
        with self.cache_file.open("w") as f:
            json.dump([e.to_dict() for e in events], f, indent=2)
    
    def _get_cached_events(self, start_date: datetime.datetime, end_date: datetime.datetime) -> Optional[List[CalendarEvent]]:
        """Get events from cache for the specified date range"""
        if not self.cached_events and self.cache_file.exists():
            try:
                with self.cache_file.open("r") as f:
                    event_data = json.load(f)
                    self.cached_events = [CalendarEvent.from_dict(d) for d in event_data]
                    self.last_cache_update = datetime.datetime.now()
            except (json.JSONDecodeError, KeyError):
                return None
        
        # Filter events for the requested date range
        return [e for e in self.cached_events if 
                (start_date <= e.start_time <= end_date) or 
                (start_date <= e.end_time <= end_date)]
    
    def create_test_event(self) -> CalendarEvent:
        """Create a test event to demonstrate calendar functionality"""
        now = datetime.datetime.now()
        start_time = now.replace(
            hour=(now.hour + 1) % 24,  # Next hour
            minute=0,
            second=0,
            microsecond=0
        )
        end_time = start_time + datetime.timedelta(hours=1)
        
        event = CalendarEvent(
            title="Test Calendar Event",
            start_time=start_time,
            end_time=end_time,
            description="This is a test event to verify calendar integration.",
            location="",
            calendar_name="Task Manager",
            is_task_event=False
        )
        
        # Save to local calendar
        self._save_local_event(event)
        
        return event

    def remove_event(self, event: CalendarEvent) -> bool:
        """Remove an event from local storage"""
        events_file = Path("data/events.json")
        
        if not events_file.exists():
            return False
            
        try:
            with events_file.open("r") as f:
                events_data = json.load(f)
                
            # Convert event to dict for comparison
            event_dict = event.to_dict()
            
            # Find and remove the matching event
            updated_events = []
            for e in events_data:
                # Compare key fields to identify the event
                if (e["start_time"] == event_dict["start_time"] and 
                    e["end_time"] == event_dict["end_time"] and
                    e["title"] == event_dict["title"]):
                    # Skip this event to remove it
                    continue
                    
                updated_events.append(e)
                
            # Save back to file
            with events_file.open("w") as f:
                json.dump(updated_events, f, indent=2)
                
            # Invalidate cache
            self.last_cache_update = None
            
            return True
                
        except (json.JSONDecodeError, KeyError) as e:
            print(f"Error removing event: {e}")
            return False


# Global calendar manager instance
_calendar_manager = None

def get_calendar_manager() -> CalendarManager:
    """Get the global calendar manager instance"""
    global _calendar_manager
    if _calendar_manager is None:
        _calendar_manager = CalendarManager()
    return _calendar_manager 