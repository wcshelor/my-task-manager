import Foundation
import SwiftData

@MainActor
final class SwiftDataTaskRepository: TaskRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchTasks() throws -> [MyTask] {
        let records = try fetchAllRecords()
        try normalizeEstimatedMinutes(in: records)

        return records
            .map(\.task)
            .sorted { leftTask, rightTask in
                if leftTask.createdAt != rightTask.createdAt {
                    return leftTask.createdAt < rightTask.createdAt
                }

                return leftTask.id.uuidString < rightTask.id.uuidString
            }
    }

    func task(withID id: UUID) throws -> MyTask? {
        let records = try fetchAllRecords()
        try normalizeEstimatedMinutes(in: records)
        return records.first { $0.id == id }?.task
    }

    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws {
        let record =
            try fetchRecord(withID: originalID ?? task.id)
            ?? fetchRecord(withID: task.id)

        if let record {
            record.update(from: task)
        } else {
            modelContext.insert(TaskRecord(task: task))
        }

        try modelContext.save()
    }

    func deleteTask(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllRecords() throws -> [TaskRecord] {
        try modelContext.fetch(FetchDescriptor<TaskRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> TaskRecord? {
        try fetchAllRecords().first { $0.id == id }
    }

    private func normalizeEstimatedMinutes(in records: [TaskRecord]) throws {
        var didUpdateRecords = false

        for record in records {
            let cleanedEstimatedMinutes = TaskDurationRules.cleanedEstimatedMinutes(
                record.estimatedMinutes
            )

            guard record.estimatedMinutes != cleanedEstimatedMinutes else {
                continue
            }

            record.estimatedMinutes = cleanedEstimatedMinutes
            didUpdateRecords = true
        }

        if didUpdateRecords {
            try modelContext.save()
        }
    }
}

@MainActor
final class SwiftDataProjectRepository: ProjectRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchProjects(includeArchived: Bool = false) throws -> [Project] {
        try fetchAllRecords()
            .map(\.project)
            .filter { includeArchived || $0.isArchived == false }
            .sorted { leftProject, rightProject in
                if leftProject.isPinned != rightProject.isPinned {
                    return leftProject.isPinned && rightProject.isPinned == false
                }

                if leftProject.name.localizedCaseInsensitiveCompare(rightProject.name) != .orderedSame {
                    return leftProject.name.localizedCaseInsensitiveCompare(rightProject.name) == .orderedAscending
                }

                return leftProject.createdAt < rightProject.createdAt
            }
    }

    func project(withID id: UUID) throws -> Project? {
        try fetchRecord(withID: id)?.project
    }

    func saveProject(_ project: Project, replacingProjectWithID originalID: UUID?) throws {
        let record =
            try fetchRecord(withID: originalID ?? project.id)
            ?? fetchRecord(withID: project.id)

        if let record {
            record.update(from: project)
        } else {
            modelContext.insert(ProjectRecord(project: project))
        }

        try modelContext.save()
    }

    func archiveProject(withID id: UUID, archivedAt: Date = .now) throws {
        guard var project = try project(withID: id) else {
            return
        }

        project.isArchived = true
        project.updatedAt = archivedAt
        try saveProject(project, replacingProjectWithID: id)
    }

    func deleteProject(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllRecords() throws -> [ProjectRecord] {
        try modelContext.fetch(FetchDescriptor<ProjectRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> ProjectRecord? {
        try fetchAllRecords().first { $0.id == id }
    }
}

@MainActor
final class SwiftDataCaptureRepository: CaptureRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchCaptures(
        includeProcessed: Bool = false,
        includeArchived: Bool = false
    ) throws -> [CaptureItem] {
        try fetchAllRecords()
            .map(\.capture)
            .filter { capture in
                (includeProcessed || capture.processedAt == nil)
                    && (includeArchived || capture.archivedAt == nil)
            }
            .sorted { leftCapture, rightCapture in
                if leftCapture.createdAt != rightCapture.createdAt {
                    return leftCapture.createdAt < rightCapture.createdAt
                }

                return leftCapture.id.uuidString < rightCapture.id.uuidString
            }
    }

    func capture(withID id: UUID) throws -> CaptureItem? {
        try fetchRecord(withID: id)?.capture
    }

    func saveCapture(_ capture: CaptureItem, replacingCaptureWithID originalID: UUID?) throws {
        let record =
            try fetchRecord(withID: originalID ?? capture.id)
            ?? fetchRecord(withID: capture.id)

        if let record {
            record.update(from: capture)
        } else {
            modelContext.insert(CaptureItemRecord(capture: capture))
        }

        try modelContext.save()
    }

    func deleteCapture(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllRecords() throws -> [CaptureItemRecord] {
        try modelContext.fetch(FetchDescriptor<CaptureItemRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> CaptureItemRecord? {
        try fetchAllRecords().first { $0.id == id }
    }
}

@MainActor
final class SwiftDataProjectItemRepository: ProjectItemRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchProjectItems(includeArchived: Bool = false) throws -> [ProjectItem] {
        try sortedItems(
            fetchAllRecords()
                .map(\.item)
                .filter { includeArchived || $0.isArchived == false }
        )
    }

    func fetchProjectItems(for projectID: UUID, includeArchived: Bool = false) throws -> [ProjectItem] {
        try sortedItems(
            fetchAllRecords()
                .map(\.item)
                .filter { item in
                    item.projectID == projectID && (includeArchived || item.isArchived == false)
                }
        )
    }

    func projectItem(withID id: UUID) throws -> ProjectItem? {
        try fetchRecord(withID: id)?.item
    }

    func saveProjectItem(_ item: ProjectItem, replacingProjectItemWithID originalID: UUID?) throws {
        let record =
            try fetchRecord(withID: originalID ?? item.id)
            ?? fetchRecord(withID: item.id)

        if let record {
            record.update(from: item)
        } else {
            modelContext.insert(ProjectItemRecord(item: item))
        }

        try modelContext.save()
    }

    func archiveProjectItem(withID id: UUID, archivedAt: Date = .now) throws {
        guard var item = try projectItem(withID: id) else {
            return
        }

        item.isArchived = true
        item.updatedAt = archivedAt
        try saveProjectItem(item, replacingProjectItemWithID: id)
    }

    func deleteProjectItem(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func sortedItems(_ items: [ProjectItem]) -> [ProjectItem] {
        items.sorted { leftItem, rightItem in
            if leftItem.createdAt != rightItem.createdAt {
                return leftItem.createdAt < rightItem.createdAt
            }

            return leftItem.id.uuidString < rightItem.id.uuidString
        }
    }

    private func fetchAllRecords() throws -> [ProjectItemRecord] {
        try modelContext.fetch(FetchDescriptor<ProjectItemRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> ProjectItemRecord? {
        try fetchAllRecords().first { $0.id == id }
    }
}
