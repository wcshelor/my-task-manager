import Foundation
import SwiftData

@Model
final class TaskRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var statusRawValue: String
    var estimatedMinutes: Int?
    var dueDate: Date?
    var priorityRawValue: String?
    var energyLevelRawValue: String?
    var workModeRawValue: String?
    var tagsText: String
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(task: MyTask) {
        self.id = task.id
        self.title = task.title
        self.notes = task.notes
        self.statusRawValue = task.status.rawValue
        self.estimatedMinutes = task.estimatedMinutes
        self.dueDate = task.dueDate
        self.priorityRawValue = task.priority?.rawValue
        self.energyLevelRawValue = task.energyLevel?.rawValue
        self.workModeRawValue = task.workMode?.rawValue
        self.tagsText = Self.encodeTags(task.tags)
        self.createdAt = task.createdAt
        self.updatedAt = task.updatedAt
        self.completedAt = task.completedAt
    }

    var task: MyTask {
        MyTask(
            id: id,
            title: title,
            notes: notes,
            status: TaskStatus(rawValue: statusRawValue) ?? .active,
            estimatedMinutes: estimatedMinutes,
            dueDate: dueDate,
            priority: priorityRawValue.flatMap(PriorityLevel.init(rawValue:)),
            energyLevel: energyLevelRawValue.flatMap(EnergyLevel.init(rawValue:)),
            workMode: workModeRawValue.flatMap(WorkModeKind.init(rawValue:)),
            tags: MyTask.cleanedTags(from: tagsText),
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }

    func update(from task: MyTask) {
        id = task.id
        title = task.title
        notes = task.notes
        statusRawValue = task.status.rawValue
        estimatedMinutes = task.estimatedMinutes
        dueDate = task.dueDate
        priorityRawValue = task.priority?.rawValue
        energyLevelRawValue = task.energyLevel?.rawValue
        workModeRawValue = task.workMode?.rawValue
        tagsText = Self.encodeTags(task.tags)
        createdAt = task.createdAt
        updatedAt = task.updatedAt
        completedAt = task.completedAt
    }

    private static func encodeTags(_ tags: [String]) -> String {
        tags.joined(separator: ",")
    }
}
