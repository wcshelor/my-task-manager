import EventKit
import Foundation

enum EventStoreAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case fullAccess
    case writeOnly
    case denied
    case restricted
    case unknown
}

struct EventStoreCalendarDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let allowsContentModifications: Bool
}

struct EventStoreEventDescriptor: Equatable, Sendable {
    let identifier: String?
    let title: String?
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String
}

@MainActor
protocol CalendarEventStore {
    func authorizationStatus() -> EventStoreAuthorizationStatus
    func requestFullAccess() async throws -> Bool
    func fetchEventCalendars() -> [EventStoreCalendarDescriptor]
    func fetchEvents(
        in window: DateInterval,
        calendarIdentifiers: Set<String>?
    ) -> [EventStoreEventDescriptor]
}

@MainActor
final class EventKitCalendarEventStore: CalendarEventStore {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func authorizationStatus() -> EventStoreAuthorizationStatus {
        Self.mapAuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
    }

    func requestFullAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }

    func fetchEventCalendars() -> [EventStoreCalendarDescriptor] {
        eventStore.calendars(for: .event)
            .map { calendar in
                EventStoreCalendarDescriptor(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    allowsContentModifications: calendar.allowsContentModifications
                )
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func fetchEvents(
        in window: DateInterval,
        calendarIdentifiers: Set<String>?
    ) -> [EventStoreEventDescriptor] {
        guard window.duration > 0 else {
            return []
        }

        guard calendarIdentifiers?.isEmpty != true else {
            return []
        }

        let calendars = eventStore.calendars(for: .event).filter { calendar in
            guard let calendarIdentifiers else {
                return true
            }

            return calendarIdentifiers.contains(calendar.calendarIdentifier)
        }

        guard calendars.isEmpty == false else {
            return []
        }

        let predicate = eventStore.predicateForEvents(
            withStart: window.start,
            end: window.end,
            calendars: calendars
        )

        return eventStore.events(matching: predicate)
            .map { event in
                EventStoreEventDescriptor(
                    identifier: event.eventIdentifier,
                    title: event.title,
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title
                )
            }
            .sorted { lhs, rhs in
                if lhs.start != rhs.start {
                    return lhs.start < rhs.start
                }

                if lhs.end != rhs.end {
                    return lhs.end < rhs.end
                }

                return normalizedEventTitle(lhs.title)
                    .localizedCaseInsensitiveCompare(normalizedEventTitle(rhs.title)) == .orderedAscending
            }
    }

    private static func mapAuthorizationStatus(
        _ status: EKAuthorizationStatus
    ) -> EventStoreAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        case .authorized:
            return .fullAccess
        @unknown default:
            return .unknown
        }
    }
}

func normalizedEventTitle(_ title: String?) -> String {
    let cleanedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return cleanedTitle.isEmpty ? "Untitled Event" : cleanedTitle
}
