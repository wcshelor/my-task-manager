import Foundation
import SwiftData
import Testing
@testable import task_manager

struct SwiftDataTaskRepositoryTests {
    @Test @MainActor func taskRepositoryStartsEmptyInMemory() throws {
        let repository = try makeRepository()

        let tasks = try repository.fetchTasks()

        #expect(tasks.isEmpty)
    }

    @Test @MainActor func taskRepositoryRoundTripsSavedTask() throws {
        let repository = try makeRepository()
        let dueDate = Date(timeIntervalSince1970: 4_000)
        let projectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174321")!
        let task = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!,
            title: "Plan roadmap",
            notes: "Share draft",
            status: .scheduled,
            estimatedMinutes: 45,
            dueDate: dueDate,
            priority: .high,
            energyLevel: .medium,
            workMode: .deepWork,
            projectID: projectID,
            taskGroup: "Launch",
            tags: ["work", "planning"],
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        try repository.saveTask(task, replacingTaskWithID: nil)

        let fetchedTask = try repository.task(withID: task.id)

        #expect(fetchedTask == task)
    }

    @Test @MainActor func projectRepositoryRoundTripsAndArchivesProject() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataProjectRepository(modelContainer: container)
        let project = Project(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            name: "Master's Thesis",
            summary: "Research and writing",
            isPinned: true,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        try repository.saveProject(project, replacingProjectWithID: nil)

        #expect(try repository.project(withID: project.id) == project)
        #expect(try repository.fetchProjects(includeArchived: false) == [project])

        try repository.archiveProject(withID: project.id, archivedAt: Date(timeIntervalSince1970: 2_000))

        #expect(try repository.fetchProjects(includeArchived: false).isEmpty)
        #expect(try repository.fetchProjects(includeArchived: true).first?.isArchived == true)
    }

    @Test @MainActor func captureRepositoryFiltersPendingCaptures() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataCaptureRepository(modelContainer: container)
        let pending = CaptureItem(title: "Ask Lisa")
        var processed = CaptureItem(title: "Processed")
        processed.markProcessed(at: Date(timeIntervalSince1970: 1_000))

        try repository.saveCapture(pending, replacingCaptureWithID: nil)
        try repository.saveCapture(processed, replacingCaptureWithID: nil)

        #expect(try repository.fetchCaptures(includeProcessed: false, includeArchived: false) == [pending])
        #expect(try repository.fetchCaptures(includeProcessed: true, includeArchived: false).count == 2)
    }

    @Test @MainActor func projectItemRepositoryFetchesItemsByProjectAndArchives() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataProjectItemRepository(modelContainer: container)
        let projectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!
        let otherProjectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174222")!
        let maybe = ProjectItem(projectID: projectID, kind: .maybe, title: "Explore method")
        let note = ProjectItem(projectID: otherProjectID, kind: .note, title: "Other note")

        try repository.saveProjectItem(maybe, replacingProjectItemWithID: nil)
        try repository.saveProjectItem(note, replacingProjectItemWithID: nil)

        #expect(try repository.fetchProjectItems(for: projectID, includeArchived: false) == [maybe])

        try repository.archiveProjectItem(withID: maybe.id, archivedAt: Date(timeIntervalSince1970: 2_000))

        #expect(try repository.fetchProjectItems(for: projectID, includeArchived: false).isEmpty)
        #expect(try repository.fetchProjectItems(for: projectID, includeArchived: true).first?.isArchived == true)
    }

    @Test @MainActor func taskRepositoryReplacesTaskUsingOriginalID() throws {
        let repository = try makeRepository()
        let originalTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!,
            title: "Original"
        )
        let updatedTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174099")!,
            title: "Updated",
            status: .done,
            createdAt: originalTask.createdAt,
            updatedAt: Date(timeIntervalSince1970: 9_999)
        )

        try repository.saveTask(originalTask, replacingTaskWithID: nil)
        try repository.saveTask(updatedTask, replacingTaskWithID: originalTask.id)

        let tasks = try repository.fetchTasks()

        #expect(tasks.count == 1)
        #expect(tasks.first == updatedTask)
    }

    @Test @MainActor func taskRepositoryDeletesTask() throws {
        let repository = try makeRepository()
        let taskID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!

        try repository.saveTask(MyTask(id: taskID, title: "Delete me"), replacingTaskWithID: nil)
        try repository.deleteTask(withID: taskID)

        #expect(try repository.fetchTasks().isEmpty)
    }

    @Test @MainActor func taskRepositoryNormalizesLegacyInvalidEstimatedMinutesOnRead() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let record = TaskRecord(task: MyTask(title: "Legacy task", estimatedMinutes: 30))
        record.estimatedMinutes = 20
        container.mainContext.insert(record)
        try container.mainContext.save()

        let repository = SwiftDataTaskRepository(modelContainer: container)
        let fetchedTask = try repository.task(withID: record.id)
        let persistedRecord = try container.mainContext
            .fetch(FetchDescriptor<TaskRecord>())
            .first { $0.id == record.id }

        #expect(fetchedTask?.estimatedMinutes == nil)
        #expect(persistedRecord?.estimatedMinutes == nil)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataTaskRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataTaskRepository(modelContainer: container)
    }
}
