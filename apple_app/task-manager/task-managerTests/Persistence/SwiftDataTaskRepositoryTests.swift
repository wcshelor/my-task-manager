import Foundation
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
            tags: ["work", "planning"],
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        try repository.saveTask(task, replacingTaskWithID: nil)

        let fetchedTask = try repository.task(withID: task.id)

        #expect(fetchedTask == task)
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
            status: .completed,
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

    @MainActor
    private func makeRepository() throws -> SwiftDataTaskRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataTaskRepository(modelContainer: container)
    }
}
