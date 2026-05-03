import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum SheetDestination: Identifiable {
        case promiseForm
        case promiseCheckIn(Promise)
        case routineBuilder
        case routineChecklist(TodayRoutineProgress)

        var id: String {
            switch self {
            case .promiseForm:
                return "promiseForm"
            case .promiseCheckIn(let promise):
                return "promiseCheckIn-\(promise.id.uuidString)"
            case .routineBuilder:
                return "routineBuilder"
            case .routineChecklist(let progress):
                return "routineChecklist-\(progress.id.uuidString)"
            }
        }
    }

    @StateObject private var viewModel: TodayViewModel
    @State private var presentedSheet: SheetDestination?

    init(
        promiseRepository: any PromiseRepository,
        routineRepository: any RoutineRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: TodayViewModel(
                promiseRepository: promiseRepository,
                routineRepository: routineRepository
            )
        )
    }

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: isCompactWidth ? 18 : 22) {
                    header

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    promiseSection
                    routineSection
                    promiseHistorySection
                }
                .padding(isCompactWidth ? 16 : 20)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        presentedSheet = .routineBuilder
                    } label: {
                        Label("New Routine", systemImage: "list.bullet.clipboard")
                    }

                    Button {
                        presentedSheet = .promiseForm
                    } label: {
                        Label("New Promise", systemImage: "hand.raised.fill")
                    }
                }
            }
            .sheet(item: $presentedSheet) { destination in
                NavigationStack {
                    switch destination {
                    case .promiseForm:
                        PromiseFormView { promise in
                            viewModel.savePromise(promise)
                            presentedSheet = nil
                        }
                    case .promiseCheckIn(let promise):
                        PromiseCheckInView(
                            promise: promise,
                            onResolve: { outcome, reflection in
                                viewModel.resolvePromise(
                                    withID: promise.id,
                                    outcome: outcome,
                                    reflection: reflection
                                )
                                presentedSheet = nil
                            },
                            onReset: { title, checkInAt in
                                viewModel.makeResetPromise(
                                    from: promise,
                                    title: title,
                                    checkInAt: checkInAt
                                )
                                presentedSheet = nil
                            }
                        )
                    case .routineBuilder:
                        RoutineBuilderView { routine in
                            viewModel.saveRoutine(routine)
                            presentedSheet = nil
                        }
                    case .routineChecklist(let progress):
                        RoutineChecklistView(
                            progress: progress,
                            onSetItem: { itemID, completed in
                                viewModel.setRoutineItem(
                                    routineID: progress.routine.id,
                                    itemID: itemID,
                                    completed: completed
                                )
                            }
                        )
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                viewModel.handleSceneDidBecomeActive()
            }
            .task {
                viewModel.loadIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What needs to stay present?")
                .font(.title2.weight(.semibold))

            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var promiseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Promises", systemImage: "hand.raised.fill")
                    .font(.headline)
                Spacer()
                Button {
                    presentedSheet = .promiseForm
                } label: {
                    Label("New Promise", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if viewModel.activePromises.isEmpty {
                ContentUnavailableView(
                    "No Active Promises",
                    systemImage: "hand.raised",
                    description: Text("Make one clear promise when you want your word to stay visible.")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.activePromises) { promise in
                    PromiseCard(
                        promise: promise,
                        isDue: viewModel.duePromises.contains { $0.id == promise.id },
                        onCheckIn: {
                            presentedSheet = .promiseCheckIn(promise)
                        }
                    )
                }
            }
        }
    }

    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Routines", systemImage: "checklist.checked")
                    .font(.headline)
                Spacer()
                Button {
                    presentedSheet = .routineBuilder
                } label: {
                    Label("New Routine", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if viewModel.routineProgress.isEmpty {
                ContentUnavailableView(
                    "No Routines Today",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Create a routine with daily or weekday timing.")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.routineProgress) { progress in
                    Button {
                        presentedSheet = .routineChecklist(progress)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: progress.completedCount == progress.totalCount ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(progress.completedCount == progress.totalCount ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(progress.routine.name)
                                    .font(.body.weight(.medium))
                                Text(progress.progressLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var promiseHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Promise History", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            HStack(spacing: 12) {
                PromiseStatView(title: "Kept", value: viewModel.keptCount, color: .green)
                PromiseStatView(title: "Missed", value: viewModel.missedCount, color: .orange)
            }

            ForEach(viewModel.promiseHistory.prefix(5)) { promise in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: promise.outcome == .kept ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(promise.outcome == .kept ? .green : .orange)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(promise.title)
                            .font(.subheadline.weight(.medium))
                        if let resolvedAt = promise.resolvedAt {
                            Text(resolvedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct PromisePresenceBanner: View {
    @StateObject private var viewModel: PromisePresenceViewModel

    init(promiseRepository: any PromiseRepository) {
        _viewModel = StateObject(
            wrappedValue: PromisePresenceViewModel(promiseRepository: promiseRepository)
        )
    }

    var body: some View {
        if let promise = viewModel.activePromises.first {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text(promise.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(promise.checkInAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .task {
                viewModel.load()
            }
        } else {
            EmptyView()
                .task {
                    viewModel.load()
                }
        }
    }
}

private struct PromiseCard: View {
    let promise: Promise
    let isDue: Bool
    let onCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(promise.title)
                        .font(.headline)
                    Text("Check in \(promise.checkInAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isDue ? "Check In" : "Open") {
                    onCheckIn()
                }
                .buttonStyle(.borderedProminent)
            }

            if let whyItMatters = promise.whyItMatters {
                Text(whyItMatters)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let expectedFriction = promise.expectedFriction {
                Label(expectedFriction, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PromiseStatView: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PromiseFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var startAt = Date()
    @State private var checkInAt = Date().addingTimeInterval(60 * 60)
    @State private var whyItMatters = ""
    @State private var expectedFriction = ""

    let onSave: (Promise) -> Void

    var body: some View {
        Form {
            Section("Promise") {
                TextField("Title", text: $title)
                TextField("Why it matters", text: $whyItMatters, axis: .vertical)
                TextField("Expected friction or excuse", text: $expectedFriction, axis: .vertical)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Timing") {
                DatePicker("Starts", selection: $startAt)
                DatePicker("Check In", selection: $checkInAt)
            }
        }
        .navigationTitle("New Promise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        Promise(
                            title: title,
                            notes: notes,
                            startAt: startAt,
                            checkInAt: checkInAt,
                            whyItMatters: whyItMatters,
                            expectedFriction: expectedFriction
                        )
                    )
                }
                .disabled(Promise.cleanedTitle(from: title) == nil)
            }
        }
    }
}

private struct PromiseCheckInView: View {
    @Environment(\.dismiss) private var dismiss

    let promise: Promise
    let onResolve: (PromiseOutcome, String?) -> Void
    let onReset: (String, Date) -> Void

    @State private var reflection = ""
    @State private var resetTitle = ""
    @State private var resetCheckInAt = Date().addingTimeInterval(60 * 60)

    var body: some View {
        Form {
            Section("Promise") {
                Text(promise.title)
                if let whyItMatters = promise.whyItMatters {
                    Text(whyItMatters)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Check In") {
                TextField("What happened?", text: $reflection, axis: .vertical)
                Button {
                    onResolve(.kept, reflection)
                } label: {
                    Label("Kept", systemImage: "checkmark.circle.fill")
                }
                Button {
                    onResolve(.missed, reflection)
                } label: {
                    Label("Missed", systemImage: "exclamationmark.circle.fill")
                }
            }

            Section("Reset") {
                TextField("Reset promise", text: $resetTitle)
                DatePicker("Check In", selection: $resetCheckInAt)
                Button {
                    onReset(resetTitle, resetCheckInAt)
                } label: {
                    Label("Create Reset Promise", systemImage: "arrow.clockwise")
                }
                .disabled(Promise.cleanedTitle(from: resetTitle) == nil)
            }
        }
        .navigationTitle("Check In")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            resetTitle = promise.title
        }
    }
}

private struct RoutineBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var notes = ""
    @State private var itemText = ""
    @State private var selectedWeekdays: Set<RoutineWeekday> = []

    let onSave: (Routine) -> Void

    var body: some View {
        Form {
            Section("Routine") {
                TextField("Name", text: $name)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Days") {
                Toggle("Daily", isOn: dailyBinding)
                if selectedWeekdays.isEmpty == false {
                    ForEach(RoutineWeekday.allCases, id: \.self) { weekday in
                        Toggle(weekday.shortName, isOn: weekdayBinding(for: weekday))
                    }
                }
            }

            Section("Items") {
                TextEditor(text: $itemText)
                    .frame(minHeight: 120)
                Text("One item per line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("New Routine")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let routine = Routine(
                        newName: name,
                        itemTitles: itemText.components(separatedBy: .newlines),
                        activeWeekdays: Array(selectedWeekdays)
                    ) else {
                        return
                    }

                    var routineWithNotes = routine
                    routineWithNotes.notes = MyTask.cleanedOptionalText(from: notes)
                    onSave(routineWithNotes)
                }
                .disabled(Routine.cleanedName(from: name) == nil || cleanedItemTitles.isEmpty)
            }
        }
    }

    private var cleanedItemTitles: [String] {
        itemText.components(separatedBy: .newlines).compactMap(RoutineItem.cleanedTitle)
    }

    private var dailyBinding: Binding<Bool> {
        Binding(
            get: { selectedWeekdays.isEmpty },
            set: { isDaily in
                selectedWeekdays = isDaily ? [] : Set(RoutineWeekday.allCases)
            }
        )
    }

    private func weekdayBinding(for weekday: RoutineWeekday) -> Binding<Bool> {
        Binding(
            get: { selectedWeekdays.contains(weekday) },
            set: { isSelected in
                if isSelected {
                    selectedWeekdays.insert(weekday)
                } else {
                    selectedWeekdays.remove(weekday)
                }
            }
        )
    }
}

private struct RoutineChecklistView: View {
    @Environment(\.dismiss) private var dismiss

    let progress: TodayRoutineProgress
    let onSetItem: (UUID, Bool) -> Void

    var body: some View {
        List {
            ForEach(progress.routine.orderedItems) { item in
                Toggle(
                    item.title,
                    isOn: Binding(
                        get: {
                            progress.completionLog?.completedItemIDs.contains(item.id) ?? false
                        },
                        set: { isCompleted in
                            onSetItem(item.id, isCompleted)
                        }
                    )
                )
            }
        }
        .navigationTitle(progress.routine.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    let container = AppContainer.makePreview()
    TodayView(
        promiseRepository: container.promiseRepository,
        routineRepository: container.routineRepository
    )
}
