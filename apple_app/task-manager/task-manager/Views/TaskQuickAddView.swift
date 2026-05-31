import SwiftUI

struct TaskQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focusedField: Field?
    @State private var formData: MyTaskFormData
    @State private var isCreatingTaskGroup = false
    @State private var newTaskGroupText = ""
    @State private var isShowingCreateConfirmation = false
    @State private var isShowingCancelConfirmation = false
    @State private var showsDetailedInfo = false
    @State private var showsScheduleStatus = false
    @State private var showsPlanningContext = false

    private enum Field: Hashable {
        case title
        case notes
        case newTaskGroup
    }
    let taskGroups: [String]
    let reservedTaskIDs: Set<UUID>
    let onSave: (MyTask) -> Void

    init(
        initialFormData: MyTaskFormData = MyTaskFormData(),
        taskGroups: [String] = [],
        reservedTaskIDs: Set<UUID> = [],
        onSave: @escaping (MyTask) -> Void
    ) {
        _formData = State(initialValue: initialFormData)
        self.taskGroups = taskGroups
        self.reservedTaskIDs = reservedTaskIDs
        self.onSave = onSave
    }

    private var validationMessage: String? {
        formData.validationMessage(reservedTaskIDs: reservedTaskIDs)
    }

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isCompactWidth ? 20 : 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Essential Details")
                        .font(.headline)

                    labeledField("Title") {
                        TextField("New Task", text: $formData.title)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3.weight(.semibold))
                            .focused($focusedField, equals: .title)
                            .submitLabel(.done)
                    }

                    labeledField("Duration") {
                        EstimatedDurationControl(estimatedMinutesText: $formData.estimatedMinutesText)
                    }
                }

                detailedInfoSection

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(isCompactWidth ? 16 : 20)
        }
        .navigationTitle("Add Task")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .destructive) {
                    isShowingCancelConfirmation = true
                } label: {
                    Text("Cancel")
                }
                .tint(.red)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    focusedField = nil
                    isShowingCreateConfirmation = true
                }
                .disabled(validationMessage != nil)
            }
        }
        .alert("Create Task?", isPresented: $isShowingCreateConfirmation) {
            Button("Yes") {
                saveTask()
            }

            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text(taskSummaryText)
        }
        .alert("Are you sure?", isPresented: $isShowingCancelConfirmation) {
            Button("Cancel Task", role: .destructive) {
                dismiss()
            }

            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("This will discard the task you are creating.")
        }
        .onAppear {
            focusedField = .title
        }
    }

    @ViewBuilder
    private var detailedInfoSection: some View {
        DisclosureGroup(isExpanded: $showsDetailedInfo) {
            VStack(alignment: .leading, spacing: 14) {
                labeledField("Notes") {
                    TextField(
                        "Optional context",
                        text: $formData.notesText,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .notes)
                }

                DisclosureGroup("Schedule and Status", isExpanded: $showsScheduleStatus) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Set Due Date", isOn: $formData.hasDueDate)

                        if formData.hasDueDate {
                            labeledField("Due") {
                                DatePicker(
                                    "Due Date",
                                    selection: $formData.dueDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            }
                        }

                        LabeledContent("Status") {
                            Picker("Status", selection: $formData.status) {
                                ForEach(TaskStatus.allCases, id: \.self) { status in
                                    Text(status.displayName).tag(status)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.top, 8)
                }

                DisclosureGroup("Planning Context", isExpanded: $showsPlanningContext) {
                    VStack(alignment: .leading, spacing: 12) {
                        taskGroupPicker

                        LabeledContent("Priority") {
                            Picker("Priority", selection: $formData.priority) {
                                Text("None").tag(nil as PriorityLevel?)

                                ForEach(PriorityLevel.allCases, id: \.self) { priority in
                                    Text(priority.displayName).tag(priority as PriorityLevel?)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        LabeledContent("Energy") {
                            Picker("Energy Level", selection: $formData.energyLevel) {
                                Text("None").tag(nil as EnergyLevel?)

                                ForEach(EnergyLevel.allCases, id: \.self) { energyLevel in
                                    Text(energyLevel.displayName).tag(energyLevel as EnergyLevel?)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        LabeledContent("Mode") {
                            Picker("Work Mode", selection: $formData.workMode) {
                                Text("None").tag(nil as WorkModeKind?)

                                ForEach(WorkModeKind.allCases, id: \.self) { workMode in
                                    Text(workMode.displayName).tag(workMode as WorkModeKind?)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        labeledField("Tags") {
                            TextField("Comma-separated tags", text: $formData.tagsText)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.top, 10)
        } label: {
            Label("Detailed Task Info", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
        }
    }

    private var taskGroupPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                Button("No Task Group") {
                    formData.taskGroupText = ""
                }

                ForEach(taskGroups, id: \.self) { taskGroup in
                    Button(taskGroup) {
                        formData.taskGroupText = taskGroup
                    }
                }

                Button("Create New Task Group") {
                    isCreatingTaskGroup = true
                    focusedField = .newTaskGroup
                }
            } label: {
                LabeledContent("Task Group") {
                    Text(formData.taskGroupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "None"
                        : formData.taskGroupText)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.bordered)

            if isCreatingTaskGroup {
                HStack(spacing: 8) {
                    TextField("New task group", text: $newTaskGroupText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .newTaskGroup)
                        .submitLabel(.done)
                        .onSubmit(createTaskGroup)

                    Button("Create", action: createTaskGroup)
                        .disabled(MyTask.cleanedOptionalText(from: newTaskGroupText) == nil)
                }
            }
        }
    }

    private var taskSummaryText: String {
        let title = MyTask.cleanedTitle(from: formData.title) ?? "Untitled task"
        let duration = formData.estimatedMinutesSummaryText
        let dueDateSummary = formData.hasDueDate
            ? "\nDue \(formData.dueDate.formatted(date: .abbreviated, time: .shortened))"
            : ""

        return "\(title)\n\(duration)\(dueDateSummary)"
    }

    private func createTaskGroup() {
        guard let cleanedTaskGroup = MyTask.cleanedOptionalText(from: newTaskGroupText) else {
            return
        }

        formData.taskGroupText = cleanedTaskGroup
        newTaskGroupText = ""
        isCreatingTaskGroup = false
    }

    private func saveTask() {
        guard let task = formData.makeTask() else {
            return
        }

        onSave(task)
        dismiss()
    }

    private func labeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }
}

#Preview {
    NavigationStack {
        TaskQuickAddView { _ in }
    }
}
