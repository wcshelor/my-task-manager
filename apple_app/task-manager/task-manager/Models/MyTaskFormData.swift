import Foundation

struct MyTaskFormData {
    var idText: String
    var title: String
    var notesText: String
    var status: TaskStatus
    var estimatedMinutesText: String
    var hasDueDate: Bool
    var dueDate: Date
    var priority: PriorityLevel?
    var energyLevel: EnergyLevel?
    var workMode: WorkModeKind?
    var tagsText: String
    var createdAt: Date?
    var completedAt: Date?

    private var preferredIncompleteStatus: TaskStatus

    init(
        idText: String = UUID().uuidString,
        title: String = "",
        notesText: String = "",
        status: TaskStatus = .inbox,
        estimatedMinutesText: String = "",
        hasDueDate: Bool = false,
        dueDate: Date = .now,
        priority: PriorityLevel? = nil,
        energyLevel: EnergyLevel? = nil,
        workMode: WorkModeKind? = nil,
        tagsText: String = "",
        createdAt: Date? = nil,
        completedAt: Date? = nil,
        preferredIncompleteStatus: TaskStatus? = nil
    ) {
        self.idText = idText
        self.title = title
        self.notesText = notesText
        self.status = status
        self.estimatedMinutesText = estimatedMinutesText
        self.hasDueDate = hasDueDate
        self.dueDate = dueDate
        self.priority = priority
        self.energyLevel = energyLevel
        self.workMode = workMode
        self.tagsText = tagsText
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.preferredIncompleteStatus = preferredIncompleteStatus ?? (
            status == .completed ? .active : status
        )
    }

    init(task: MyTask) {
        self.init(
            idText: task.id.uuidString,
            title: task.title,
            notesText: task.notes ?? "",
            status: task.status,
            estimatedMinutesText: task.estimatedMinutes.map(String.init) ?? "",
            hasDueDate: task.dueDate != nil,
            dueDate: task.dueDate ?? task.updatedAt,
            priority: task.priority,
            energyLevel: task.energyLevel,
            workMode: task.workMode,
            tagsText: task.tags.joined(separator: ", "),
            createdAt: task.createdAt,
            completedAt: task.completedAt,
            preferredIncompleteStatus: task.status == .completed ? .active : task.status
        )
    }

    var canSave: Bool {
        validationMessage == nil
    }

    var validationMessage: String? {
        validationMessage(reservedTaskIDs: [])
    }

    var hasEstimatedDuration: Bool {
        get {
            hasEstimatedMinutesInput
        }
        set {
            estimatedMinutesText = newValue ? String(estimatedMinutesSelection) : ""
        }
    }

    var estimatedMinutesSelection: Int {
        get {
            parsedEstimatedMinutes ?? TaskDurationRules.defaultAssumedMinutes
        }
        set {
            estimatedMinutesText = String(
                TaskDurationRules.normalizedFormSelectionMinutes(newValue)
            )
        }
    }

    var estimatedMinutesDisplayText: String {
        "\(estimatedMinutesSelection) min"
    }

    var isCompleted: Bool {
        get {
            status == .completed
        }
        set {
            status = newValue ? .completed : preferredIncompleteStatus

            if !newValue {
                completedAt = nil
            }
        }
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

        if hasEstimatedMinutesInput && parsedEstimatedMinutes == nil {
            return "Estimated minutes must be a positive multiple of 15."
        }

        guard let parsedID else {
            return "Enter a valid UUID."
        }

        if reservedTaskIDs.contains(parsedID), parsedID != originalTaskID {
            return "Task ID must be unique."
        }

        return nil
    }

    func makeTask(savedAt: Date = .now) -> MyTask? {
        guard let id = parsedID else {
            return nil
        }

        guard let cleanedTitle = MyTask.cleanedTitle(from: title) else {
            return nil
        }

        guard !hasEstimatedMinutesInput || parsedEstimatedMinutes != nil else {
            return nil
        }

        let finalCreatedAt = createdAt ?? savedAt

        return MyTask(
            id: id,
            title: cleanedTitle,
            notes: MyTask.cleanedOptionalText(from: notesText),
            status: status,
            estimatedMinutes: parsedEstimatedMinutes,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            energyLevel: energyLevel,
            workMode: workMode,
            tags: MyTask.cleanedTags(from: tagsText),
            createdAt: finalCreatedAt,
            updatedAt: savedAt,
            completedAt: status == .completed ? (completedAt ?? savedAt) : nil
        )
    }

    mutating func generateNewID() {
        idText = UUID().uuidString
    }

    private var parsedID: UUID? {
        UUID(uuidString: idText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var trimmedEstimatedMinutesText: String {
        estimatedMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasEstimatedMinutesInput: Bool {
        !trimmedEstimatedMinutesText.isEmpty
    }

    private var parsedEstimatedMinutes: Int? {
        guard hasEstimatedMinutesInput else {
            return nil
        }

        guard let estimatedMinutes = Int(trimmedEstimatedMinutesText) else {
            return nil
        }

        return TaskDurationRules.cleanedEstimatedMinutes(estimatedMinutes)
    }
}
