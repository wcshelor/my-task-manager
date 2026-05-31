import Foundation

nonisolated struct CalendarEventSnapshot: Sendable, Equatable {
    let identifier: String?
    let calendarIdentifier: String?
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }
}

nonisolated enum BusySource: Sendable, Equatable, Hashable {
    case calendarEvent(identifier: String?)
    case scheduledBlock(blockID: UUID)
}

nonisolated struct BusyInterval: Sendable, Equatable {
    let start: Date
    let end: Date
    let sources: [BusySource]

    init(
        start: Date,
        end: Date,
        sources: [BusySource]
    ) {
        self.start = start
        self.end = end
        self.sources = sources
    }

    init(
        start: Date,
        end: Date,
        source: BusySource
    ) {
        self.init(start: start, end: end, sources: [source])
    }

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    var durationMinutes: Int {
        Int(interval.duration / 60)
    }
}

nonisolated struct FreeGap: Identifiable, Sendable, Equatable {
    let start: Date
    let end: Date

    var id: String {
        "\(start.timeIntervalSinceReferenceDate)-\(end.timeIntervalSinceReferenceDate)"
    }

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

nonisolated enum PlannerPriorityEmphasis: String, CaseIterable, Identifiable, Sendable {
    case balanced
    case highestPriority
    case dueSoon

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .balanced:
            return "Balanced"
        case .highestPriority:
            return "Highest Priority"
        case .dueSoon:
            return "Due Soon"
        }
    }
}

nonisolated struct PlannerConstraints: Sendable, Equatable {
    let planningWindow: DateInterval
    let now: Date
    let minimumGapMinutes: Int
    let defaultAssumedDurationMinutes: Int
    let suggestionCap: Int
    let priorityEmphasis: PlannerPriorityEmphasis

    init(
        planningWindow: DateInterval,
        now: Date,
        minimumGapMinutes: Int,
        defaultAssumedDurationMinutes: Int,
        suggestionCap: Int,
        priorityEmphasis: PlannerPriorityEmphasis
    ) {
        self.planningWindow = planningWindow
        self.now = now
        self.minimumGapMinutes = max(1, minimumGapMinutes)
        self.defaultAssumedDurationMinutes =
            TaskDurationRules.cleanedDefaultAssumedDurationMinutes(defaultAssumedDurationMinutes)
        self.suggestionCap = max(0, suggestionCap)
        self.priorityEmphasis = priorityEmphasis
    }
}

nonisolated struct SuggestionFingerprint: Hashable, Sendable {
    let taskID: UUID
    let start: Date
    let end: Date
}

nonisolated struct SuggestionCandidate: Identifiable, Sendable, Equatable {
    let id: UUID
    let task: MyTask
    let sourceGap: FreeGap
    let suggestedInterval: DateInterval
    let score: Double
    let explanation: String
    let assumedDurationMinutes: Int

    init(
        id: UUID = UUID(),
        task: MyTask,
        sourceGap: FreeGap,
        suggestedInterval: DateInterval,
        score: Double,
        explanation: String,
        assumedDurationMinutes: Int
    ) {
        self.id = id
        self.task = task
        self.sourceGap = sourceGap
        self.suggestedInterval = suggestedInterval
        self.score = score
        self.explanation = explanation
        self.assumedDurationMinutes = assumedDurationMinutes
    }

    var taskID: UUID {
        task.id
    }

    var fingerprint: SuggestionFingerprint {
        SuggestionFingerprint(
            taskID: task.id,
            start: suggestedInterval.start,
            end: suggestedInterval.end
        )
    }
}

nonisolated struct PlannerOutput: Sendable, Equatable {
    let busyIntervals: [BusyInterval]
    let freeGaps: [FreeGap]
    let suggestions: [SuggestionCandidate]
}
