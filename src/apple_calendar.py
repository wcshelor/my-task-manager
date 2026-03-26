"""
Apple Calendar Integration Module
Handles importing events from macOS Calendar app
"""

import subprocess
import json
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
import time

@dataclass
class AppleCalendar:
    """Represents an Apple Calendar"""
    name: str
    id: str
    color: str = ""
    enabled: bool = True

@dataclass
class AppleEvent:
    """Represents an event from Apple Calendar"""
    title: str
    start_date: datetime
    end_date: datetime
    calendar_name: str
    calendar_id: str
    description: str = ""
    location: str = ""
    all_day: bool = False

class AppleCalendarImporter:
    """Handles importing events from Apple Calendar"""
    
    def __init__(self):
        self.available_calendars: List[AppleCalendar] = []
    
    def get_available_calendars(self) -> List[AppleCalendar]:
        """Get list of all available calendars from Apple Calendar"""
        # Try to access Calendar data without opening the app visibly
        applescript = '''tell application "Calendar"
    try
        set calendarNames to {}
        repeat with cal in calendars
            set end of calendarNames to name of cal
        end repeat
        set AppleScript's text item delimiters to "|"
        set calendarString to calendarNames as string
        set AppleScript's text item delimiters to ""
        return calendarString
    on error errMsg
        return "ERROR: " & errMsg
    end try
end tell'''
        
        try:
            # First attempt: try without launching Calendar app
            result = subprocess.run(
                ['osascript', '-e', applescript],
                capture_output=True,
                text=True,
                check=True,
                timeout=15
            )
            
            calendars = []
            output = result.stdout.strip()
            
            if output.startswith("ERROR:"):
                error_msg = output[7:]  # Remove "ERROR: " prefix
                
                # If error mentions app not running, try launching it in background
                if "not running" in error_msg.lower() or "application isn't running" in error_msg.lower():
                    # Launch Calendar app in background (without bringing to front)
                    background_launch = '''tell application "Calendar"
    launch
end tell'''
                    
                    try:
                        subprocess.run(['osascript', '-e', background_launch], 
                                     capture_output=True, text=True, timeout=10)
                        
                        # Wait a moment for it to start
                        time.sleep(1)
                        
                        # Try again
                        result = subprocess.run(
                            ['osascript', '-e', applescript],
                            capture_output=True,
                            text=True,
                            check=True,
                            timeout=15
                        )
                        
                        output = result.stdout.strip()
                        
                    except Exception as e:
                        print(f"Could not start Calendar in background: {e}")
                        return []
                
                if output.startswith("ERROR:"):
                    print(f"AppleScript error: {output[7:]}")
                    return []
            
            if output:
                # AppleScript returns format like: "Calendar1|Calendar2|Calendar3"
                calendar_names = output.split('|')
                for name in calendar_names:
                    if name.strip():
                        calendars.append(AppleCalendar(name=name.strip(), id=name.strip()))
            
            self.available_calendars = calendars
            return calendars
            
        except subprocess.TimeoutExpired:
            print("Timeout getting calendars - Calendar app may need permission")
            return []
        except subprocess.CalledProcessError as e:
            error_output = e.stderr.strip() if e.stderr else "Unknown error"
            print(f"Error getting calendars: {error_output}")
            
            # Check for common permission issues
            if "not authorized" in error_output.lower() or "permission" in error_output.lower():
                print("Permission issue detected. Please grant Calendar access to Terminal/Python.")
            
            return []
        except Exception as e:
            print(f"Unexpected error: {e}")
            return []
    
    def import_events(self, 
                     selected_calendars: List[str], 
                     start_date: datetime, 
                     end_date: datetime) -> List[AppleEvent]:
        """Import events from selected calendars within date range"""
        
        if not selected_calendars:
            return []
        
        # Format dates for AppleScript
        start_str = start_date.strftime("%m/%d/%Y")
        end_str = end_date.strftime("%m/%d/%Y")
        
        all_events = []
        
        # Try to process all calendars at once for maximum efficiency
        if len(selected_calendars) > 1:
            print(f"Importing from all calendars at once: {', '.join(selected_calendars)}")
            try:
                batch_events = self._import_all_calendars_batch(selected_calendars, start_date, end_date)
                if batch_events:
                    print(f"Successfully imported {len(batch_events)} events total")
                    return batch_events
                else:
                    print("Batch import returned no events, falling back to individual processing...")
            except Exception as e:
                print(f"Batch import failed ({e}), falling back to individual processing...")
        
        # Fallback: Process calendars one by one
        for calendar_name in selected_calendars:
            print(f"Importing from calendar: {calendar_name}")
            
            # Simple and fast: just get events in the date range directly
            applescript = f'''tell application "Calendar"
    try
        set startDate to date "{start_str}"
        set endDate to date "{end_str}"
        set eventList to {{}}
        
        try
            set cal to calendar "{calendar_name}"
            -- Get events directly in the date range - this should be fast!
            set calEvents to (every event of cal whose start date ≥ startDate and start date ≤ endDate)
            
            repeat with evt in calEvents
                try
                    set eventTitle to summary of evt
                    set eventStart to start date of evt
                    set eventEnd to end date of evt
                    set eventDesc to description of evt
                    set eventLoc to location of evt
                    set eventAllDay to allday event of evt
                    
                    set eventInfo to eventTitle & "|||" & (eventStart as string) & "|||" & (eventEnd as string) & "|||" & "{calendar_name}" & "|||" & eventDesc & "|||" & eventLoc & "|||" & (eventAllDay as string)
                    set end of eventList to eventInfo
                on error
                    -- Skip problematic events
                end try
            end repeat
        on error calErr
            return "ERROR: " & calErr
        end try
        
        set AppleScript's text item delimiters to "\\n"
        set eventString to eventList as string
        set AppleScript's text item delimiters to ""
        return eventString
    on error errMsg
        return "ERROR: " & errMsg
    end try
end tell'''
            
            try:
                result = subprocess.run(
                    ['osascript', '-e', applescript],
                    capture_output=True,
                    text=True,
                    check=True,
                    timeout=20  # Reasonable timeout for direct date range query
                )
                
                output = result.stdout.strip()
                
                if output.startswith("ERROR:"):
                    error_msg = output[7:]
                    print(f"Error importing from {calendar_name}: {error_msg}")
                    continue
                
                # Parse events from this calendar
                if output and output != "":
                    event_lines = output.split('\n') if '\n' in output else [output]
                    event_count = 0
                    
                    for line in event_lines:
                        if line.strip():
                            try:
                                parts = line.split('|||')
                                if len(parts) >= 4:
                                    title = parts[0].strip()
                                    start_str = parts[1].strip()
                                    end_str = parts[2].strip()
                                    calendar_name_parsed = parts[3].strip()
                                    description = parts[4].strip() if len(parts) > 4 else ""
                                    location = parts[5].strip() if len(parts) > 5 else ""
                                    all_day = parts[6].strip().lower() == "true" if len(parts) > 6 else False
                                    
                                    # Parse dates (AppleScript date format)
                                    start_date_parsed = self._parse_applescript_date(start_str)
                                    end_date_parsed = self._parse_applescript_date(end_str)
                                    
                                    if start_date_parsed and end_date_parsed:
                                        # Mark as imported from Apple Calendar
                                        enhanced_description = f"[Imported from Apple Calendar: {calendar_name_parsed}]"
                                        if description and description != "missing value":
                                            enhanced_description += f" {description}"
                                        
                                        event = AppleEvent(
                                            title=title,
                                            start_date=start_date_parsed,
                                            end_date=end_date_parsed,
                                            calendar_name=calendar_name_parsed,
                                            calendar_id="",
                                            description=enhanced_description,
                                            location=location if location != "missing value" else "",
                                            all_day=all_day
                                        )
                                        all_events.append(event)
                                        event_count += 1
                            except Exception as e:
                                print(f"Error parsing event: {e}")
                                continue
                    
                    print(f"  → Imported {event_count} events from {calendar_name}")
                else:
                    print(f"  → No events found in {calendar_name} for the date range")
                
            except subprocess.TimeoutExpired:
                print(f"Timeout importing from {calendar_name}, trying fallback...")
                fallback_events = self._import_calendar_fallback(calendar_name, start_date, end_date)
                all_events.extend(fallback_events)
            except subprocess.CalledProcessError as e:
                print(f"Error importing from {calendar_name}: {e}")
                print(f"Trying fallback for {calendar_name}...")
                fallback_events = self._import_calendar_fallback(calendar_name, start_date, end_date)
                all_events.extend(fallback_events)
            except Exception as e:
                print(f"Unexpected error importing from {calendar_name}: {e}")
                print(f"Trying fallback for {calendar_name}...")
                fallback_events = self._import_calendar_fallback(calendar_name, start_date, end_date)
                all_events.extend(fallback_events)
        
        print(f"Successfully imported {len(all_events)} events total")
        return all_events
    
    def _import_all_calendars_batch(self, selected_calendars: List[str], start_date: datetime, end_date: datetime) -> List[AppleEvent]:
        """Efficiently import events from all selected calendars at once"""
        # Format dates for AppleScript
        start_str = start_date.strftime("%m/%d/%Y")
        end_str = end_date.strftime("%m/%d/%Y")
        
        # Create AppleScript calendar list
        calendar_list = ', '.join([f'"{cal}"' for cal in selected_calendars])
        
        # Ultra-fast: get events from all selected calendars in one query
        applescript = f'''tell application "Calendar"
    try
        set startDate to date "{start_str}"
        set endDate to date "{end_str}"
        set eventList to {{}}
        set calendarNames to {{{calendar_list}}}
        
        repeat with calName in calendarNames
            try
                set cal to calendar (calName as string)
                -- Get events directly in the date range - this should be fast!
                set calEvents to (every event of cal whose start date ≥ startDate and start date ≤ endDate)
                
                repeat with evt in calEvents
                    try
                        set eventTitle to summary of evt
                        set eventStart to start date of evt
                        set eventEnd to end date of evt
                        set eventDesc to description of evt
                        set eventLoc to location of evt
                        set eventAllDay to allday event of evt
                        
                        set eventInfo to eventTitle & "|||" & (eventStart as string) & "|||" & (eventEnd as string) & "|||" & (calName as string) & "|||" & eventDesc & "|||" & eventLoc & "|||" & (eventAllDay as string)
                        set end of eventList to eventInfo
                    on error
                        -- Skip problematic events
                    end try
                end repeat
            on error calErr
                -- Skip problematic calendars
            end try
        end repeat
        
        set AppleScript's text item delimiters to "\\n"
        set eventString to eventList as string
        set AppleScript's text item delimiters to ""
        return eventString
    on error errMsg
        return "ERROR: " & errMsg
    end try
end tell'''
        
        result = subprocess.run(
            ['osascript', '-e', applescript],
            capture_output=True,
            text=True,
            check=True,
            timeout=25  # Reasonable timeout for all calendars at once
        )
        
        output = result.stdout.strip()
        
        if output.startswith("ERROR:"):
            raise Exception(f"AppleScript error: {output[7:]}")
        
        all_events = []
        calendar_counts = {}
        
        # Parse events from all calendars
        if output and output != "":
            event_lines = output.split('\n') if '\n' in output else [output]
            
            for line in event_lines:
                if line.strip():
                    try:
                        parts = line.split('|||')
                        if len(parts) >= 4:
                            title = parts[0].strip()
                            start_str = parts[1].strip()
                            end_str = parts[2].strip()
                            calendar_name = parts[3].strip()
                            description = parts[4].strip() if len(parts) > 4 else ""
                            location = parts[5].strip() if len(parts) > 5 else ""
                            all_day = parts[6].strip().lower() == "true" if len(parts) > 6 else False
                            
                            # Parse dates (AppleScript date format)
                            start_date_parsed = self._parse_applescript_date(start_str)
                            end_date_parsed = self._parse_applescript_date(end_str)
                            
                            if start_date_parsed and end_date_parsed:
                                # Mark as imported from Apple Calendar
                                enhanced_description = f"[Imported from Apple Calendar: {calendar_name}]"
                                if description and description != "missing value":
                                    enhanced_description += f" {description}"
                                
                                event = AppleEvent(
                                    title=title,
                                    start_date=start_date_parsed,
                                    end_date=end_date_parsed,
                                    calendar_name=calendar_name,
                                    calendar_id="",
                                    description=enhanced_description,
                                    location=location if location != "missing value" else "",
                                    all_day=all_day
                                )
                                all_events.append(event)
                                calendar_counts[calendar_name] = calendar_counts.get(calendar_name, 0) + 1
                    except Exception as e:
                        print(f"Error parsing event: {e}")
                        continue
        
        # Print summary for each calendar
        for cal_name in selected_calendars:
            count = calendar_counts.get(cal_name, 0)
            if count > 0:
                print(f"  → Imported {count} events from {cal_name}")
            else:
                print(f"  → No events found in {cal_name} for the date range")
        
        return all_events
    
    def _import_calendar_fallback(self, calendar_name: str, start_date: datetime, end_date: datetime) -> List[AppleEvent]:
        """Fallback method for importing events when main method fails"""
        print(f"  Using fallback import for {calendar_name}...")
        
        # Format dates for AppleScript
        start_str = start_date.strftime("%m/%d/%Y")
        end_str = end_date.strftime("%m/%d/%Y")
        
        # Ultra-simple fallback that only gets first 10 events
        fallback_script = f'''tell application "Calendar"
    try
        set eventList to {{}}
        
        try
            set cal to calendar "{calendar_name}"
            set allEvents to (every event of cal)
            set eventCount to count of allEvents
            
            if eventCount > 10 then
                set eventCount to 10
            end if
            
            repeat with i from 1 to eventCount
                try
                    set evt to item i of allEvents
                    set eventTitle to summary of evt
                    set eventStart to start date of evt
                    set eventEnd to end date of evt
                    set eventDesc to description of evt
                    set eventLoc to location of evt
                    set eventAllDay to allday event of evt
                    
                    set eventInfo to eventTitle & "|||" & (eventStart as string) & "|||" & (eventEnd as string) & "|||" & "{calendar_name}" & "|||" & eventDesc & "|||" & eventLoc & "|||" & (eventAllDay as string)
                    set end of eventList to eventInfo
                on error
                    -- Skip problematic events
                end try
            end repeat
        on error
            -- Skip problematic calendars
        end try
        
        set AppleScript's text item delimiters to "\\n"
        set eventString to eventList as string
        set AppleScript's text item delimiters to ""
        return eventString
    on error errMsg
        return "ERROR: " & errMsg
    end try
end tell'''
        
        try:
            result = subprocess.run(
                ['osascript', '-e', fallback_script],
                capture_output=True,
                text=True,
                check=True,
                timeout=30  # Longer timeout for fallback
            )
            
            output = result.stdout.strip()
            events = []
            
            if output.startswith("ERROR:"):
                print(f"  Fallback also failed for {calendar_name}: {output[7:]}")
                return events
            
            if output and output != "":
                event_lines = output.split('\n') if '\n' in output else [output]
                
                for line in event_lines:
                    if line.strip():
                        try:
                            parts = line.split('|||')
                            if len(parts) >= 4:
                                title = parts[0].strip()
                                start_str = parts[1].strip()
                                end_str = parts[2].strip()
                                calendar_name_parsed = parts[3].strip()
                                description = parts[4].strip() if len(parts) > 4 else ""
                                location = parts[5].strip() if len(parts) > 5 else ""
                                all_day = parts[6].strip().lower() == "true" if len(parts) > 6 else False
                                
                                # Parse dates
                                start_date_parsed = self._parse_applescript_date(start_str)
                                end_date_parsed = self._parse_applescript_date(end_str)
                                
                                if start_date_parsed and end_date_parsed:
                                    # Mark as fallback import from Apple Calendar
                                    enhanced_description = f"[Imported from Apple Calendar: {calendar_name_parsed}]"
                                    if description:
                                        enhanced_description += f" {description}"
                                    
                                    event = AppleEvent(
                                        title=title,
                                        start_date=start_date_parsed,
                                        end_date=end_date_parsed,
                                        calendar_name=calendar_name_parsed,
                                        calendar_id="",
                                        description=enhanced_description,
                                        location=location,
                                        all_day=all_day
                                    )
                                    events.append(event)
                        except Exception as e:
                            print(f"  Error parsing fallback event: {e}")
                            continue
                
                print(f"  → Fallback imported {len(events)} events from {calendar_name}")
            
            return events
            
        except Exception as e:
            print(f"  Fallback method also failed for {calendar_name}: {e}")
            return []
    
    def _parse_applescript_date(self, date_str: str) -> Optional[datetime]:
        """Parse AppleScript date string to Python datetime"""
        try:
            # AppleScript returns dates like: "Monday, December 16, 2024 at 2:00:00 PM"
            # We need to handle various formats
            
            # Remove day of week if present
            if ',' in date_str:
                parts = date_str.split(',', 1)
                if len(parts) > 1:
                    date_str = parts[1].strip()
            
            # Try different date formats
            formats = [
                "%B %d, %Y at %I:%M:%S %p",  # December 16, 2024 at 2:00:00 PM
                "%B %d, %Y at %I:%M %p",     # December 16, 2024 at 2:00 PM
                "%B %d, %Y",                 # December 16, 2024 (all day)
                "%m/%d/%Y %I:%M:%S %p",      # 12/16/2024 2:00:00 PM
                "%m/%d/%Y %I:%M %p",         # 12/16/2024 2:00 PM
                "%m/%d/%Y",                  # 12/16/2024
            ]
            
            for fmt in formats:
                try:
                    return datetime.strptime(date_str, fmt)
                except ValueError:
                    continue
            
            print(f"Could not parse date: {date_str}")
            return None
            
        except Exception as e:
            print(f"Error parsing date '{date_str}': {e}")
            return None

def check_calendar_permissions() -> bool:
    """Check if we have permission to access Calendar and provide guidance"""
    # Try a simple Calendar access without opening the app
    test_script = '''tell application "Calendar"
    try
        set calCount to count of calendars
        return "SUCCESS: " & calCount
    on error errMsg
        return "ERROR: " & errMsg
    end try
end tell'''
    
    try:
        result = subprocess.run(
            ['osascript', '-e', test_script],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        output = result.stdout.strip()
        
        if output.startswith("SUCCESS:"):
            return True
        elif output.startswith("ERROR:"):
            error_msg = output[7:]
            
            # If app not running, try launching in background
            if "not running" in error_msg.lower() or "application isn't running" in error_msg.lower():
                try:
                    # Launch in background
                    launch_script = '''tell application "Calendar"
    launch
end tell'''
                    subprocess.run(['osascript', '-e', launch_script], 
                                 capture_output=True, text=True, timeout=10)
                    time.sleep(1)
                    
                    # Try again
                    result = subprocess.run(
                        ['osascript', '-e', test_script],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    output = result.stdout.strip()
                    if output.startswith("SUCCESS:"):
                        return True
                        
                except Exception:
                    pass
            
            print(f"❌ Calendar access error: {error_msg}")
            print_permission_instructions()
            return False
        else:
            print(f"❌ Unexpected response: {output}")
            print_permission_instructions()
            return False
            
    except subprocess.TimeoutExpired:
        print("❌ Timeout accessing Calendar")
        print_permission_instructions()
        return False
    except Exception as e:
        print(f"❌ Error checking permissions: {e}")
        print_permission_instructions()
        return False

def print_permission_instructions():
    """Print instructions for granting Calendar permissions"""
    print("\n" + "="*60)
    print("CALENDAR PERMISSION SETUP REQUIRED")
    print("="*60)
    print("To use Apple Calendar integration, you need to grant permissions:")
    print()
    print("1. Open System Preferences/Settings")
    print("2. Go to Security & Privacy → Privacy")
    print("3. Select 'Calendar' from the left sidebar")
    print("4. Make sure 'Terminal' is checked (if running from Terminal)")
    print("5. If using an IDE like VS Code, add your IDE to the list")
    print()
    print("Alternative method:")
    print("1. Open Terminal")
    print("2. Run: tccutil reset Calendar")
    print("3. Run the task manager again - it will prompt for permission")
    print()
    print("If you're still having issues:")
    print("- Try running the Calendar app first")
    print("- Make sure you have calendars with events")
    print("- Restart Terminal after granting permissions")
    print("="*60)

def test_apple_calendar_integration():
    """Test function for Apple Calendar integration"""
    print("Testing Apple Calendar Integration...")
    
    # First check permissions
    if not check_calendar_permissions():
        return
    
    importer = AppleCalendarImporter()
    
    # Test getting calendars
    print("\n1. Getting available calendars...")
    calendars = importer.get_available_calendars()
    
    if calendars:
        print(f"Found {len(calendars)} calendars:")
        for cal in calendars:
            print(f"  - {cal.name} (ID: {cal.id})")
        
        # Test importing events from first calendar
        if calendars:
            print(f"\n2. Testing event import from '{calendars[0].name}'...")
            start_date = datetime.now()
            end_date = start_date + timedelta(days=7)
            
            events = importer.import_events(
                [calendars[0].name], 
                start_date, 
                end_date
            )
            
            print(f"Found {len(events)} events:")
            for event in events[:5]:  # Show first 5 events
                print(f"  - {event.title}")
                print(f"    {event.start_date} to {event.end_date}")
                print(f"    Calendar: {event.calendar_name}")
                if event.location:
                    print(f"    Location: {event.location}")
                print()
    else:
        print("No calendars found")
        print_permission_instructions()

if __name__ == "__main__":
    test_apple_calendar_integration() 