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
        try fetchAllRecords()
            .map(\.task)
            .sorted { leftTask, rightTask in
                if leftTask.createdAt != rightTask.createdAt {
                    return leftTask.createdAt < rightTask.createdAt
                }

                return leftTask.id.uuidString < rightTask.id.uuidString
            }
    }

    func task(withID id: UUID) throws -> MyTask? {
        try fetchRecord(withID: id)?.task
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
}
