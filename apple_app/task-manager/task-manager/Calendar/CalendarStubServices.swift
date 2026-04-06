import Foundation

@MainActor
final class StubCalendarPermissionService: CalendarPermissionProviding {
    private let status: CalendarPermissionStatus

    init(status: CalendarPermissionStatus = .notDetermined) {
        self.status = status
    }

    func currentStatus() -> CalendarPermissionStatus {
        status
    }

    func requestFullAccess() async -> CalendarPermissionStatus {
        status
    }
}

@MainActor
final class StubCalendarListingService: CalendarListing {
    private let calendars: [ReadableCalendar]

    init(calendars: [ReadableCalendar] = []) {
        self.calendars = calendars
    }

    func fetchReadableCalendars() async throws -> [ReadableCalendar] {
        calendars
    }
}

@MainActor
final class StubCalendarReader: CalendarReading {
    private let events: [CalendarEventSnapshot]

    init(events: [CalendarEventSnapshot] = []) {
        self.events = events
    }

    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot] {
        events.filter { event in
            event.end > window.start && event.start < window.end
        }
    }
}

@MainActor
final class StubCalendarWriter: CalendarWriting {
    private let validatedCalendarTitle: String

    init(validatedCalendarTitle: String = AppSettings.mvpDefault.writeCalendarTitle) {
        self.validatedCalendarTitle = validatedCalendarTitle
    }

    func validateWriteCalendar() async throws -> String {
        validatedCalendarTitle
    }

    func createEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult {
        CalendarWriteResult(
            eventIdentifier: "stub-\(block.id.uuidString)",
            calendarTitle: validatedCalendarTitle,
            eventTitle: "Task: \(task.title)"
        )
    }

    func updateEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult {
        CalendarWriteResult(
            eventIdentifier: block.calendarEventIdentifier ?? "stub-\(block.id.uuidString)",
            calendarTitle: validatedCalendarTitle,
            eventTitle: "Task: \(task.title)"
        )
    }

    func deleteEvent(for block: ScheduledBlock) async throws {}
}

@MainActor
final class StubCalendarReconciler: CalendarReconciling {
    func reconcileScheduledBlocks() async throws -> ReconciliationReport {
        .empty
    }
}
