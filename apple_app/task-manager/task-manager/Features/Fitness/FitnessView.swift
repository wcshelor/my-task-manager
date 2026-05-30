import SwiftUI

struct FitnessView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FitnessViewModel
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var selectedExercise: FitnessExercise?
    @State private var presentedSheet: FitnessSheet?

    private let onChange: () -> Void

    init(
        fitnessRepository: any FitnessRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: FitnessViewModel(fitnessRepository: fitnessRepository)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Section("Workout Days") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: [GridItem(.fixed(110))], spacing: 12) {
                            Button {
                                presentedSheet = .template(nil)
                            } label: {
                                AddWorkoutDayCard()
                            }
                            .buttonStyle(.plain)

                            ForEach(viewModel.workoutTemplates) { template in
                                Button {
                                    selectedTemplate = template
                                } label: {
                                    WorkoutDayCard(template: template)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Edit") {
                                        presentedSheet = .template(template)
                                    }
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteWorkoutTemplate(withID: template.id)
                                        onChange()
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 130)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    Picker("Sort", selection: $viewModel.sortOption) {
                        ForEach(ExerciseSortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Exercise Library") {
                    if viewModel.sortedExercises.isEmpty {
                        ContentUnavailableView(
                            "No Exercises",
                            systemImage: "dumbbell",
                            description: Text("Create your first exercise to start logging sessions.")
                        )
                    } else {
                        ForEach(viewModel.sortedExercises) { exercise in
                            Button {
                                selectedExercise = exercise
                            } label: {
                                ExerciseLibraryRow(
                                    exercise: exercise,
                                    latestSession: viewModel.latestSession(for: exercise.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button {
                                    presentedSheet = .session(exercise, nil)
                                } label: {
                                    Label("Log", systemImage: "plus.circle")
                                }
                                .tint(.accentColor)

                                Button {
                                    presentedSheet = .exercise(exercise)
                                } label: {
                                    Label("Edit", systemImage: "square.and.pencil")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fitness")
            .task {
                viewModel.loadIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentedSheet = .exercise(nil)
                    } label: {
                        Label("Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                NavigationStack {
                    switch sheet {
                    case .exercise(let exercise):
                        FitnessExerciseFormView(initialExercise: exercise) { savedExercise in
                            viewModel.saveExercise(savedExercise, replacingExerciseWithID: exercise?.id)
                            onChange()
                            presentedSheet = nil
                        }
                    case .template(let template):
                        WorkoutTemplateFormView(
                            initialTemplate: template,
                            exercises: viewModel.exercises
                        ) { savedTemplate in
                            viewModel.saveWorkoutTemplate(
                                savedTemplate,
                                replacingWorkoutTemplateWithID: template?.id
                            )
                            onChange()
                            presentedSheet = nil
                        } onDelete: {
                            guard let template else { return }
                            viewModel.deleteWorkoutTemplate(withID: template.id)
                            onChange()
                            presentedSheet = nil
                        }
                    case .session(let exercise, let session):
                        ExerciseSessionFormView(
                            exercise: exercise,
                            initialSession: session,
                            lastSession: viewModel.latestSession(for: exercise.id)
                        ) { savedSession in
                            viewModel.saveExerciseSession(
                                savedSession,
                                replacingExerciseSessionWithID: session?.id
                            )
                            onChange()
                            presentedSheet = nil
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedTemplate) { template in
                WorkoutTemplateDetailView(
                    summary: viewModel.templateRows(for: template),
                    onEdit: {
                        presentedSheet = .template(template)
                    },
                    onSelectExercise: { exercise in
                        selectedExercise = exercise
                    }
                )
            }
            .navigationDestination(item: $selectedExercise) { exercise in
                ExerciseDetailView(
                    exercise: exercise,
                    sessions: viewModel.recentSessions(for: exercise.id, limit: 20),
                    loggedToday: viewModel.loggedToday(for: exercise.id),
                    onEditExercise: {
                        presentedSheet = .exercise(exercise)
                    },
                    onLogSession: {
                        presentedSheet = .session(exercise, nil)
                    },
                    onEditSession: { session in
                        presentedSheet = .session(exercise, session)
                    },
                    onDeleteSession: { session in
                        viewModel.deleteExerciseSession(withID: session.id)
                        onChange()
                    }
                )
            }
        }
    }

}

private enum FitnessSheet: Identifiable {
    case exercise(FitnessExercise?)
    case template(WorkoutTemplate?)
    case session(FitnessExercise, ExerciseSession?)

    var id: String {
        switch self {
        case .exercise(let exercise):
            return "exercise-\(exercise?.id.uuidString ?? "new")"
        case .template(let template):
            return "template-\(template?.id.uuidString ?? "new")"
        case .session(let exercise, let session):
            return "session-\(exercise.id.uuidString)-\(session?.id.uuidString ?? "new")"
        }
    }
}

private struct AddWorkoutDayCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Workout Day")
                        .font(.headline)
                }
                .foregroundStyle(.primary)
            }
            .frame(width: 140, height: 110)
    }
}

private struct WorkoutDayCard: View {
    let template: WorkoutTemplate

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.accentColor.opacity(0.12))
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(template.exerciseIDs.count) exercise\(template.exerciseIDs.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(width: 160, height: 110)
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: FitnessExercise
    let latestSession: ExerciseSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(exercise.tag.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(exercise.trackingStyle.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(latestSession.map { "Latest: \($0.summaryText)" } ?? "No sessions yet")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct WorkoutTemplateDetailView: View {
    let summary: FitnessTemplateRowSummary
    let onEdit: () -> Void
    let onSelectExercise: (FitnessExercise) -> Void

    var body: some View {
        List {
            ForEach(summary.rows) { row in
                Button {
                    onSelectExercise(row.exercise)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.exercise.name)
                                .font(.body.weight(.semibold))
                            Spacer()
                            if row.loggedToday {
                                Text("Logged today")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("\(row.exercise.tag.displayName) · \(row.exercise.trackingStyle.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(row.latestSession.map { "Last: \($0.summaryText)" } ?? "No sessions yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(row.priorSessions.enumerated()), id: \.element.id) { _, session in
                            Text(session.summaryText)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(summary.template.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: onEdit)
            }
        }
    }
}

private struct ExerciseDetailView: View {
    let exercise: FitnessExercise
    let sessions: [ExerciseSession]
    let loggedToday: Bool
    let onEditExercise: () -> Void
    let onLogSession: () -> Void
    let onEditSession: (ExerciseSession) -> Void
    let onDeleteSession: (ExerciseSession) -> Void

    var body: some View {
        List {
            Section("Exercise") {
                LabeledContent("Tag", value: exercise.tag.displayName)
                LabeledContent("Tracking", value: exercise.trackingStyle.displayName)
                if let weightUnit = exercise.weightUnit {
                    LabeledContent("Weight Unit", value: weightUnit.displayName)
                }
                if let distanceUnit = exercise.distanceUnit {
                    LabeledContent("Distance Unit", value: distanceUnit.displayName)
                }
                if exercise.selectableMetricFields.isEmpty == false {
                    LabeledContent(
                        "Fields",
                        value: exercise.selectableMetricFields.map(\.displayName).joined(separator: ", ")
                    )
                }
                if loggedToday {
                    Text("Logged today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Recent History") {
                if let latestSession = sessions.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last logged \(latestSession.performedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline.weight(.semibold))
                        Text(latestSession.summaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if sessions.isEmpty {
                    Text("No sessions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.body.weight(.semibold))
                            Text(session.summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button {
                                onEditSession(session)
                            } label: {
                                Label("Edit", systemImage: "square.and.pencil")
                            }

                            Button(role: .destructive) {
                                onDeleteSession(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Log", action: onLogSession)
                Button("Edit", action: onEditExercise)
            }
        }
    }
}

private struct FitnessExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialExercise: FitnessExercise?
    let onSave: (FitnessExercise) -> Void

    @State private var name: String
    @State private var tag: FitnessTag
    @State private var trackingStyle: ExerciseTrackingStyle
    @State private var metricFields: Set<SelectableMetricField>
    @State private var weightUnit: WeightUnit
    @State private var distanceUnit: DistanceUnit

    init(
        initialExercise: FitnessExercise?,
        onSave: @escaping (FitnessExercise) -> Void
    ) {
        self.initialExercise = initialExercise
        self.onSave = onSave
        _name = State(initialValue: initialExercise?.name ?? "")
        _tag = State(initialValue: initialExercise?.tag ?? .push)
        _trackingStyle = State(initialValue: initialExercise?.trackingStyle ?? .strengthSets)
        _metricFields = State(initialValue: Set(initialExercise?.selectableMetricFields ?? [.durationMinutes]))
        _weightUnit = State(initialValue: initialExercise?.weightUnit ?? .pounds)
        _distanceUnit = State(initialValue: initialExercise?.distanceUnit ?? .miles)
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)
                Picker("Tag", selection: $tag) {
                    ForEach(FitnessTag.allCases, id: \.self) { tag in
                        Text(tag.displayName).tag(tag)
                    }
                }
                Picker("Tracking", selection: $trackingStyle) {
                    ForEach(ExerciseTrackingStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            }

            if trackingStyle == .strengthSets {
                Section("Strength") {
                    Picker("Weight Unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            } else {
                Section("Metrics") {
                    ForEach(SelectableMetricField.allCases, id: \.self) { field in
                        Toggle(
                            field.displayName,
                            isOn: Binding(
                                get: { metricFields.contains(field) },
                                set: { isEnabled in
                                    if isEnabled {
                                        metricFields.insert(field)
                                    } else {
                                        metricFields.remove(field)
                                    }
                                }
                            )
                        )
                    }

                    if metricFields.contains(.distance) {
                        Picker("Distance Unit", selection: $distanceUnit) {
                            ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(initialExercise == nil ? "New Exercise" : "Edit Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let exercise = makeExercise() else {
                        return
                    }
                    onSave(exercise)
                }
            }
        }
    }

    private func makeExercise() -> FitnessExercise? {
        let fields = Array(metricFields)
        guard let cleanedName = FitnessExercise.cleanedName(from: name),
              FitnessExercise.isConfigurationValid(
                trackingStyle: trackingStyle,
                selectableMetricFields: fields,
                weightUnit: trackingStyle == .strengthSets ? weightUnit : nil,
                distanceUnit: trackingStyle == .metricSummary && metricFields.contains(.distance) ? distanceUnit : nil
              ) else {
            return nil
        }

        return FitnessExercise(
            id: initialExercise?.id ?? UUID(),
            name: cleanedName,
            tag: tag,
            trackingStyle: trackingStyle,
            selectableMetricFields: fields,
            weightUnit: trackingStyle == .strengthSets ? weightUnit : nil,
            distanceUnit: trackingStyle == .metricSummary && metricFields.contains(.distance) ? distanceUnit : nil,
            createdAt: initialExercise?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}

private struct WorkoutTemplateFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialTemplate: WorkoutTemplate?
    let exercises: [FitnessExercise]
    let onSave: (WorkoutTemplate) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var exerciseIDs: [UUID]

    init(
        initialTemplate: WorkoutTemplate?,
        exercises: [FitnessExercise],
        onSave: @escaping (WorkoutTemplate) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.initialTemplate = initialTemplate
        self.exercises = exercises
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initialTemplate?.name ?? "")
        _exerciseIDs = State(initialValue: initialTemplate?.exerciseIDs ?? [])
    }

    var body: some View {
        Form {
            Section("Workout Day") {
                TextField("Name", text: $name)
            }

            Section("Exercises") {
                if exerciseIDs.isEmpty {
                    Text("Add at least one exercise.")
                        .foregroundStyle(.secondary)
                }

                ForEach(selectedExercises) { exercise in
                    HStack {
                        Text(exercise.name)
                        Spacer()
                        Button(role: .destructive) {
                            exerciseIDs.removeAll { $0 == exercise.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { source, destination in
                    exerciseIDs.move(fromOffsets: source, toOffset: destination)
                }
            }

            Section("Add Existing") {
                ForEach(availableExercises) { exercise in
                    Button(exercise.name) {
                        exerciseIDs.append(exercise.id)
                    }
                }
            }
        }
        .navigationTitle(initialTemplate == nil ? "New Workout Day" : "Edit Workout Day")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let template = makeTemplate() else {
                        return
                    }
                    onSave(template)
                }
            }
            if initialTemplate != nil {
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete", role: .destructive, action: onDelete)
                }
            }
        }
    }

    private var selectedExercises: [FitnessExercise] {
        exerciseIDs.compactMap { id in
            exercises.first { $0.id == id }
        }
    }

    private var availableExercises: [FitnessExercise] {
        exercises.filter { exerciseIDs.contains($0.id) == false }
    }

    private func makeTemplate() -> WorkoutTemplate? {
        guard let cleanedName = WorkoutTemplate.cleanedName(from: name) else {
            return nil
        }

        let cleanedExerciseIDs = WorkoutTemplate.cleanedExerciseIDs(exerciseIDs)
        guard cleanedExerciseIDs.isEmpty == false else {
            return nil
        }

        return WorkoutTemplate(
            id: initialTemplate?.id ?? UUID(),
            name: cleanedName,
            exerciseIDs: cleanedExerciseIDs,
            createdAt: initialTemplate?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}

private struct ExerciseSessionFormView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: FitnessExercise
    let initialSession: ExerciseSession?
    let lastSession: ExerciseSession?
    let onSave: (ExerciseSession) -> Void

    @State private var strengthSets: [StrengthSet]
    @State private var durationMinutes: Int
    @State private var difficultyLevel: Int
    @State private var averageRPM: Int
    @State private var distance: Double

    init(
        exercise: FitnessExercise,
        initialSession: ExerciseSession?,
        lastSession: ExerciseSession?,
        onSave: @escaping (ExerciseSession) -> Void
    ) {
        self.exercise = exercise
        self.initialSession = initialSession
        self.lastSession = lastSession
        self.onSave = onSave
        _strengthSets = State(initialValue: initialSession?.strengthSets ?? [StrengthSet(reps: 0)])
        _durationMinutes = State(initialValue: initialSession?.durationMinutes ?? 0)
        _difficultyLevel = State(initialValue: initialSession?.difficultyLevel ?? 5)
        _averageRPM = State(initialValue: initialSession?.averageRPM ?? 0)
        _distance = State(initialValue: initialSession?.distance ?? 0)
    }

    var body: some View {
        Form {
            if let lastSession {
                Section("Last Session") {
                    Text(lastSession.performedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastSession.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if exercise.trackingStyle == .strengthSets {
                Section("Sets") {
                    ForEach(strengthSets.indices, id: \.self) { index in
                        HStack {
                            Stepper("Reps \(strengthSets[index].reps)", value: Binding(
                                get: { strengthSets[index].reps },
                                set: { strengthSets[index].reps = $0 }
                            ), in: 0...100)
                            TextField(
                                exercise.weightUnit?.displayName ?? "Weight",
                                value: Binding(
                                    get: { strengthSets[index].weight ?? 0 },
                                    set: { strengthSets[index].weight = $0 == 0 ? nil : $0 }
                                ),
                                format: .number
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        }
                    }
                    .onDelete { offsets in
                        strengthSets.remove(atOffsets: offsets)
                    }

                    Button("Add Set") {
                        strengthSets.append(StrengthSet(reps: 0))
                    }
                }
            } else {
                Section("Metrics") {
                    if exercise.selectableMetricFields.contains(.durationMinutes) {
                        Stepper("Duration \(durationMinutes)m", value: $durationMinutes, in: 0...600)
                    }
                    if exercise.selectableMetricFields.contains(.difficultyLevel) {
                        Stepper("Difficulty \(difficultyLevel)", value: $difficultyLevel, in: 1...10)
                    }
                    if exercise.selectableMetricFields.contains(.averageRPM) {
                        Stepper("Average RPM \(averageRPM)", value: $averageRPM, in: 0...300)
                    }
                    if exercise.selectableMetricFields.contains(.distance) {
                        TextField(
                            "Distance (\(exercise.distanceUnit?.displayName ?? ""))",
                            value: $distance,
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                    }
                }
            }
        }
        .navigationTitle(initialSession == nil ? "Log Session" : "Edit Session")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let session = makeSession()
                    guard session.isValid(for: exercise) else {
                        return
                    }
                    onSave(session)
                }
            }
        }
    }

    private func makeSession() -> ExerciseSession {
        ExerciseSession(
            id: initialSession?.id ?? UUID(),
            exerciseID: exercise.id,
            performedAt: initialSession?.performedAt ?? .now,
            strengthSets: exercise.trackingStyle == .strengthSets ? strengthSets : [],
            durationMinutes: exercise.selectableMetricFields.contains(.durationMinutes) ? durationMinutes : nil,
            difficultyLevel: exercise.selectableMetricFields.contains(.difficultyLevel) ? difficultyLevel : nil,
            averageRPM: exercise.selectableMetricFields.contains(.averageRPM) ? averageRPM : nil,
            distance: exercise.selectableMetricFields.contains(.distance) ? distance : nil,
            createdAt: initialSession?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}
