import Foundation

@MainActor
protocol TaskRepository {
    func fetchTasks() throws -> [MyTask]
    func task(withID id: UUID) throws -> MyTask?
    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws
    func deleteTask(withID id: UUID) throws
}
