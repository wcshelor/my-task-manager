import Foundation

enum PlannerHorizon: String, CaseIterable, Identifiable, Sendable {
    case nextTwoHours
    case restOfToday
    case tomorrow
    case nextSevenDays

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .nextTwoHours:
            return "Next 2 Hours"
        case .restOfToday:
            return "Rest of Today"
        case .tomorrow:
            return "Tomorrow"
        case .nextSevenDays:
            return "Next 7 Days"
        }
    }

    func planningWindow(
        relativeTo referenceDate: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? startOfToday.addingTimeInterval(86_400)

        switch self {
        case .nextTwoHours:
            return DateInterval(
                start: referenceDate,
                end: referenceDate.addingTimeInterval(2 * 60 * 60)
            )
        case .restOfToday:
            return DateInterval(start: referenceDate, end: startOfTomorrow)
        case .tomorrow:
            let endOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfTomorrow)
                ?? startOfTomorrow.addingTimeInterval(86_400)
            return DateInterval(start: startOfTomorrow, end: endOfTomorrow)
        case .nextSevenDays:
            return DateInterval(
                start: referenceDate,
                end: referenceDate.addingTimeInterval(7 * 86_400)
            )
        }
    }
}

enum PlannerRequestWindow: Equatable, Sendable {
    case selectedTimeRange(PlannerSelectedTimeRange)
    case horizon(PlannerHorizon)

    var title: String {
        switch self {
        case .selectedTimeRange:
            return "Selected Slot"
        case .horizon(let horizon):
            return horizon.title
        }
    }

    func planningWindow(
        relativeTo referenceDate: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        switch self {
        case .selectedTimeRange(let selectedTimeRange):
            return selectedTimeRange.interval
        case .horizon(let horizon):
            return horizon.planningWindow(relativeTo: referenceDate, calendar: calendar)
        }
    }
}

struct PlannerFilterState: Equatable, Sendable {
    var workMode: WorkModeKind?
    var selectedTags: Set<String>
    var priorityEmphasis: PlannerPriorityEmphasis

    nonisolated init(
        workMode: WorkModeKind? = nil,
        selectedTags: Set<String> = [],
        priorityEmphasis: PlannerPriorityEmphasis = .balanced
    ) {
        self.workMode = workMode
        self.selectedTags = selectedTags
        self.priorityEmphasis = priorityEmphasis
    }
}

enum PlannerSuggestionDecision: String, Equatable, Sendable {
    case pending
    case accepted
}

struct PlannerSuggestionItem: Identifiable, Equatable, Sendable {
    let candidate: SuggestionCandidate
    var decision: PlannerSuggestionDecision

    init(
        candidate: SuggestionCandidate,
        decision: PlannerSuggestionDecision = .pending
    ) {
        self.candidate = candidate
        self.decision = decision
    }

    var id: UUID {
        candidate.id
    }

    var taskID: UUID {
        candidate.taskID
    }

    var taskTitle: String {
        candidate.task.title
    }

    var interval: DateInterval {
        candidate.suggestedInterval
    }

    var explanation: String {
        candidate.explanation
    }
}

struct PlannerScheduledBlockItem: Identifiable, Equatable, Sendable {
    let block: ScheduledBlock
    let taskTitle: String

    var id: UUID {
        block.id
    }

    var interval: DateInterval {
        block.interval
    }
}

enum PlannerMorningEnergy: String, CaseIterable, Identifiable, Equatable, Sendable {
    case low
    case normal
    case high

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        }
    }
}

enum PlannerMorningBriefAction: Equatable, Sendable {
    case requestCalendarAccess
    case openCalendarSetup
    case planToday
    case reviewTasks
}

struct PlannerMorningBriefMetric: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let value: String
}

struct PlannerMorningBrief: Equatable, Sendable {
    let title: String
    let message: String
    let calendarStatus: String
    let scheduledSummary: String
    let taskSummary: String
    let actionTitle: String
    let actionMessage: String
    let action: PlannerMorningBriefAction
    let energy: PlannerMorningEnergy?
    let metrics: [PlannerMorningBriefMetric]
}

enum PlannerTimelineEntry: Identifiable, Equatable {
    case calendarEvent(CalendarEventSnapshot)
    case scheduledBlock(PlannerScheduledBlockItem)
    case suggestion(PlannerSuggestionItem)

    var id: String {
        switch self {
        case .calendarEvent(let event):
            return "event:\(event.identifier ?? event.title)-\(event.start.timeIntervalSince1970)"
        case .scheduledBlock(let item):
            return "block:\(item.id.uuidString)"
        case .suggestion(let item):
            return "suggestion:\(item.id.uuidString)"
        }
    }

    var start: Date {
        switch self {
        case .calendarEvent(let event):
            return event.start
        case .scheduledBlock(let item):
            return item.interval.start
        case .suggestion(let item):
            return item.interval.start
        }
    }

    var end: Date {
        switch self {
        case .calendarEvent(let event):
            return event.end
        case .scheduledBlock(let item):
            return item.interval.end
        case .suggestion(let item):
            return item.interval.end
        }
    }

    var isAllDay: Bool {
        switch self {
        case .calendarEvent(let event):
            return event.isAllDay
        case .scheduledBlock(let item):
            return item.block.isAllDay
        case .suggestion:
            return false
        }
    }
}
