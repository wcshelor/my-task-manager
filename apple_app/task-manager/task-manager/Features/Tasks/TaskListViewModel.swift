import Combine
import Foundation

nonisolated struct ScheduledTaskCompletionPrompt: Identifiable, Equatable, Sendable {
    let blockID: UUID
    let taskID: UUID
    let taskTitle: String

    var id: UUID {
        blockID
    }
}

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks: [MyTask] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var overdueCompletionPrompt: ScheduledTaskCompletionPrompt?

    private let taskRepository: any TaskRepository
    private let scheduledBlockRepository: (any ScheduledBlockRepository)?
    private let calendarWriter: (any CalendarWriting)?
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false
    private var queuedOverdueCompletionPrompts: [ScheduledTaskCompletionPrompt] = []
    private var promptedOverdueBlockIDs: Set<UUID> = []

    init(
        taskRepository: any TaskRepository,
        scheduledBlockRepository: (any ScheduledBlockRepository)? = nil,
        calendarWriter: (any CalendarWriting)? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.taskRepository = taskRepository
        self.scheduledBlockRepository = scheduledBlockRepository
        self.calendarWriter = calendarWriter
        self.nowProvider = nowProvider
    }

    func loadTasksIfNeeded() async {
        guard hasLoaded == false else {
            return
        }

        loadTasks()
        await enqueueOverdueScheduledTaskPrompts()
    }

    func handleSceneDidBecomeActive() async {
        guard hasLoaded else {
            return
        }

        loadTasks()
        await enqueueOverdueScheduledTaskPrompts()
    }

    func loadTasks() {
        do {
            tasks = try taskRepository.fetchTasks()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load tasks: \(error.localizedDescription)"
        }
    }

    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID? = nil) {
        do {
            try taskRepository.saveTask(task, replacingTaskWithID: originalID)
            tasks = try taskRepository.fetchTasks()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to save task: \(error.localizedDescription)"
        }
    }

    func deleteTask(withID id: UUID) {
        do {
            try taskRepository.deleteTask(withID: id)
            tasks = try taskRepository.fetchTasks()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to delete task: \(error.localizedDescription)"
        }
    }

    func markTaskCompleted(withID id: UUID) async {
        await completeTask(withID: id)
    }

    func answerOverdueCompletionPrompt(finished: Bool) async {
        guard let prompt = overdueCompletionPrompt else {
            return
        }

        overdueCompletionPrompt = nil
        queuedOverdueCompletionPrompts.removeAll { $0.id == prompt.id }

        if finished {
            await completeTask(withID: prompt.taskID)
        } else {
            await moveScheduledTaskBackToList(
                taskID: prompt.taskID,
                blockID: prompt.blockID
            )
        }

        presentNextOverdueCompletionPrompt()
    }

    private func completeTask(withID id: UUID) async {
        do {
            errorMessage = nil
            let completedAt = nowProvider()
            guard var task = try taskRepository.task(withID: id) else {
                errorMessage = "Unable to update task: Task not found."
                return
            }

            let originalBlocks = try activeScheduledBlocks(for: id)
            task.status = .done
            task.completedAt = completedAt
            task.updatedAt = completedAt
            try taskRepository.saveTask(task, replacingTaskWithID: id)

            var cleanupWarning: String?
            do {
                try await removeCalendarEventsAndMarkBlocksCompleted(
                    originalBlocks,
                    at: completedAt
                )
            } catch {
                cleanupWarning = "Task completed, but the linked calendar event could not be removed: \(error.localizedDescription)"
            }

            tasks = try taskRepository.fetchTasks()
            if let cleanupWarning {
                recordError(cleanupWarning)
            }
            hasLoaded = true
        } catch {
            errorMessage = "Unable to update task: \(error.localizedDescription)"
        }
    }

    func reopenTask(withID id: UUID) {
        updateTask(withID: id) { task in
            task.status = .open
            task.completedAt = nil
        }
    }

    func archiveTask(withID id: UUID) {
        updateTask(withID: id) { task in
            task.status = .archived
            task.completedAt = nil
        }
    }

    private func updateTask(
        withID id: UUID,
        mutate: (inout MyTask) -> Void
    ) {
        do {
            guard var task = try taskRepository.task(withID: id) else {
                errorMessage = "Unable to update task: Task not found."
                return
            }

            mutate(&task)
            task.updatedAt = .now
            try taskRepository.saveTask(task, replacingTaskWithID: id)
            tasks = try taskRepository.fetchTasks()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to update task: \(error.localizedDescription)"
        }
    }

    private func enqueueOverdueScheduledTaskPrompts() async {
        guard let scheduledBlockRepository else {
            return
        }

        do {
            let now = nowProvider()
            let currentTasks = try taskRepository.fetchTasks()
            let taskLookup = Dictionary(uniqueKeysWithValues: currentTasks.map { ($0.id, $0) })
            let prompts = try scheduledBlockRepository.fetchScheduledBlocks()
                .filter { block in
                    block.isActivelyScheduled
                        && block.end <= now
                        && promptedOverdueBlockIDs.contains(block.id) == false
                        && taskLookup[block.taskID]?.status != .done
                }
                .compactMap { block -> ScheduledTaskCompletionPrompt? in
                    guard let task = taskLookup[block.taskID] else {
                        return nil
                    }

                    promptedOverdueBlockIDs.insert(block.id)
                    return ScheduledTaskCompletionPrompt(
                        blockID: block.id,
                        taskID: task.id,
                        taskTitle: task.title
                    )
                }

            queuedOverdueCompletionPrompts.append(contentsOf: prompts)
            presentNextOverdueCompletionPrompt()
        } catch {
            recordError("Unable to check scheduled tasks: \(error.localizedDescription)")
        }
    }

    private func presentNextOverdueCompletionPrompt() {
        guard overdueCompletionPrompt == nil else {
            return
        }

        overdueCompletionPrompt = queuedOverdueCompletionPrompts.first
    }

    private func moveScheduledTaskBackToList(
        taskID: UUID,
        blockID: UUID
    ) async {
        do {
            errorMessage = nil
            let movedAt = nowProvider()
            guard var task = try taskRepository.task(withID: taskID) else {
                errorMessage = "Unable to update task: Task not found."
                return
            }

            let blocks = try scheduledBlockRepository?.fetchScheduledBlocks(for: taskID) ?? []
            guard let block = blocks.first(where: { $0.id == blockID }) else {
                return
            }

            if task.status == .scheduled {
                task.status = .open
                task.completedAt = nil
                task.updatedAt = movedAt
                try taskRepository.saveTask(task, replacingTaskWithID: task.id)
            }

            var cleanupWarning: String?
            do {
                try await deleteLinkedEventIfPresent(for: block)
            } catch {
                cleanupWarning = "The task was moved back to the list, but the linked calendar event could not be removed: \(error.localizedDescription)"
            }

            var canceledBlock = block
            canceledBlock.status = .canceled
            canceledBlock.calendarLinkState = .notWritten
            canceledBlock.calendarEventIdentifier = nil
            canceledBlock.updatedAt = movedAt
            canceledBlock.lastSyncedAt = movedAt
            canceledBlock.syncErrorMessage = nil
            try scheduledBlockRepository?.saveScheduledBlock(
                canceledBlock,
                replacingBlockWithID: canceledBlock.id
            )

            tasks = try taskRepository.fetchTasks()
            if let cleanupWarning {
                recordError(cleanupWarning)
            }
            hasLoaded = true
        } catch {
            errorMessage = "Unable to move scheduled task back to the list: \(error.localizedDescription)"
        }
    }

    private func activeScheduledBlocks(for taskID: UUID) throws -> [ScheduledBlock] {
        try scheduledBlockRepository?
            .fetchScheduledBlocks(for: taskID)
            .filter(\.isActivelyScheduled) ?? []
    }

    private func removeCalendarEventsAndMarkBlocksCompleted(
        _ blocks: [ScheduledBlock],
        at date: Date
    ) async throws {
        for block in blocks {
            try await deleteLinkedEventIfPresent(for: block)

            var completedBlock = block
            completedBlock.status = .completed
            completedBlock.calendarLinkState = .notWritten
            completedBlock.calendarEventIdentifier = nil
            completedBlock.updatedAt = date
            completedBlock.lastSyncedAt = date
            completedBlock.syncErrorMessage = nil
            try scheduledBlockRepository?.saveScheduledBlock(
                completedBlock,
                replacingBlockWithID: completedBlock.id
            )
        }
    }

    private func deleteLinkedEventIfPresent(for block: ScheduledBlock) async throws {
        guard let calendarWriter,
            let identifier = block.calendarEventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            identifier.isEmpty == false else {
            return
        }

        do {
            try await calendarWriter.deleteEvent(for: block)
        } catch CalendarWriteError.missingLinkedEventIdentifier {
            return
        }
    }

    private func recordError(_ message: String) {
        guard message.isEmpty == false else {
            return
        }

        if let errorMessage, errorMessage.isEmpty == false {
            self.errorMessage = "\(errorMessage)\n\(message)"
        } else {
            errorMessage = message
        }
    }
}
