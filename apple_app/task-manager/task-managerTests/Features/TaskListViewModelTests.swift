import Foundation
import Testing
@testable import task_manager

@MainActor
struct TaskListViewModelTests {
    @Test func markTaskCompletedPersistsCompletedState() async throws {
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
        await viewModel.markTaskCompleted(withID: task.id)

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

    @Test func sceneActivationReloadsTasksAfterAnExternalRepositoryChange() async throws {
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

        await viewModel.handleSceneDidBecomeActive()

        #expect(viewModel.tasks.count == 2)
        #expect(viewModel.tasks.contains(syncedTask))
    }

    @Test func completingScheduledTaskRemovesLinkedCalendarEventAndCompletesBlock() async throws {
        let task = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174020")!,
            title: "Scheduled task",
            status: .scheduled,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let block = ScheduledBlock(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174021")!,
            taskID: task.id,
            start: Date(timeIntervalSince1970: 2_000),
            end: Date(timeIntervalSince1970: 3_000),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Tasks"
        )
        let taskRepository = FakeTaskRepository(tasks: [task])
        let blockRepository = FakeScheduledBlockRepository(blocks: [block])
        let calendarWriter = FakeCalendarWriter()
        let viewModel = TaskListViewModel(
            taskRepository: taskRepository,
            scheduledBlockRepository: blockRepository,
            calendarWriter: calendarWriter,
            nowProvider: { Date(timeIntervalSince1970: 4_000) }
        )

        await viewModel.markTaskCompleted(withID: task.id)

        let savedTask = try #require(try taskRepository.task(withID: task.id))
        let savedBlock = try #require(blockRepository.blocks.first)
        #expect(savedTask.status == .completed)
        #expect(calendarWriter.deletedEventIdentifiers == ["event-123"])
        #expect(savedBlock.status == .completed)
        #expect(savedBlock.calendarLinkState == .notWritten)
        #expect(savedBlock.calendarEventIdentifier == nil)
    }

    @Test func loadQueuesOverdueScheduledTaskPromptAndNoAnswerMovesTaskBackToList() async throws {
        let task = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174030")!,
            title: "Past scheduled task",
            status: .scheduled,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let block = ScheduledBlock(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174031")!,
            taskID: task.id,
            start: Date(timeIntervalSince1970: 2_000),
            end: Date(timeIntervalSince1970: 3_000),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-456",
            calendarTitle: "Tasks"
        )
        let taskRepository = FakeTaskRepository(tasks: [task])
        let blockRepository = FakeScheduledBlockRepository(blocks: [block])
        let calendarWriter = FakeCalendarWriter()
        let viewModel = TaskListViewModel(
            taskRepository: taskRepository,
            scheduledBlockRepository: blockRepository,
            calendarWriter: calendarWriter,
            nowProvider: { Date(timeIntervalSince1970: 4_000) }
        )

        await viewModel.loadTasksIfNeeded()

        #expect(viewModel.overdueCompletionPrompt?.taskTitle == "Past scheduled task")

        await viewModel.answerOverdueCompletionPrompt(finished: false)

        let savedTask = try #require(try taskRepository.task(withID: task.id))
        let savedBlock = try #require(blockRepository.blocks.first)
        #expect(savedTask.status == .active)
        #expect(calendarWriter.deletedEventIdentifiers == ["event-456"])
        #expect(savedBlock.status == .canceled)
        #expect(savedBlock.calendarLinkState == .notWritten)
        #expect(viewModel.overdueCompletionPrompt == nil)
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

@MainActor
private final class FakeScheduledBlockRepository: ScheduledBlockRepository {
    private(set) var blocks: [ScheduledBlock]

    init(blocks: [ScheduledBlock]) {
        self.blocks = blocks
    }

    func fetchScheduledBlocks() throws -> [ScheduledBlock] {
        blocks
    }

    func fetchScheduledBlocks(for taskID: UUID) throws -> [ScheduledBlock] {
        blocks.filter { $0.taskID == taskID }
    }

    func saveScheduledBlock(_ block: ScheduledBlock, replacingBlockWithID originalID: UUID?) throws {
        if let originalID, let index = blocks.firstIndex(where: { $0.id == originalID }) {
            blocks[index] = block
            return
        }

        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
            return
        }

        blocks.append(block)
    }

    func deleteScheduledBlock(withID id: UUID) throws {
        blocks.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeCalendarWriter: CalendarWriting {
    private(set) var deletedEventIdentifiers: [String] = []

    func validateWriteCalendar() async throws -> String {
        "Tasks"
    }

    func createEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult {
        CalendarWriteResult(
            eventIdentifier: "event-\(block.id.uuidString)",
            calendarTitle: "Tasks",
            eventTitle: "Task: \(task.title)"
        )
    }

    func updateEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult {
        CalendarWriteResult(
            eventIdentifier: block.calendarEventIdentifier ?? "event-\(block.id.uuidString)",
            calendarTitle: "Tasks",
            eventTitle: "Task: \(task.title)"
        )
    }

    func deleteEvent(for block: ScheduledBlock) async throws {
        if let identifier = block.calendarEventIdentifier {
            deletedEventIdentifiers.append(identifier)
        }
    }
}
