import Foundation

enum ScheduledBlockStatus: String, CaseIterable, Codable, Sendable {
    case proposed
    case accepted
    case rejected
    case canceled
    case completed
    case deletedExternally
}

enum CalendarLinkState: String, CaseIterable, Codable, Sendable {
    case notWritten
    case writePending
    case linked
    case movedExternally
    case deletedExternally
    case identifierStale
    case syncError
}

struct ScheduledBlock: Identifiable, Equatable, Sendable {
    let id: UUID
    var taskID: UUID
    var start: Date
    var end: Date
    var status: ScheduledBlockStatus
    var calendarLinkState: CalendarLinkState
    var calendarEventIdentifier: String?
    var calendarTitle: String?
    var eventTitleSnapshot: String?
    let createdAt: Date
    var updatedAt: Date
    var lastSyncedAt: Date?
    var syncErrorMessage: String?
    var isAllDay: Bool

    init(
        id: UUID = UUID(),
        taskID: UUID,
        start: Date,
        end: Date,
        status: ScheduledBlockStatus = .proposed,
        calendarLinkState: CalendarLinkState = .notWritten,
        calendarEventIdentifier: String? = nil,
        calendarTitle: String? = nil,
        eventTitleSnapshot: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        syncErrorMessage: String? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.taskID = taskID
        self.start = start
        self.end = end
        self.status = status
        self.calendarLinkState = calendarLinkState
        self.calendarEventIdentifier = calendarEventIdentifier
        self.calendarTitle = calendarTitle
        self.eventTitleSnapshot = eventTitleSnapshot
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.lastSyncedAt = lastSyncedAt
        self.syncErrorMessage = syncErrorMessage
        self.isAllDay = isAllDay
    }

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    var isActivelyScheduled: Bool {
        status == .accepted && calendarLinkState != .deletedExternally
    }
}

struct AppSettings: Equatable, Sendable {
    var excludedReadCalendarTitles: [String]
    var writeCalendarTitle: String
    var minimumGapMinutes: Int
    var defaultAssumedDurationMinutes: Int
    var plannerSuggestionCap: Int

    static let mvpDefault = AppSettings(
        excludedReadCalendarTitles: ["Birthdays"],
        writeCalendarTitle: "Important",
        minimumGapMinutes: 15,
        defaultAssumedDurationMinutes: 30,
        plannerSuggestionCap: 5
    )
}
