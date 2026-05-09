import Foundation
import SwiftData

@Model
final class TaskRecord {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var statusRawValue: String = TaskStatus.active.rawValue
    var estimatedMinutes: Int?
    var dueDate: Date?
    var priorityRawValue: String?
    var energyLevelRawValue: String?
    var workModeRawValue: String?
    var projectID: UUID?
    var taskGroup: String?
    var tagsText: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
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
        self.projectID = task.projectID
        self.taskGroup = task.taskGroup
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
            projectID: projectID,
            taskGroup: taskGroup,
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
        projectID = task.projectID
        taskGroup = task.taskGroup
        tagsText = Self.encodeTags(task.tags)
        createdAt = task.createdAt
        updatedAt = task.updatedAt
        completedAt = task.completedAt
    }

    private static func encodeTags(_ tags: [String]) -> String {
        tags.joined(separator: ",")
    }
}

@Model
final class ProjectRecord {
    var id: UUID = UUID()
    var name: String = ""
    var summary: String?
    var isPinned: Bool = false
    var isArchived: Bool = false
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(project: Project) {
        update(from: project)
    }

    var project: Project {
        Project(
            id: id,
            name: name,
            summary: summary,
            isPinned: isPinned,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from project: Project) {
        id = project.id
        name = project.name
        summary = project.summary
        isPinned = project.isPinned
        isArchived = project.isArchived
        createdAt = project.createdAt
        updatedAt = project.updatedAt
    }
}

@Model
final class CaptureItemRecord {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var projectID: UUID?
    var source: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var processedAt: Date?
    var archivedAt: Date?
    var convertedTaskID: UUID?
    var convertedProjectItemID: UUID?

    init(capture: CaptureItem) {
        update(from: capture)
    }

    var capture: CaptureItem {
        CaptureItem(
            id: id,
            title: title,
            notes: notes,
            projectID: projectID,
            source: source,
            createdAt: createdAt,
            updatedAt: updatedAt,
            processedAt: processedAt,
            archivedAt: archivedAt,
            convertedTaskID: convertedTaskID,
            convertedProjectItemID: convertedProjectItemID
        )
    }

    func update(from capture: CaptureItem) {
        id = capture.id
        title = capture.title
        notes = capture.notes
        projectID = capture.projectID
        source = capture.source
        createdAt = capture.createdAt
        updatedAt = capture.updatedAt
        processedAt = capture.processedAt
        archivedAt = capture.archivedAt
        convertedTaskID = capture.convertedTaskID
        convertedProjectItemID = capture.convertedProjectItemID
    }
}

@Model
final class ProjectItemRecord {
    var id: UUID = UUID()
    var projectID: UUID = UUID()
    var kindRawValue: String = ProjectItemKind.maybe.rawValue
    var title: String = ""
    var notes: String?
    var source: String?
    var pressureRawValue: String?
    var reviewAfter: Date?
    var promotedTaskID: UUID?
    var isArchived: Bool = false
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(item: ProjectItem) {
        update(from: item)
    }

    var item: ProjectItem {
        ProjectItem(
            id: id,
            projectID: projectID,
            kind: ProjectItemKind(rawValue: kindRawValue) ?? .maybe,
            title: title,
            notes: notes,
            source: source,
            pressure: pressureRawValue.flatMap(ProjectItemPressure.init(rawValue:)),
            reviewAfter: reviewAfter,
            promotedTaskID: promotedTaskID,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from item: ProjectItem) {
        id = item.id
        projectID = item.projectID
        kindRawValue = item.kind.rawValue
        title = item.title
        notes = item.notes
        source = item.source
        pressureRawValue = item.pressure?.rawValue
        reviewAfter = item.reviewAfter
        promotedTaskID = item.promotedTaskID
        isArchived = item.isArchived
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }
}
