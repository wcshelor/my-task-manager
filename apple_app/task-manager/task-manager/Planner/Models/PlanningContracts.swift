import Foundation

struct CalendarEventSnapshot: Sendable, Equatable {
    let identifier: String?
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }
}

enum BusySource: Sendable, Equatable {
    case calendarEvent(identifier: String?)
    case scheduledBlock(blockID: UUID)
}

struct BusyInterval: Sendable, Equatable {
    let start: Date
    let end: Date
    let source: BusySource

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }
}

struct FreeGap: Identifiable, Sendable, Equatable {
    let id: UUID
    let start: Date
    let end: Date

    init(
        id: UUID = UUID(),
        start: Date,
        end: Date
    ) {
        self.id = id
        self.start = start
        self.end = end
    }

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

struct TaskPlanningInput: Sendable, Equatable {
    let task: MyTask
    let busyIntervals: [BusyInterval]
    let timeWindow: DateInterval
    let settings: AppSettings
}

struct SuggestionCandidate: Identifiable, Sendable, Equatable {
    let id: UUID
    let taskID: UUID
    let suggestedInterval: DateInterval
    let score: Double
    let explanation: String

    init(
        id: UUID = UUID(),
        taskID: UUID,
        suggestedInterval: DateInterval,
        score: Double,
        explanation: String
    ) {
        self.id = id
        self.taskID = taskID
        self.suggestedInterval = suggestedInterval
        self.score = score
        self.explanation = explanation
    }
}

struct PlannerOutput: Sendable, Equatable {
    let suggestions: [SuggestionCandidate]
}
