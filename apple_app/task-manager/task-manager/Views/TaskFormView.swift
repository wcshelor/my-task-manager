import SwiftUI

struct TaskFormView: View {
    enum Mode {
        case create
        case edit(originalTaskID: UUID)

        var title: String {
            switch self {
            case .create:
                return "New Task"
            case .edit:
                return "Task Details"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .create:
                return "Create Task"
            case .edit:
                return "Save Changes"
            }
        }

        var originalTaskID: UUID? {
            switch self {
            case .create:
                return nil
            case .edit(let originalTaskID):
                return originalTaskID
            }
        }

        var showsDeleteAction: Bool {
            switch self {
            case .create:
                return false
            case .edit:
                return true
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var formData: MyTaskFormData
    @State private var isShowingDeleteConfirmation = false

    let mode: Mode
    let reservedTaskIDs: Set<UUID>
    let onSave: (MyTask) -> Void
    let onDelete: (() -> Void)?

    init(
        mode: Mode,
        initialFormData: MyTaskFormData = MyTaskFormData(),
        reservedTaskIDs: Set<UUID> = [],
        onSave: @escaping (MyTask) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.reservedTaskIDs = reservedTaskIDs
        self.onSave = onSave
        self.onDelete = onDelete
        _formData = State(initialValue: initialFormData)
    }

    private var validationMessage: String? {
        formData.validationMessage(
            reservedTaskIDs: reservedTaskIDs,
            originalTaskID: mode.originalTaskID
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Section("Task Details") {
                    HStack {
                        TextField("ID", text: $formData.idText)
                            .font(.system(.body, design: .monospaced))

                        Button("Generate ID") {
                            formData.generateNewID()
                        }
                    }

                    TextField("Title", text: $formData.title)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $formData.notesText)
                            .frame(minHeight: 100)
                    }

                    Picker("Status", selection: $formData.status) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }

                    TextField("Estimated Minutes", text: $formData.estimatedMinutesText)
                }

                Section("Scheduling") {
                    Toggle("Set Due Date", isOn: $formData.hasDueDate)

                    if formData.hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $formData.dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section("Attributes") {
                    Picker("Priority", selection: $formData.priority) {
                        Text("None").tag(nil as PriorityLevel?)

                        ForEach(PriorityLevel.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority as PriorityLevel?)
                        }
                    }

                    Picker("Energy Level", selection: $formData.energyLevel) {
                        Text("None").tag(nil as EnergyLevel?)

                        ForEach(EnergyLevel.allCases, id: \.self) { energyLevel in
                            Text(energyLevel.displayName).tag(energyLevel as EnergyLevel?)
                        }
                    }

                    Picker("Work Mode", selection: $formData.workMode) {
                        Text("None").tag(nil as WorkModeKind?)

                        ForEach(WorkModeKind.allCases, id: \.self) { workMode in
                            Text(workMode.displayName).tag(workMode as WorkModeKind?)
                        }
                    }
                }

                Section("Tags") {
                    TextField("Comma-separated tags", text: $formData.tagsText)
                }

                if mode.showsDeleteAction, onDelete != nil {
                    Section {
                        Button("Delete Task", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    } footer: {
                        Text("Deletes this task from local app storage.")
                    }
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button(mode.saveButtonTitle) {
                    saveTask()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validationMessage != nil)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(mode.title)
        .alert("Delete Task?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteTask()
            }

            Button("Keep Task", role: .cancel) {}
        } message: {
            Text("This removes the task from your saved task list.")
        }
    }

    private func saveTask() {
        guard let task = formData.makeTask() else {
            return
        }

        onSave(task)
        dismiss()
    }

    private func deleteTask() {
        onDelete?()
        dismiss()
    }
}

#Preview {
    TaskFormView(mode: .create) { _ in }
}
