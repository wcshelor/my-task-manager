import Foundation

nonisolated enum TaskStatus: String, CaseIterable, Codable, Sendable {
    case inbox
    case active
    case scheduled
    case completed
    case archived

    var displayName: String {
        switch self {
        case .inbox:
            return "Inbox"
        case .active:
            return "Active"
        case .scheduled:
            return "Scheduled"
        case .completed:
            return "Completed"
        case .archived:
            return "Archived"
        }
    }
}

nonisolated enum PriorityLevel: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high
    case urgent

    var displayName: String {
        rawValue.capitalized
    }
}

nonisolated enum EnergyLevel: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high

    var displayName: String {
        rawValue.capitalized
    }
}

nonisolated enum WorkModeKind: String, CaseIterable, Codable, Sendable {
    case deepWork
    case shallowAdmin
    case creative
    case practice
    case errand
    case flexible

    var displayName: String {
        switch self {
        case .deepWork:
            return "Deep Work"
        case .shallowAdmin:
            return "Shallow Admin"
        case .creative:
            return "Creative"
        case .practice:
            return "Practice"
        case .errand:
            return "Errand"
        case .flexible:
            return "Flexible"
        }
    }
}

nonisolated struct Project: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var summary: String?
    var isPinned: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        summary: String? = nil,
        isPinned: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = Self.cleanedName(from: name) ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = MyTask.cleanedOptionalText(from: summary)
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init?(newName: String) {
        guard let cleanedName = Self.cleanedName(from: newName) else {
            return nil
        }

        self.init(name: cleanedName)
    }

    static func cleanedName(from rawName: String) -> String? {
        let cleanedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedName.isEmpty ? nil : cleanedName
    }
}

nonisolated struct ProjectTaskSummary: Equatable, Sendable {
    let projectID: UUID
    let activeTasks: [MyTask]

    init(project: Project, tasks: [MyTask]) {
        self.init(projectID: project.id, tasks: tasks)
    }

    init(projectID: UUID, tasks: [MyTask]) {
        self.projectID = projectID
        self.activeTasks = tasks
            .filter { task in
                task.projectID == projectID && task.status != .archived
            }
            .sorted { leftTask, rightTask in
                if leftTask.createdAt != rightTask.createdAt {
                    return leftTask.createdAt < rightTask.createdAt
                }

                return leftTask.id.uuidString < rightTask.id.uuidString
            }
    }

    var activeTaskCount: Int {
        activeTasks.count
    }

    var completedActiveTaskCount: Int {
        activeTasks.filter { $0.status == .completed }.count
    }

    var incompleteActiveTaskCount: Int {
        activeTasks.filter { $0.status != .completed }.count
    }

    var progressFraction: Double {
        guard activeTaskCount > 0 else {
            return 0
        }

        return Double(completedActiveTaskCount) / Double(activeTaskCount)
    }

    var progressSummary: String {
        guard activeTaskCount > 0 else {
            return "No tasks"
        }

        return "\(completedActiveTaskCount)/\(activeTaskCount) tasks complete"
    }

    var nextAction: MyTask? {
        nextActions(limit: 1).first
    }

    func nextActions(limit: Int? = nil) -> [MyTask] {
        let sortedActions = Self.sortedNextActions(from: activeTasks)

        guard let limit else {
            return sortedActions
        }

        return Array(sortedActions.prefix(limit))
    }

    static func sortedNextActions(from tasks: [MyTask]) -> [MyTask] {
        tasks
            .filter { task in
                task.status != .completed && task.status != .archived
            }
            .sorted(by: isHigherRankedNextAction)
    }

    private static func isHigherRankedNextAction(
        _ leftTask: MyTask,
        _ rightTask: MyTask
    ) -> Bool {
        // Deterministic project next-action order: due date, priority, creation date, UUID.
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

        let leftPriorityRank = leftTask.priority?.projectNextActionRank ?? Int.max
        let rightPriorityRank = rightTask.priority?.projectNextActionRank ?? Int.max
        if leftPriorityRank != rightPriorityRank {
            return leftPriorityRank < rightPriorityRank
        }

        if leftTask.createdAt != rightTask.createdAt {
            return leftTask.createdAt < rightTask.createdAt
        }

        return leftTask.id.uuidString < rightTask.id.uuidString
    }
}

extension Project {
    nonisolated func taskSummary(from tasks: [MyTask]) -> ProjectTaskSummary {
        ProjectTaskSummary(project: self, tasks: tasks)
    }
}

nonisolated enum ProjectItemKind: String, CaseIterable, Codable, Sendable {
    case maybe
    case note

    var displayName: String {
        switch self {
        case .maybe:
            return "Maybe"
        case .note:
            return "Note"
        }
    }
}

nonisolated enum ProjectItemPressure: String, CaseIterable, Codable, Sendable {
    case noPressure
    case useful
    case shouldDoSometime
    case becomingRelevant

    var displayName: String {
        switch self {
        case .noPressure:
            return "No Pressure"
        case .useful:
            return "Useful"
        case .shouldDoSometime:
            return "Should Do Sometime"
        case .becomingRelevant:
            return "Becoming Relevant"
        }
    }
}

nonisolated struct ProjectItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var projectID: UUID
    var kind: ProjectItemKind
    var title: String
    var notes: String?
    var source: String?
    var pressure: ProjectItemPressure?
    var reviewAfter: Date?
    var promotedTaskID: UUID?
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectID: UUID,
        kind: ProjectItemKind,
        title: String,
        notes: String? = nil,
        source: String? = nil,
        pressure: ProjectItemPressure? = nil,
        reviewAfter: Date? = nil,
        promotedTaskID: UUID? = nil,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.kind = kind
        self.title = Self.cleanedTitle(from: title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.source = MyTask.cleanedOptionalText(from: source)
        self.pressure = pressure
        self.reviewAfter = reviewAfter
        self.promotedTaskID = promotedTaskID
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    static func cleanedTitle(from rawTitle: String) -> String? {
        let cleanedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? nil : cleanedTitle
    }
}

nonisolated struct CaptureItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var projectID: UUID?
    var source: String?
    let createdAt: Date
    var updatedAt: Date
    var processedAt: Date?
    var archivedAt: Date?
    var convertedTaskID: UUID?
    var convertedProjectItemID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        projectID: UUID? = nil,
        source: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        processedAt: Date? = nil,
        archivedAt: Date? = nil,
        convertedTaskID: UUID? = nil,
        convertedProjectItemID: UUID? = nil
    ) {
        self.id = id
        self.title = Self.cleanedTitle(from: title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = MyTask.cleanedOptionalText(from: notes)
        self.projectID = projectID
        self.source = MyTask.cleanedOptionalText(from: source)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.processedAt = processedAt
        self.archivedAt = archivedAt
        self.convertedTaskID = convertedTaskID
        self.convertedProjectItemID = convertedProjectItemID
    }

    init?(newTitle: String, projectID: UUID? = nil) {
        guard let cleanedTitle = Self.cleanedTitle(from: newTitle) else {
            return nil
        }

        self.init(title: cleanedTitle, projectID: projectID)
    }

    var isPendingReview: Bool {
        processedAt == nil && archivedAt == nil
    }

    mutating func markProcessed(
        at date: Date = .now,
        convertedTaskID: UUID? = nil,
        convertedProjectItemID: UUID? = nil
    ) {
        processedAt = date
        updatedAt = date
        self.convertedTaskID = convertedTaskID
        self.convertedProjectItemID = convertedProjectItemID
    }

    mutating func archive(at date: Date = .now) {
        archivedAt = date
        updatedAt = date
    }

    static func cleanedTitle(from rawTitle: String) -> String? {
        let cleanedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? nil : cleanedTitle
    }
}

nonisolated enum TaskDurationRules {
    static let minutesIncrement = 15
    static let defaultAssumedMinutes = 30

    static func isValidEstimatedMinutes(_ estimatedMinutes: Int) -> Bool {
        estimatedMinutes > 0 && estimatedMinutes.isMultiple(of: minutesIncrement)
    }

    static func cleanedEstimatedMinutes(_ estimatedMinutes: Int?) -> Int? {
        guard let estimatedMinutes else {
            return nil
        }

        guard isValidEstimatedMinutes(estimatedMinutes) else {
            return nil
        }

        return estimatedMinutes
    }

    static func cleanedDefaultAssumedDurationMinutes(_ estimatedMinutes: Int) -> Int {
        cleanedEstimatedMinutes(estimatedMinutes) ?? defaultAssumedMinutes
    }

    static func normalizedFormSelectionMinutes(_ estimatedMinutes: Int) -> Int {
        let adjustedMinutes = max(minutesIncrement, estimatedMinutes)
        let remainder = adjustedMinutes % minutesIncrement

        guard remainder != 0 else {
            return adjustedMinutes
        }

        return adjustedMinutes + (minutesIncrement - remainder)
    }
}

nonisolated struct MyTask: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var status: TaskStatus
    private var storedEstimatedMinutes: Int?
    var estimatedMinutes: Int? {
        get {
            storedEstimatedMinutes
        }
        set {
            storedEstimatedMinutes = TaskDurationRules.cleanedEstimatedMinutes(newValue)
        }
    }
    var dueDate: Date?
    var priority: PriorityLevel?
    var energyLevel: EnergyLevel?
    var workMode: WorkModeKind?
    var projectID: UUID?
    var taskGroup: String?
    var tags: [String]
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    var isDone: Bool {
        status == .completed
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        status: TaskStatus = .inbox,
        estimatedMinutes: Int? = nil,
        dueDate: Date? = nil,
        priority: PriorityLevel? = nil,
        energyLevel: EnergyLevel? = nil,
        workMode: WorkModeKind? = nil,
        projectID: UUID? = nil,
        taskGroup: String? = nil,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        let cleanedUpdatedAt = updatedAt ?? createdAt

        self.id = id
        self.title = Self.cleanedTitle(from: title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = Self.cleanedOptionalText(from: notes)
        self.status = status
        self.storedEstimatedMinutes = TaskDurationRules.cleanedEstimatedMinutes(estimatedMinutes)
        self.dueDate = dueDate
        self.priority = priority
        self.energyLevel = energyLevel
        self.workMode = workMode
        self.projectID = projectID
        self.taskGroup = Self.cleanedOptionalText(from: taskGroup)
        self.tags = Self.cleanedTags(from: tags)
        self.createdAt = createdAt
        self.updatedAt = cleanedUpdatedAt
        self.completedAt = status == .completed ? (completedAt ?? cleanedUpdatedAt) : nil
    }

    init?(newTitle: String) {
        guard let cleanedTitle = Self.cleanedTitle(from: newTitle) else {
            return nil
        }

        self.init(title: cleanedTitle)
    }

    static let sampleTasks = [
        MyTask(
            title: "Draft client launch brief",
            notes: "Clarify milestones, owners, and Friday review questions.",
            status: .active,
            estimatedMinutes: 90,
            dueDate: .now.addingTimeInterval(2 * 86_400),
            priority: .high,
            energyLevel: .high,
            workMode: .deepWork,
            taskGroup: "Work",
            tags: ["client", "writing", "planning"]
        ),
        MyTask(
            title: "Clear finance inbox",
            notes: "File receipts and reply to the accountant.",
            status: .inbox,
            estimatedMinutes: 30,
            priority: .medium,
            energyLevel: .low,
            workMode: .shallowAdmin,
            taskGroup: "Admin",
            tags: ["finance", "email"]
        ),
        MyTask(
            title: "Buy groceries for the week",
            notes: "Produce, coffee, lunch staples, and dishwasher tabs.",
            status: .active,
            estimatedMinutes: 45,
            priority: .medium,
            energyLevel: .low,
            workMode: .errand,
            taskGroup: "Home",
            tags: ["home", "shopping", "errand"]
        ),
        MyTask(
            title: "Reply to partner follow-ups",
            notes: "Send short answers and move anything complex to the brief.",
            status: .completed,
            estimatedMinutes: 30,
            priority: .low,
            energyLevel: .medium,
            workMode: .shallowAdmin,
            taskGroup: "Work",
            tags: ["work", "admin", "email"]
        ),
        MyTask(
            title: "Practice presentation run-through",
            status: .active,
            estimatedMinutes: 60,
            dueDate: .now.addingTimeInterval(5 * 60 * 60),
            priority: .urgent,
            energyLevel: .medium,
            workMode: .practice,
            taskGroup: "Work",
            tags: ["presentation", "practice"]
        ),
        MyTask(
            title: "Sketch onboarding flow ideas",
            notes: "Capture three variants before turning them into tickets.",
            status: .inbox,
            estimatedMinutes: 75,
            priority: .medium,
            energyLevel: .high,
            workMode: .creative,
            taskGroup: "Product",
            tags: ["design", "creative"]
        ),
        MyTask(
            title: "Schedule dentist appointment",
            status: .inbox,
            estimatedMinutes: 15,
            priority: .low,
            energyLevel: .low,
            workMode: .flexible,
            taskGroup: "Personal",
            tags: ["health", "phone"]
        ),
        MyTask(
            title: "Archive old project notes",
            status: .archived,
            estimatedMinutes: 45,
            priority: .low,
            energyLevel: .low,
            workMode: .shallowAdmin,
            taskGroup: "Admin",
            tags: ["cleanup"]
        )
    ]

    static func cleanedTitle(from rawTitle: String) -> String? {
        let cleanedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? nil : cleanedTitle
    }

    static func cleanedOptionalText(from rawText: String?) -> String? {
        guard let rawText else {
            return nil
        }

        let cleanedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedText.isEmpty ? nil : cleanedText
    }

    static func cleanedEstimatedMinutes(_ estimatedMinutes: Int?) -> Int? {
        TaskDurationRules.cleanedEstimatedMinutes(estimatedMinutes)
    }

    static func cleanedTags(from rawTags: String) -> [String] {
        cleanedTags(from: rawTags.split(separator: ",").map(String.init))
    }

    static func cleanedTags(from rawTags: [String]) -> [String] {
        rawTags.compactMap { rawTag in
            let cleanedTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedTag.isEmpty ? nil : cleanedTag
        }
    }

    func hasActiveScheduledBlock(in scheduledBlocks: [ScheduledBlock]) -> Bool {
        scheduledBlocks.contains { scheduledBlock in
            scheduledBlock.taskID == id && scheduledBlock.isActivelyScheduled
        }
    }
}

extension Array where Element == MyTask {
    mutating func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID? = nil) {
        if let originalID, let originalIndex = firstIndex(where: { $0.id == originalID }) {
            self[originalIndex] = task
            return
        }

        if let existingIndex = firstIndex(where: { $0.id == task.id }) {
            self[existingIndex] = task
            return
        }

        append(task)
    }

    mutating func deleteTask(withID id: UUID) {
        removeAll { $0.id == id }
    }

    func containsTask(withID id: UUID, excluding excludedID: UUID? = nil) -> Bool {
        contains { task in
            task.id == id && task.id != excludedID
        }
    }

    func task(withID id: UUID) -> MyTask? {
        first { $0.id == id }
    }
}

private extension PriorityLevel {
    nonisolated var projectNextActionRank: Int {
        switch self {
        case .urgent:
            return 0
        case .high:
            return 1
        case .medium:
            return 2
        case .low:
            return 3
        }
    }
}
