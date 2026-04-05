import Foundation
import Testing
@testable import task_manager

struct MyTaskCollectionTests {
    @Test func saveTaskAppendsANewTask() {
        let existingTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!,
            title: "Existing task"
        )
        let newTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174001")!,
            title: "New task"
        )
        var tasks = [existingTask]

        tasks.saveTask(newTask)

        #expect(tasks.count == 2)
        #expect(tasks.last?.id == newTask.id)
        #expect(tasks.last?.title == newTask.title)
    }

    @Test func saveTaskReplacesExistingTaskWithoutCreatingDuplicate() {
        let originalTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!,
            title: "Original task"
        )
        let untouchedTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174001")!,
            title: "Untouched task"
        )
        let updatedTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174099")!,
            title: "Updated task",
            status: .completed,
            createdAt: Date(timeIntervalSince1970: 9_999),
            updatedAt: Date(timeIntervalSince1970: 10_000)
        )
        var tasks = [originalTask, untouchedTask]

        tasks.saveTask(updatedTask, replacingTaskWithID: originalTask.id)

        #expect(tasks.count == 2)
        #expect(tasks[0] == updatedTask)
        #expect(tasks[1] == untouchedTask)
        #expect(tasks.contains(where: { $0.id == originalTask.id }) == false)
        #expect(tasks.contains(where: { $0.id == updatedTask.id }))
    }

    @Test func deleteTaskRemovesMatchingTask() {
        let deletedID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        var tasks = [
            MyTask(id: deletedID, title: "Delete me"),
            MyTask(
                id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174001")!,
                title: "Keep me"
            )
        ]

        tasks.deleteTask(withID: deletedID)

        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Keep me")
        #expect(tasks.containsTask(withID: deletedID) == false)
    }

    @Test func addTaskFlowCreatesAndAppendsTask() {
        let savedAt = Date(timeIntervalSince1970: 5_000)
        let formData = MyTaskFormData(
            idText: "123E4567-E89B-12D3-A456-426614174055",
            title: "Plan sprint",
            notesText: "  Align backlog  ",
            estimatedMinutesText: "30",
            priority: .high,
            energyLevel: .medium,
            workMode: .deepWork,
            tagsText: "work, planning"
        )
        var tasks = [MyTask(title: "Existing task")]

        let newTask = formData.makeTask(savedAt: savedAt)
        tasks.saveTask(newTask!)

        #expect(tasks.count == 2)
        #expect(tasks.last?.title == "Plan sprint")
        #expect(tasks.last?.notes == "Align backlog")
        #expect(tasks.last?.estimatedMinutes == 30)
        #expect(tasks.last?.priority == .high)
        #expect(tasks.last?.energyLevel == .medium)
        #expect(tasks.last?.workMode == .deepWork)
        #expect(tasks.last?.tags == ["work", "planning"])
        #expect(tasks.last?.status == .active)
        #expect(tasks.last?.createdAt == savedAt)
        #expect(tasks.last?.updatedAt == savedAt)
    }
}
