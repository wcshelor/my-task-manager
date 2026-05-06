import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum SheetDestination: Identifiable {
        case taskQuickAdd
        case promiseForm
        case promiseCheckIn(Promise)
        case routineBuilder
        case routineSession(UUID)

        var id: String {
            switch self {
            case .taskQuickAdd:
                return "taskQuickAdd"
            case .promiseForm:
                return "promiseForm"
            case .promiseCheckIn(let promise):
                return "promiseCheckIn-\(promise.id.uuidString)"
            case .routineBuilder:
                return "routineBuilder"
            case .routineSession(let routineID):
                return "routineSession-\(routineID.uuidString)"
            }
        }
    }

    @StateObject private var viewModel: TodayViewModel
    @State private var presentedSheet: SheetDestination?
    @State private var isPlannerPresented = false

    private let taskRepository: any TaskRepository
    private let scheduledBlockRepository: any ScheduledBlockRepository
    private let settingsRepository: any SettingsRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarListingService: any CalendarListing
    private let calendarReader: any CalendarReading
    private let calendarWriter: any CalendarWriting
    private let calendarReconciler: any CalendarReconciling
    private let calendarChangeObserver: any CalendarChangeObserving
    private let promiseRepository: any PromiseRepository

    init(
        taskRepository: any TaskRepository,
        scheduledBlockRepository: any ScheduledBlockRepository,
        settingsRepository: any SettingsRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing,
        calendarReader: any CalendarReading,
        calendarWriter: any CalendarWriting,
        calendarReconciler: any CalendarReconciling,
        calendarChangeObserver: any CalendarChangeObserving,
        promiseRepository: any PromiseRepository,
        routineRepository: any RoutineRepository
    ) {
        self.taskRepository = taskRepository
        self.scheduledBlockRepository = scheduledBlockRepository
        self.settingsRepository = settingsRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarListingService = calendarListingService
        self.calendarReader = calendarReader
        self.calendarWriter = calendarWriter
        self.calendarReconciler = calendarReconciler
        self.calendarChangeObserver = calendarChangeObserver
        self.promiseRepository = promiseRepository
        _viewModel = StateObject(
            wrappedValue: TodayViewModel(
                taskRepository: taskRepository,
                promiseRepository: promiseRepository,
                routineRepository: routineRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarReader: calendarReader
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

                    calendarOverviewSection
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
                        presentedSheet = .taskQuickAdd
                    } label: {
                        Label("New Task", systemImage: "checklist")
                    }

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
                    case .taskQuickAdd:
                        TaskQuickAddView(
                            taskGroups: viewModel.taskGroups,
                            reservedTaskIDs: viewModel.reservedTaskIDs
                        ) { task in
                            viewModel.saveTask(task)
                            presentedSheet = nil
                        }
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
                    case .routineSession(let routineID):
                        RoutineSessionView(
                            viewModel: viewModel,
                            routineID: routineID
                        )
                    }
                }
            }
            .navigationDestination(isPresented: $isPlannerPresented) {
                PlannerView(
                    taskRepository: taskRepository,
                    scheduledBlockRepository: scheduledBlockRepository,
                    settingsRepository: settingsRepository,
                    calendarPermissionProvider: calendarPermissionProvider,
                    calendarListingService: calendarListingService,
                    calendarReader: calendarReader,
                    calendarWriter: calendarWriter,
                    calendarReconciler: calendarReconciler,
                    calendarChangeObserver: calendarChangeObserver,
                    promiseRepository: promiseRepository,
                    navigationTitle: "Plan the Day"
                )
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

    @ViewBuilder
    private var calendarOverviewSection: some View {
        if let overview = viewModel.calendarOverview {
            TodayCalendarOverviewCard(
                overview: overview,
                onPlanTheDay: {
                    isPlannerPresented = true
                }
            )
        } else if viewModel.calendarPermissionStatus != nil {
            TodayCalendarPermissionCard(status: viewModel.calendarPermissionStatus!)
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
                ForEach(Array(viewModel.routineProgress), id: \TodayRoutineProgress.id) { (progress: TodayRoutineProgress) in
                    Button {
                        presentedSheet = .routineSession(progress.routine.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: progress.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(progress.isComplete ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(progress.routine.name)
                                    .font(.body.weight(.medium))
                                Text(progress.progressLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            Text(progress.actionLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(progress.isComplete ? Color.secondary : Color.blue)
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

private struct TodayCalendarOverviewCard: View {
    let overview: TodayCalendarOverview
    let onPlanTheDay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Today’s Events", systemImage: "calendar.badge.clock")
                        .font(.headline)

                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let nextEvent = overview.nextEvent {
                    Text("Next \(nextEvent.start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }

            if overview.events.isEmpty {
                Text("No calendar events on the books today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(overview.events.prefix(3).enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(event.isAllDay ? Color.blue : Color.orange)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(.subheadline.weight(.medium))
                            Text(eventTimeLabel(for: event))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(event.calendarTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if overview.events.count > 3 {
                    Text("+ \(overview.events.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onPlanTheDay()
            } label: {
                Label("Plan the Day", systemImage: "calendar.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.14), lineWidth: 1)
        )
    }

    private var summaryText: String {
        if overview.events.isEmpty {
            return "Your day is open so far."
        }

        if overview.allDayEvents.isEmpty {
            return overview.events.count == 1 ? "1 event scheduled today." : "\(overview.events.count) events scheduled today."
        }

        return "\(overview.events.count) events, including \(overview.allDayEvents.count) all-day."
    }

    private func eventTimeLabel(for event: CalendarEventSnapshot) -> String {
        if event.isAllDay {
            return "All day"
        }

        return "\(event.start.formatted(date: .omitted, time: .shortened)) - \(event.end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct TodayCalendarPermissionCard: View {
    let status: CalendarPermissionStatus

    var body: some View {
        if status != .fullAccessGranted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Today’s Events", systemImage: "calendar.badge.exclamationmark")
                    .font(.headline)

                Text(copyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var copyText: String {
        switch status {
        case .notDetermined:
            return "Calendar access is pending, so today’s event overview is not available yet."
        case .fullAccessGranted:
            return ""
        case .writeOnlyGrantedButInsufficient, .denied, .restricted:
            return "Grant full Calendar access to show today’s event overview here."
        case .error(let message):
            return message
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

private struct RoutineSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TodayViewModel

    let routineID: UUID

    var body: some View {
        Group {
            if let progress = viewModel.progress(for: routineID) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(progress.progressLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ProgressView(
                            value: Double(progress.completedCount),
                            total: Double(max(progress.totalCount, 1))
                        )
                    }

                    Spacer()

                    if progress.isComplete {
                        VStack(alignment: .center, spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.green)

                            Text("Routine Complete")
                                .font(.title2.weight(.semibold))

                            Text("All items are done for today.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else if let item = progress.currentItem {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Current Step")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(item.title)
                                .font(.title2.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button {
                            viewModel.completeCurrentRoutineItem(routineID: routineID)
                        } label: {
                            Label("Complete Step", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()

                    Button("Leave Routine") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .navigationTitle(progress.routine.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "Routine Not Available",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This routine is no longer active today.")
                )
                .navigationTitle("Routine")
            }
        }
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
        taskRepository: container.taskRepository,
        scheduledBlockRepository: container.scheduledBlockRepository,
        settingsRepository: container.settingsRepository,
        calendarPermissionProvider: container.calendarPermissionProvider,
        calendarListingService: container.calendarListingService,
        calendarReader: container.calendarReader,
        calendarWriter: container.calendarWriter,
        calendarReconciler: container.calendarReconciler,
        calendarChangeObserver: container.calendarChangeObserver,
        promiseRepository: container.promiseRepository,
        routineRepository: container.routineRepository
    )
}
