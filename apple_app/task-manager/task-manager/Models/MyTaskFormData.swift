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
    var projectID: UUID?
    var taskGroupText: String
    var tagsText: String
    var createdAt: Date?
    var completedAt: Date?

    private var preferredIncompleteStatus: TaskStatus

    init(
        idText: String = UUID().uuidString,
        title: String = "",
        notesText: String = "",
        status: TaskStatus = .open,
        estimatedMinutesText: String = "",
        hasDueDate: Bool = false,
        dueDate: Date = .now,
        priority: PriorityLevel? = nil,
        energyLevel: EnergyLevel? = nil,
        workMode: WorkModeKind? = nil,
        projectID: UUID? = nil,
        taskGroupText: String = "",
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
        self.projectID = projectID
        self.taskGroupText = taskGroupText
        self.tagsText = tagsText
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.preferredIncompleteStatus = preferredIncompleteStatus ?? (
            status == .done ? .open : status
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
            projectID: task.projectID,
            taskGroupText: task.taskGroup ?? "",
            tagsText: task.tags.joined(separator: ", "),
            createdAt: task.createdAt,
            completedAt: task.completedAt,
            preferredIncompleteStatus: task.status == .done ? .open : task.status
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
            estimatedMinutesText = newValue ? String(TaskDurationRules.minutesIncrement) : ""
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
        parsedEstimatedMinutes.map { "\($0) min" } ?? "None"
    }

    var estimatedMinutesSummaryText: String {
        parsedEstimatedMinutes.map { "\($0) min" } ?? "No estimate"
    }

    var isCompleted: Bool {
        get {
            status == .done
        }
        set {
            status = newValue ? .done : preferredIncompleteStatus

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
            projectID: projectID,
            taskGroup: taskGroupText,
            tags: MyTask.cleanedTags(from: tagsText),
            createdAt: finalCreatedAt,
            updatedAt: savedAt,
            completedAt: status == .done ? (completedAt ?? savedAt) : nil
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
