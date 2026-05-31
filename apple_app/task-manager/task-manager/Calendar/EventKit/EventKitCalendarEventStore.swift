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
    let calendarIdentifier: String
    let title: String?
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String
}

struct EventStoreEventMutationRequest: Equatable, Sendable {
    let identifier: String?
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarIdentifier: String
}

enum EventStoreMutationError: Error, LocalizedError, Equatable {
    case calendarNotFound(String)
    case eventNotFound(String)
    case invalidDateRange
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .calendarNotFound(let identifier):
            return "Calendar \(identifier) could not be found."
        case .eventNotFound(let identifier):
            return "Calendar event \(identifier) could not be found."
        case .invalidDateRange:
            return "Calendar events must end after they start."
        case .saveFailed(let message):
            return message
        }
    }
}

@MainActor
protocol CalendarEventStore {
    func authorizationStatus() -> EventStoreAuthorizationStatus
    func requestFullAccess() async throws -> Bool
    func fetchEventCalendars() -> [EventStoreCalendarDescriptor]
    func fetchEvent(withIdentifier identifier: String) -> EventStoreEventDescriptor?
    func fetchEvents(
        in window: DateInterval,
        calendarIdentifiers: Set<String>?
    ) -> [EventStoreEventDescriptor]
    func saveEvent(_ request: EventStoreEventMutationRequest) throws -> EventStoreEventDescriptor
    func deleteEvent(withIdentifier identifier: String) throws
}

@MainActor
final class EventKitCalendarEventStore: CalendarEventStore, CalendarChangeObserving {
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

    func fetchEvent(withIdentifier identifier: String) -> EventStoreEventDescriptor? {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            return nil
        }

        return EventStoreEventDescriptor(
            identifier: event.eventIdentifier,
            calendarIdentifier: event.calendar.calendarIdentifier,
            title: event.title,
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendarTitle: event.calendar.title
        )
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
                    calendarIdentifier: event.calendar.calendarIdentifier,
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

    func saveEvent(_ request: EventStoreEventMutationRequest) throws -> EventStoreEventDescriptor {
        guard request.end > request.start else {
            throw EventStoreMutationError.invalidDateRange
        }

        guard let calendar = eventStore.calendars(for: .event).first(where: {
            $0.calendarIdentifier == request.calendarIdentifier
        }) else {
            throw EventStoreMutationError.calendarNotFound(request.calendarIdentifier)
        }

        let event: EKEvent
        if let identifier = request.identifier {
            guard let existingEvent = eventStore.event(withIdentifier: identifier) else {
                throw EventStoreMutationError.eventNotFound(identifier)
            }

            event = existingEvent
        } else {
            event = EKEvent(eventStore: eventStore)
        }

        event.calendar = calendar
        event.title = request.title
        event.startDate = request.start
        event.endDate = request.end
        event.isAllDay = request.isAllDay

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
        } catch {
            throw EventStoreMutationError.saveFailed(error.localizedDescription)
        }

        return EventStoreEventDescriptor(
            identifier: event.eventIdentifier,
            calendarIdentifier: event.calendar.calendarIdentifier,
            title: event.title,
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendarTitle: event.calendar.title
        )
    }

    func deleteEvent(withIdentifier identifier: String) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            throw EventStoreMutationError.eventNotFound(identifier)
        }

        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
        } catch {
            throw EventStoreMutationError.saveFailed(error.localizedDescription)
        }
    }

    func observeStoreChanges(
        _ onChange: @escaping @MainActor @Sendable () -> Void
    ) -> any CalendarChangeObservation {
        EventKitCalendarChangeObservation(
            eventStore: eventStore,
            onChange: onChange
        )
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

private final class EventKitCalendarChangeObservation: CalendarChangeObservation {
    private let notificationCenter: NotificationCenter
    private var token: NSObjectProtocol?

    init(
        eventStore: EKEventStore,
        notificationCenter: NotificationCenter = .default,
        onChange: @escaping @MainActor @Sendable () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.token = notificationCenter.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
        ) { _ in
            Task { @MainActor in
                onChange()
            }
        }
    }

    func invalidate() {
        guard let token else {
            return
        }

        notificationCenter.removeObserver(token)
        self.token = nil
    }

    deinit {
        invalidate()
    }
}

func normalizedEventTitle(_ title: String?) -> String {
    let cleanedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return cleanedTitle.isEmpty ? "Untitled Event" : cleanedTitle
}
