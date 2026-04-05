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
