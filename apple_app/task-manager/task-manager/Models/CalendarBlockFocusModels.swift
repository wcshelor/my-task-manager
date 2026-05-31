import Foundation

nonisolated enum CalendarProjectMatchStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case inferred
    case ambiguous

    var id: Self { self }
}

nonisolated struct CalendarProjectMatchResult: Equatable, Sendable {
    let matchingProjectIDs: [UUID]

    var status: CalendarProjectMatchStatus {
        switch matchingProjectIDs.count {
        case 0:
            return .none
        case 1:
            return .inferred
        default:
            return .ambiguous
        }
    }

    var matchedProjectID: UUID? {
        matchingProjectIDs.count == 1 ? matchingProjectIDs.first : nil
    }

    var isAmbiguous: Bool {
        matchingProjectIDs.count > 1
    }

    var isConfirmed: Bool {
        matchedProjectID != nil
    }
}

nonisolated struct CalendarProjectMatcher {
    private static let genericSingleWordProjectNames: Set<String> = [
        "admin",
        "calendar",
        "event",
        "focus",
        "home",
        "life",
        "meeting",
        "notes",
        "personal",
        "project",
        "task",
        "work",
        "today",
    ]

    func match(
        eventTitle: String,
        projects: [Project]
    ) -> CalendarProjectMatchResult {
        let normalizedEventTitle = Self.normalizedText(eventTitle)
        guard normalizedEventTitle.isEmpty == false else {
            return CalendarProjectMatchResult(matchingProjectIDs: [])
        }

        let eventTokens = Self.tokens(from: normalizedEventTitle)
        let matchingProjectIDs = projects.compactMap { project -> UUID? in
            guard Self.matches(eventTokens: eventTokens, eventTitle: normalizedEventTitle, project: project) else {
                return nil
            }

            return project.id
        }
        .sorted { leftID, rightID in
            leftID.uuidString < rightID.uuidString
        }

        return CalendarProjectMatchResult(matchingProjectIDs: matchingProjectIDs)
    }

    func match(
        eventTitle: String,
        project: Project
    ) -> Bool {
        match(eventTitle: eventTitle, projects: [project]).isConfirmed
    }

    private static func matches(
        eventTokens: [String],
        eventTitle: String,
        project: Project
    ) -> Bool {
        let normalizedProjectName = normalizedText(project.name)
        guard normalizedProjectName.isEmpty == false else {
            return false
        }

        if normalizedProjectName == eventTitle {
            return true
        }

        let projectTokens = tokens(from: normalizedProjectName)
        guard projectTokens.isEmpty == false else {
            return false
        }

        if projectTokens.count == 1 {
            let token = projectTokens[0]
            guard token.count >= 4 else {
                return false
            }

            guard genericSingleWordProjectNames.contains(token) == false else {
                return false
            }

            return eventTokens.contains(token)
        }

        return eventTokens.containsContiguousPhrase(projectTokens)
    }

    private static func normalizedText(_ value: String) -> String {
        let folded = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let sanitizedScalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) {
                return Character(scalar)
            }

            return " "
        }

        return String(sanitizedScalars)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private static func tokens(from normalizedText: String) -> [String] {
        normalizedText
            .split(separator: " ")
            .map(String.init)
    }
}

private extension Array where Element == String {
    func containsContiguousPhrase(_ phraseTokens: [String]) -> Bool {
        guard phraseTokens.isEmpty == false, count >= phraseTokens.count else {
            return false
        }

        guard phraseTokens.count > 1 else {
            return contains(phraseTokens[0])
        }

        let windowCount = phraseTokens.count
        for startIndex in indices where startIndex + windowCount <= count {
            let window = self[startIndex..<(startIndex + windowCount)]
            if Array(window) == phraseTokens {
                return true
            }
        }

        return false
    }
}

nonisolated struct CalendarBlockFocus: Identifiable, Equatable, Sendable {
    let id: UUID
    let eventKey: String
    var eventIdentifier: String
    var calendarIdentifier: String
    var titleSnapshot: String
    var startDateSnapshot: Date
    var endDateSnapshot: Date
    var linkedProjectID: UUID?
    var selectedTaskIDs: [UUID]
    var intentionNote: String?
    var preferredDebriefTemplateKind: DebriefTemplateKind?
    var isProjectLinkUserConfirmed: Bool
    var isNoFocusNeeded: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        eventKey: String,
        eventIdentifier: String,
        calendarIdentifier: String,
        titleSnapshot: String,
        startDateSnapshot: Date,
        endDateSnapshot: Date,
        linkedProjectID: UUID? = nil,
        selectedTaskIDs: [UUID] = [],
        intentionNote: String? = nil,
        preferredDebriefTemplateKind: DebriefTemplateKind? = nil,
        isProjectLinkUserConfirmed: Bool = false,
        isNoFocusNeeded: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.eventKey = eventKey
        self.eventIdentifier = Self.cleanedIdentifier(eventIdentifier)
        self.calendarIdentifier = Self.cleanedIdentifier(calendarIdentifier)
        self.titleSnapshot = Self.cleanedTitle(titleSnapshot)
        self.startDateSnapshot = startDateSnapshot
        self.endDateSnapshot = endDateSnapshot
        self.linkedProjectID = linkedProjectID
        self.selectedTaskIDs = Self.cleanedIDs(selectedTaskIDs)
        self.intentionNote = MyTask.cleanedOptionalText(from: intentionNote)
        self.preferredDebriefTemplateKind = preferredDebriefTemplateKind
        self.isProjectLinkUserConfirmed = isProjectLinkUserConfirmed
        self.isNoFocusNeeded = isNoFocusNeeded
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(
        event: CalendarEventSnapshot,
        linkedProjectID: UUID? = nil,
        selectedTaskIDs: [UUID] = [],
        intentionNote: String? = nil,
        preferredDebriefTemplateKind: DebriefTemplateKind? = nil,
        isProjectLinkUserConfirmed: Bool = false,
        isNoFocusNeeded: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        guard
            let eventIdentifier = event.identifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            eventIdentifier.isEmpty == false,
            let calendarIdentifier = event.calendarIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            calendarIdentifier.isEmpty == false
        else {
            return nil
        }

        self.init(
            id: UUID(),
            eventKey: DebriefEventKey.from(
                eventIdentifier: eventIdentifier,
                title: event.title,
                start: event.start,
                end: event.end,
                calendarIdentifier: calendarIdentifier,
                calendarTitle: event.calendarTitle
            ),
            eventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier,
            titleSnapshot: event.title,
            startDateSnapshot: event.start,
            endDateSnapshot: event.end,
            linkedProjectID: linkedProjectID,
            selectedTaskIDs: selectedTaskIDs,
            intentionNote: intentionNote,
            preferredDebriefTemplateKind: preferredDebriefTemplateKind,
            isProjectLinkUserConfirmed: isProjectLinkUserConfirmed,
            isNoFocusNeeded: isNoFocusNeeded,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    var selectedTaskCount: Int {
        selectedTaskIDs.count
    }

    var durationMinutes: Int {
        max(0, Int(endDateSnapshot.timeIntervalSince(startDateSnapshot) / 60))
    }

    var hasProjectLink: Bool {
        linkedProjectID != nil
    }

    var isProjectLinkConfirmed: Bool {
        linkedProjectID != nil && isProjectLinkUserConfirmed
    }

    private static func cleanedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanedTitle(_ value: String) -> String {
        MyTask.cleanedTitle(from: value) ?? "Untitled Event"
    }

    private static func cleanedIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}

nonisolated enum DebriefTaskOutcomeStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case completed
    case partlyDone
    case stillOpen
    case blocked
    case notTouched

    var id: Self { self }

    var displayName: String {
        switch self {
        case .completed:
            return "Completed"
        case .partlyDone:
            return "Partly done"
        case .stillOpen:
            return "Still open"
        case .blocked:
            return "Blocked"
        case .notTouched:
            return "Not touched"
        }
    }
}

nonisolated struct DebriefTaskOutcome: Identifiable, Equatable, Sendable {
    let id: UUID
    var debriefID: UUID
    var taskID: UUID
    var taskTitleSnapshot: String
    var outcome: DebriefTaskOutcomeStatus
    var note: String?
    var didUpdateTaskStatus: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        debriefID: UUID,
        taskID: UUID,
        taskTitleSnapshot: String,
        outcome: DebriefTaskOutcomeStatus,
        note: String? = nil,
        didUpdateTaskStatus: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.debriefID = debriefID
        self.taskID = taskID
        self.taskTitleSnapshot = MyTask.cleanedTitle(from: taskTitleSnapshot) ?? "Untitled Task"
        self.outcome = outcome
        self.note = MyTask.cleanedOptionalText(from: note)
        self.didUpdateTaskStatus = didUpdateTaskStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

nonisolated struct CalendarBlockFocusTaskSuggestionService {
    func suggestedTasks(
        for project: Project,
        tasks: [MyTask],
        blockDurationMinutes: Int?
    ) -> [MyTask] {
        tasks
            .filter { task in
                task.projectID == project.id
                    && task.status != .done
                    && task.status != .archived
            }
            .sorted { leftTask, rightTask in
                Self.isHigherRanked(
                    leftTask,
                    than: rightTask,
                    blockDurationMinutes: blockDurationMinutes
                )
            }
    }

    private static func isHigherRanked(
        _ leftTask: MyTask,
        than rightTask: MyTask,
        blockDurationMinutes: Int?
    ) -> Bool {
        switch (leftTask.dueDate, rightTask.dueDate) {
        case (.some(let leftDueDate), .some(let rightDueDate)):
            if leftDueDate != rightDueDate {
                return leftDueDate < rightDueDate
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        let leftPriorityRank = priorityRank(for: leftTask.priority)
        let rightPriorityRank = priorityRank(for: rightTask.priority)
        if leftPriorityRank != rightPriorityRank {
            return leftPriorityRank < rightPriorityRank
        }

        if let blockDurationMinutes {
            let leftFits = estimatedMinutesFitsBlock(leftTask.estimatedMinutes, blockDurationMinutes)
            let rightFits = estimatedMinutesFitsBlock(rightTask.estimatedMinutes, blockDurationMinutes)
            if leftFits != rightFits {
                return leftFits && rightFits == false
            }

            let leftEstimated = leftTask.estimatedMinutes ?? Int.max
            let rightEstimated = rightTask.estimatedMinutes ?? Int.max
            if leftEstimated != rightEstimated {
                return leftEstimated < rightEstimated
            }
        }

        if leftTask.updatedAt != rightTask.updatedAt {
            return leftTask.updatedAt > rightTask.updatedAt
        }

        if leftTask.createdAt != rightTask.createdAt {
            return leftTask.createdAt > rightTask.createdAt
        }

        return leftTask.title.localizedCaseInsensitiveCompare(rightTask.title) == .orderedAscending
    }

    private static func priorityRank(for priority: PriorityLevel?) -> Int {
        switch priority {
        case .urgent:
            return 0
        case .high:
            return 1
        case .medium:
            return 2
        case .low:
            return 3
        case .none:
            return Int.max
        }
    }

    private static func estimatedMinutesFitsBlock(
        _ estimatedMinutes: Int?,
        _ blockDurationMinutes: Int
    ) -> Bool {
        guard let estimatedMinutes else {
            return false
        }

        return estimatedMinutes <= blockDurationMinutes
    }
}
