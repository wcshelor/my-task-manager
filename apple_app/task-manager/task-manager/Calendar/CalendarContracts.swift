import Foundation

nonisolated enum CalendarPermissionStatus: Equatable, Sendable {
    case notDetermined
    case fullAccessGranted
    case writeOnlyGrantedButInsufficient
    case denied
    case restricted
    case error(String)
}

nonisolated struct CalendarWriteResult: Equatable, Sendable {
    let eventIdentifier: String
    let calendarTitle: String
    let eventTitle: String
    let writtenAt: Date

    init(
        eventIdentifier: String,
        calendarTitle: String,
        eventTitle: String,
        writtenAt: Date = .now
    ) {
        self.eventIdentifier = eventIdentifier
        self.calendarTitle = calendarTitle
        self.eventTitle = eventTitle
        self.writtenAt = writtenAt
    }
}

struct ReadableCalendar: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let allowsContentModifications: Bool
    let isExcludedBySettings: Bool
}

struct ReconciliationIssue: Identifiable, Equatable, Sendable {
    let id: UUID
    let blockID: UUID
    let message: String

    init(
        id: UUID = UUID(),
        blockID: UUID,
        message: String
    ) {
        self.id = id
        self.blockID = blockID
        self.message = message
    }
}

struct ReconciliationReport: Equatable, Sendable {
    var reconciledBlockCount: Int
    var movedBlockCount: Int
    var deletedBlockCount: Int
    var issues: [ReconciliationIssue]

    static let empty = ReconciliationReport(
        reconciledBlockCount: 0,
        movedBlockCount: 0,
        deletedBlockCount: 0,
        issues: []
    )
}

@MainActor
protocol CalendarReading {
    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot]
}

@MainActor
protocol CalendarListing {
    func fetchReadableCalendars() async throws -> [ReadableCalendar]
}

@MainActor
protocol CalendarWriting {
    func validateWriteCalendar() async throws -> String
    func createEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult
    func updateEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult
    func deleteEvent(for block: ScheduledBlock) async throws
}

@MainActor
protocol CalendarReconciling {
    func reconcileScheduledBlocks() async throws -> ReconciliationReport
}

@MainActor
protocol CalendarPermissionProviding {
    func currentStatus() -> CalendarPermissionStatus
    func requestFullAccess() async -> CalendarPermissionStatus
}
