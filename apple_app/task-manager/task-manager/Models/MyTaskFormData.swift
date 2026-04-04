import Foundation

struct MyTaskFormData {
    var idText: String
    var title: String
    var isDone: Bool
    var createdAt: Date

    init(
        idText: String = UUID().uuidString,
        title: String = "",
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.idText = idText
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }

    init(task: MyTask) {
        self.init(
            idText: task.id.uuidString,
            title: task.title,
            isDone: task.isDone,
            createdAt: task.createdAt
        )
    }

    var canSave: Bool {
        validationMessage == nil
    }

    var validationMessage: String? {
        validationMessage(reservedTaskIDs: [])
    }

    func canSave(reservedTaskIDs: Set<UUID>, originalTaskID: UUID? = nil) -> Bool {
        validationMessage(reservedTaskIDs: reservedTaskIDs, originalTaskID: originalTaskID) == nil
    }

    func validationMessage(
        reservedTaskIDs: Set<UUID>,
        originalTaskID: UUID? = nil
    ) -> String? {
        if MyTask.cleanedTitle(from: title) == nil {
            return "Enter a task title."
        }

        guard let parsedID else {
            return "Enter a valid UUID."
        }

        if reservedTaskIDs.contains(parsedID), parsedID != originalTaskID {
            return "Task ID must be unique."
        }

        return nil
    }

    func makeTask() -> MyTask? {
        guard let id = parsedID else {
            return nil
        }

        guard let cleanedTitle = MyTask.cleanedTitle(from: title) else {
            return nil
        }

        return MyTask(
            id: id,
            title: cleanedTitle,
            isDone: isDone,
            createdAt: createdAt
        )
    }

    mutating func generateNewID() {
        idText = UUID().uuidString
    }

    private var parsedID: UUID? {
        UUID(uuidString: idText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
