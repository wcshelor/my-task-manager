import Foundation

enum CalendarReadError: LocalizedError, Equatable {
    case fullAccessRequired(CalendarPermissionStatus)
    case invalidWindow

    var errorDescription: String? {
        switch self {
        case .fullAccessRequired(let status):
            return "Full Calendar access is required to read events. Current status: \(status)."
        case .invalidWindow:
            return "Calendar read windows must have a positive duration."
        }
    }
}

@MainActor
final class EventKitCalendarPermissionService: CalendarPermissionProviding {
    private let eventStore: any CalendarEventStore

    init(eventStore: any CalendarEventStore) {
        self.eventStore = eventStore
    }

    func currentStatus() -> CalendarPermissionStatus {
        mapPermissionStatus(eventStore.authorizationStatus())
    }

    func requestFullAccess() async -> CalendarPermissionStatus {
        do {
            let granted = try await eventStore.requestFullAccess()
            if granted {
                return .fullAccessGranted
            }

            return currentStatus()
        } catch {
            return .error(error.localizedDescription)
        }
    }
}

@MainActor
final class EventKitCalendarListingService: CalendarListing {
    private let eventStore: any CalendarEventStore
    private let settingsRepository: any SettingsRepository

    init(
        eventStore: any CalendarEventStore,
        settingsRepository: any SettingsRepository
    ) {
        self.eventStore = eventStore
        self.settingsRepository = settingsRepository
    }

    func fetchReadableCalendars() async throws -> [ReadableCalendar] {
        try requireFullAccess(from: eventStore)

        let excludedTitles = Set(try settingsRepository.loadSettings().excludedReadCalendarTitles)

        return eventStore.fetchEventCalendars().map { calendar in
            ReadableCalendar(
                id: calendar.id,
                title: calendar.title,
                allowsContentModifications: calendar.allowsContentModifications,
                isExcludedBySettings: excludedTitles.contains(calendar.title)
            )
        }
    }
}

@MainActor
final class EventKitCalendarReader: CalendarReading {
    private let eventStore: any CalendarEventStore
    private let settingsRepository: any SettingsRepository

    init(
        eventStore: any CalendarEventStore,
        settingsRepository: any SettingsRepository
    ) {
        self.eventStore = eventStore
        self.settingsRepository = settingsRepository
    }

    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot] {
        guard window.duration > 0 else {
            throw CalendarReadError.invalidWindow
        }

        try requireFullAccess(from: eventStore)

        let excludedTitles = Set(try settingsRepository.loadSettings().excludedReadCalendarTitles)
        let includedCalendarIdentifiers = Set(
            eventStore.fetchEventCalendars()
                .filter { excludedTitles.contains($0.title) == false }
                .map(\.id)
        )

        return eventStore.fetchEvents(
            in: window,
            calendarIdentifiers: includedCalendarIdentifiers
        )
        .compactMap { event in
            guard event.end > event.start else {
                return nil
            }

            return CalendarEventSnapshot(
                identifier: event.identifier,
                title: normalizedEventTitle(event.title),
                start: event.start,
                end: event.end,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendarTitle
            )
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }

            if lhs.end != rhs.end {
                return lhs.end < rhs.end
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private func requireFullAccess(from eventStore: any CalendarEventStore) throws {
    let status = mapPermissionStatus(eventStore.authorizationStatus())
    guard status == .fullAccessGranted else {
        throw CalendarReadError.fullAccessRequired(status)
    }
}

private func mapPermissionStatus(
    _ status: EventStoreAuthorizationStatus
) -> CalendarPermissionStatus {
    switch status {
    case .notDetermined:
        return .notDetermined
    case .fullAccess:
        return .fullAccessGranted
    case .writeOnly:
        return .writeOnlyGrantedButInsufficient
    case .denied:
        return .denied
    case .restricted:
        return .restricted
    case .unknown:
        return .error("Unknown Calendar authorization status.")
    }
}
