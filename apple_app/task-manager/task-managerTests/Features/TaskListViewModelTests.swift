import Foundation
import Testing
@testable import task_manager

@MainActor
struct TaskListViewModelTests {
    @Test func markTaskCompletedPersistsCompletedState() throws {
        let task = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!,
            title: "Finish migration",
            status: .active,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let repository = FakeTaskRepository(tasks: [task])
        let viewModel = TaskListViewModel(taskRepository: repository)

        viewModel.loadTasks()
        viewModel.markTaskCompleted(withID: task.id)

        let savedTask = try #require(try repository.task(withID: task.id))
        #expect(savedTask.status == .completed)
        #expect(savedTask.completedAt != nil)
        #expect(viewModel.tasks.first?.status == .completed)
    }

    @Test func reopenTaskRestoresCompletedTaskToActive() throws {
        let completedAt = Date(timeIntervalSince1970: 1_200)
        let task = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174001")!,
            title: "Review notes",
            status: .completed,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: completedAt,
            completedAt: completedAt
        )
        let repository = FakeTaskRepository(tasks: [task])
        let viewModel = TaskListViewModel(taskRepository: repository)

        viewModel.loadTasks()
        viewModel.reopenTask(withID: task.id)

        let savedTask = try #require(try repository.task(withID: task.id))
        #expect(savedTask.status == .active)
        #expect(savedTask.completedAt == nil)
        #expect(viewModel.tasks.first?.status == .active)
    }

    @Test func archiveTaskPersistsArchivedState() throws {
        let task = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174002")!,
            title: "Old note",
            status: .inbox,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let repository = FakeTaskRepository(tasks: [task])
        let viewModel = TaskListViewModel(taskRepository: repository)

        viewModel.loadTasks()
        viewModel.archiveTask(withID: task.id)

        let savedTask = try #require(try repository.task(withID: task.id))
        #expect(savedTask.status == .archived)
        #expect(savedTask.completedAt == nil)
        #expect(viewModel.tasks.first?.status == .archived)
    }

    @Test func sceneActivationReloadsTasksAfterAnExternalRepositoryChange() throws {
        let originalTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174010")!,
            title: "Inbox task",
            status: .active,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let syncedTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174011")!,
            title: "Added on another device",
            status: .inbox,
            createdAt: Date(timeIntervalSince1970: 2_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let repository = FakeTaskRepository(tasks: [originalTask])
        let viewModel = TaskListViewModel(taskRepository: repository)

        viewModel.loadTasks()
        repository.replaceTasks(with: [originalTask, syncedTask])

        viewModel.handleSceneDidBecomeActive()

        #expect(viewModel.tasks.count == 2)
        #expect(viewModel.tasks.contains(syncedTask))
    }
}

@MainActor
private final class FakeTaskRepository: TaskRepository {
    private(set) var tasks: [MyTask]

    init(tasks: [MyTask] = []) {
        self.tasks = tasks
    }

    func fetchTasks() throws -> [MyTask] {
        tasks
    }

    func task(withID id: UUID) throws -> MyTask? {
        tasks.first { $0.id == id }
    }

    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws {
        tasks.saveTask(task, replacingTaskWithID: originalID)
    }

    func deleteTask(withID id: UUID) throws {
        tasks.deleteTask(withID: id)
    }

    func replaceTasks(with tasks: [MyTask]) {
        self.tasks = tasks
    }
}
