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
