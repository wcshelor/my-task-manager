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

    private enum Field: Hashable {
        case title
        case notes
        case newTaskGroup
    }
    private let hourOptions = Array(0...12)
    private let minuteOptions = [0, 15, 30, 45]

    let taskGroups: [String]
    let reservedTaskIDs: Set<UUID>
    let onSave: (MyTask) -> Void

    init(
        initialFormData: MyTaskFormData = MyTaskFormData(),
        taskGroups: [String] = [],
        reservedTaskIDs: Set<UUID> = [],
        onSave: @escaping (MyTask) -> Void
    ) {
        var preparedFormData = initialFormData
        if preparedFormData.hasEstimatedDuration == false {
            preparedFormData.estimatedMinutesSelection = TaskDurationRules.defaultAssumedMinutes
        }
        _formData = State(initialValue: preparedFormData)
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
                    Text("Title")
                        .font(.headline)

                    TextField("What needs to happen?", text: $formData.title)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.weight(.semibold))
                        .focused($focusedField, equals: .title)
                        .submitLabel(.done)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notes")
                        .font(.headline)

                    TextField(
                        "Optional details",
                        text: $formData.notesText,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .notes)
                }

                durationSection

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Set Due Date", isOn: $formData.hasDueDate)
                        .font(.headline)

                    if formData.hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $formData.dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                    }
                }

                optionalAttributesSection

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
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated Duration")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Hours", selection: durationHoursBinding) {
                    ForEach(hourOptions, id: \.self) { hour in
                        Text("\(hour) hr").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("Minutes", selection: durationMinutesBinding) {
                    ForEach(minuteOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 132)
        }
    }

    @ViewBuilder
    private var optionalAttributesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Optional Details")
                .font(.headline)

            LabeledContent("Status") {
                Picker("Status", selection: $formData.status) {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.menu)
            }

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

            TextField("Tags", text: $formData.tagsText)
                .textFieldStyle(.roundedBorder)
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

    private var durationHoursBinding: Binding<Int> {
        Binding(
            get: { formData.estimatedMinutesSelection / 60 },
            set: { setDuration(hours: $0, minutes: formData.estimatedMinutesSelection % 60) }
        )
    }

    private var durationMinutesBinding: Binding<Int> {
        Binding(
            get: { formData.estimatedMinutesSelection % 60 },
            set: { setDuration(hours: formData.estimatedMinutesSelection / 60, minutes: $0) }
        )
    }

    private var taskSummaryText: String {
        let title = MyTask.cleanedTitle(from: formData.title) ?? "Untitled task"
        let duration = formData.estimatedMinutesDisplayText
        let dueDateSummary = formData.hasDueDate
            ? "\nDue \(formData.dueDate.formatted(date: .abbreviated, time: .shortened))"
            : ""

        return "\(title)\n\(duration)\(dueDateSummary)"
    }

    private func setDuration(hours: Int, minutes: Int) {
        let totalMinutes = max(TaskDurationRules.minutesIncrement, hours * 60 + minutes)
        formData.estimatedMinutesSelection = totalMinutes
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
}

#Preview {
    NavigationStack {
        TaskQuickAddView { _ in }
    }
}
