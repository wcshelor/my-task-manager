import Combine
import Foundation

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks: [MyTask] = []
    @Published private(set) var errorMessage: String?

    private let taskRepository: any TaskRepository
    private var hasLoaded = false

    init(taskRepository: any TaskRepository) {
        self.taskRepository = taskRepository
    }

    func loadTasksIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        loadTasks()
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

    func markTaskCompleted(withID id: UUID) {
        updateTask(withID: id) { task in
            task.status = .completed
            task.completedAt = .now
        }
    }

    func reopenTask(withID id: UUID) {
        updateTask(withID: id) { task in
            task.status = .active
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
}
