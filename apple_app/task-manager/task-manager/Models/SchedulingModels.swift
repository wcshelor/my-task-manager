import Foundation

nonisolated enum ScheduledBlockStatus: String, CaseIterable, Codable, Sendable {
    case proposed
    case accepted
    case rejected
    case canceled
    case completed
    case deletedExternally
}

nonisolated enum CalendarLinkState: String, CaseIterable, Codable, Sendable {
    case notWritten
    case writePending
    case linked
    case movedExternally
    case deletedExternally
    case identifierStale
    case syncError
}

nonisolated struct ScheduledBlock: Identifiable, Equatable, Sendable {
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

nonisolated struct AppSettings: Equatable, Sendable {
    var excludedReadCalendarTitles: [String]
    var writeCalendarTitle: String
    var minimumGapMinutes: Int
    private var storedDefaultAssumedDurationMinutes: Int
    var defaultAssumedDurationMinutes: Int {
        get {
            storedDefaultAssumedDurationMinutes
        }
        set {
            storedDefaultAssumedDurationMinutes =
                TaskDurationRules.cleanedDefaultAssumedDurationMinutes(newValue)
        }
    }
    var plannerSuggestionCap: Int

    init(
        excludedReadCalendarTitles: [String],
        writeCalendarTitle: String,
        minimumGapMinutes: Int,
        defaultAssumedDurationMinutes: Int,
        plannerSuggestionCap: Int
    ) {
        self.excludedReadCalendarTitles = excludedReadCalendarTitles
        self.writeCalendarTitle = writeCalendarTitle
        self.minimumGapMinutes = max(1, minimumGapMinutes)
        self.storedDefaultAssumedDurationMinutes =
            TaskDurationRules.cleanedDefaultAssumedDurationMinutes(defaultAssumedDurationMinutes)
        self.plannerSuggestionCap = max(0, plannerSuggestionCap)
    }

    static let mvpDefault = AppSettings(
        excludedReadCalendarTitles: ["Birthdays"],
        writeCalendarTitle: "Important",
        minimumGapMinutes: 15,
        defaultAssumedDurationMinutes: 30,
        plannerSuggestionCap: 5
    )
}
