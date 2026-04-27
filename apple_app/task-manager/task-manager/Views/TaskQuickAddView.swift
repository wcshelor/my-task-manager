import SwiftUI

struct TaskQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focusedField: Field?
    @State private var formData: MyTaskFormData

    private enum Field: Hashable {
        case title
        case notes
    }

    private let durationOptions = [15, 30, 45, 60, 90]

    let reservedTaskIDs: Set<UUID>
    let onSave: (MyTask) -> Void
    let onOpenDetailedCreate: ((MyTaskFormData) -> Void)?

    init(
        initialFormData: MyTaskFormData = MyTaskFormData(),
        reservedTaskIDs: Set<UUID> = [],
        onSave: @escaping (MyTask) -> Void,
        onOpenDetailedCreate: ((MyTaskFormData) -> Void)? = nil
    ) {
        _formData = State(initialValue: initialFormData)
        self.reservedTaskIDs = reservedTaskIDs
        self.onSave = onSave
        self.onOpenDetailedCreate = onOpenDetailedCreate
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Estimated Duration")
                        .font(.headline)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        durationOptionButton(
                            title: "No Estimate",
                            isSelected: formData.hasEstimatedDuration == false
                        ) {
                            formData.hasEstimatedDuration = false
                        }

                        ForEach(durationOptions, id: \.self) { minutes in
                            durationOptionButton(
                                title: durationLabel(for: minutes),
                                isSelected: formData.hasEstimatedDuration
                                    && formData.estimatedMinutesSelection == minutes
                            ) {
                                formData.hasEstimatedDuration = true
                                formData.estimatedMinutesSelection = minutes
                            }
                        }
                    }
                }

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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved to Inbox by default.")
                        .font(.subheadline.weight(.semibold))

                    Text("Capture first. Add priority, tags, due-date refinements, and other metadata later from the full editor.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(isCompactWidth ? 16 : 20)
        }
        .navigationTitle("Quick Add")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: isCompactWidth ? 10 : 12) {
                Button("Cancel") {
                    dismiss()
                }

                if let onOpenDetailedCreate {
                    Button("More Details") {
                        onOpenDetailedCreate(formData)
                    }
                }

                Spacer(minLength: 0)

                Button("Add Task") {
                    saveTask()
                }
                .buttonStyle(.borderedProminent)
                .disabled(validationMessage != nil)
            }
            .padding(.horizontal, isCompactWidth ? 16 : 20)
            .padding(.vertical, 12)
            .background(.thinMaterial)
        }
        .onAppear {
            focusedField = .title
        }
    }

    @ViewBuilder
    private func durationOptionButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if isSelected {
            Button(action: action) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(action: action) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
    }

    private func durationLabel(for minutes: Int) -> String {
        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60) hr"
        }

        if minutes > 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }

        return "\(minutes)m"
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
