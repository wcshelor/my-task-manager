import Foundation

enum TaskStatus: String, CaseIterable, Codable, Sendable {
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

enum PriorityLevel: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high
    case urgent

    var displayName: String {
        rawValue.capitalized
    }
}

enum EnergyLevel: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high

    var displayName: String {
        rawValue.capitalized
    }
}

enum WorkModeKind: String, CaseIterable, Codable, Sendable {
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

struct MyTask: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var status: TaskStatus
    var estimatedMinutes: Int?
    var dueDate: Date?
    var priority: PriorityLevel?
    var energyLevel: EnergyLevel?
    var workMode: WorkModeKind?
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
        status: TaskStatus = .active,
        estimatedMinutes: Int? = nil,
        dueDate: Date? = nil,
        priority: PriorityLevel? = nil,
        energyLevel: EnergyLevel? = nil,
        workMode: WorkModeKind? = nil,
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
        self.estimatedMinutes = Self.cleanedEstimatedMinutes(estimatedMinutes)
        self.dueDate = dueDate
        self.priority = priority
        self.energyLevel = energyLevel
        self.workMode = workMode
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
            title: "Buy groceries",
            notes: "Milk, eggs, and fruit",
            priority: .medium,
            energyLevel: .low,
            workMode: .errand,
            tags: ["home", "shopping"]
        ),
        MyTask(
            title: "Reply to emails",
            notes: "Inbox zero for client follow-ups",
            status: .completed,
            estimatedMinutes: 20,
            priority: .low,
            workMode: .shallowAdmin,
            tags: ["work", "admin"]
        ),
        MyTask(
            title: "Walk the dog",
            dueDate: .now.addingTimeInterval(60 * 60),
            energyLevel: .medium,
            workMode: .flexible,
            tags: ["personal"]
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
        guard let estimatedMinutes else {
            return nil
        }

        return estimatedMinutes > 0 ? estimatedMinutes : nil
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
