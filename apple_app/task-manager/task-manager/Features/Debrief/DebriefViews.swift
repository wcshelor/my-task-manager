import SwiftUI

@MainActor
final class DebriefQueueViewModel: ObservableObject {
    @Published private(set) var pendingCandidates: [CalendarDebriefCandidate] = []
    @Published private(set) var completedTodayCount = 0
    @Published private(set) var errorMessage: String?

    private let debriefRepository: any DebriefRepository
    private let captureRepository: any CaptureRepository
    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let calendarBlockFocusRepository: any CalendarBlockFocusRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarReader: any CalendarReading
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private let queueSettings: DebriefQueueSettings
    private var cachedDebriefsByEventKey: [String: CalendarDebriefRecord] = [:]
    private var cachedTasksByID: [UUID: MyTask] = [:]
    private var cachedProjectsByID: [UUID: Project] = [:]
    private var cachedFocusesByEventLookupKey: [String: CalendarBlockFocus] = [:]

    init(
        debriefRepository: any DebriefRepository,
        captureRepository: any CaptureRepository,
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        calendarBlockFocusRepository: any CalendarBlockFocusRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarReader: any CalendarReading,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        queueSettings: DebriefQueueSettings = .mvpDefault
    ) {
        self.debriefRepository = debriefRepository
        self.captureRepository = captureRepository
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.calendarBlockFocusRepository = calendarBlockFocusRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarReader = calendarReader
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.queueSettings = queueSettings
    }

    func load() async {
        let permissionStatus = calendarPermissionProvider.currentStatus()
        guard permissionStatus == .fullAccessGranted else {
            pendingCandidates = []
            errorMessage = "Calendar access is required to surface Debriefs."
            return
        }

        let now = nowProvider()
        let queueStart = calendar.date(
            byAdding: .day,
            value: -max(1, queueSettings.lookbackDays),
            to: now
        ) ?? now.addingTimeInterval(-Double(max(1, queueSettings.lookbackDays)) * 86_400)

        do {
            let events = try await calendarReader.fetchEvents(
                in: DateInterval(start: queueStart, end: now)
            )
            let debriefs = try debriefRepository.fetchDebriefs()
            let tasks = try taskRepository.fetchTasks()
            let projects = try projectRepository.fetchProjects(includeArchived: false)
            let focuses = try calendarBlockFocusRepository.fetchFocuses(
                in: DateInterval(start: queueStart, end: now)
            )
            cachedDebriefsByEventKey = Dictionary(
                uniqueKeysWithValues: debriefs.map { ($0.eventKey, $0) }
            )
            cachedTasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
            cachedProjectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
            cachedFocusesByEventLookupKey = Dictionary(
                uniqueKeysWithValues: focuses.map { focus in
                    (
                        Self.focusLookupKey(
                            eventIdentifier: focus.eventIdentifier,
                            calendarIdentifier: focus.calendarIdentifier
                        ),
                        focus
                    )
                }
            )
            completedTodayCount = debriefs.filter { debrief in
                guard let completedAt = debrief.completedAt else {
                    return false
                }

                return calendar.isDate(completedAt, inSameDayAs: now)
            }.count
            pendingCandidates = enrichCandidates(
                DebriefQueueService(settings: queueSettings).pendingCandidates(
                from: events,
                existingDebriefs: debriefs,
                now: now
                )
            )
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load Debriefs: \(error.localizedDescription)"
            pendingCandidates = []
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func draft(for candidate: CalendarDebriefCandidate) -> DebriefDraft {
        let focus = focus(for: candidate)
        let selectedTasks = focus?.selectedTaskIDs.compactMap { cachedTasksByID[$0] } ?? []
        return DebriefDraft(
            candidate: candidate,
            existingDebrief: cachedDebriefsByEventKey[candidate.eventKey],
            blockFocus: focus,
            selectedTasks: selectedTasks
        )
    }

    func completeDebrief(
        for candidate: CalendarDebriefCandidate,
        draft: DebriefDraft
    ) throws {
        let now = nowProvider()
        var captureIDs: [UUID] = []

        for captureText in draft.captureLines {
            guard let cleanedTitle = CaptureItem.cleanedTitle(from: captureText) else {
                continue
            }

            let capture = CaptureItem(
                title: cleanedTitle,
                source: "Debrief · \(candidate.title)",
                createdAt: now,
                updatedAt: now
            )
            try captureRepository.saveCapture(capture, replacingCaptureWithID: nil)
            captureIDs.append(capture.id)
        }

        let existingDebrief = cachedDebriefsByEventKey[candidate.eventKey]
        let debriefID = existingDebrief?.id ?? UUID()
        let taskOutcomes = draft.taskOutcomeDrafts.map { taskOutcomeDraft in
            DebriefTaskOutcome(
                debriefID: debriefID,
                taskID: taskOutcomeDraft.taskID,
                taskTitleSnapshot: taskOutcomeDraft.taskTitleSnapshot,
                outcome: taskOutcomeDraft.outcome,
                note: taskOutcomeDraft.note,
                didUpdateTaskStatus: taskOutcomeDraft.didUpdateTaskStatus,
                createdAt: now,
                updatedAt: now
            )
        }
        applyTaskOutcomeUpdates(taskOutcomes, at: now)
        let completedDebrief = draft.makeDebriefRecord(
            candidate: candidate,
            status: .completed,
            completedAt: now,
            noDebriefNeeded: false,
            captureIDs: captureIDs,
            taskOutcomes: taskOutcomes,
            preserving: existingDebrief
        )

        try debriefRepository.saveDebrief(
            completedDebrief,
            replacingDebriefWithID: existingDebrief?.id
        )
        cachedDebriefsByEventKey[candidate.eventKey] = completedDebrief
    }

    func skipDebrief(for candidate: CalendarDebriefCandidate) throws {
        let now = nowProvider()
        let existingDebrief = cachedDebriefsByEventKey[candidate.eventKey]
        let skippedDebrief = CalendarDebriefRecord(
            id: existingDebrief?.id ?? UUID(),
            eventKey: candidate.eventKey,
            eventIdentifier: candidate.eventIdentifier,
            calendarIdentifier: candidate.calendarIdentifier,
            calendarTitleSnapshot: candidate.calendarTitle,
            titleSnapshot: candidate.title,
            startDateSnapshot: candidate.start,
            endDateSnapshot: candidate.end,
            templateKind: existingDebrief?.templateKind ?? candidate.suggestedTemplate,
            createdAt: existingDebrief?.createdAt ?? now,
            updatedAt: now,
            completedAt: now,
            status: .skipped,
            noDebriefNeeded: true,
            essentialNote: existingDebrief?.essentialNote,
            createdCaptureIDs: existingDebrief?.createdCaptureIDs ?? [],
            taskOutcomes: existingDebrief?.taskOutcomes ?? []
        )

        try debriefRepository.saveDebrief(
            skippedDebrief,
            replacingDebriefWithID: existingDebrief?.id
        )
        cachedDebriefsByEventKey[candidate.eventKey] = skippedDebrief
    }

    private func enrichCandidates(_ candidates: [CalendarDebriefCandidate]) -> [CalendarDebriefCandidate] {
        let matcher = CalendarProjectMatcher()

        return candidates.map { candidate in
            var enrichedCandidate = candidate
            if let focus = focus(for: candidate) {
                enrichedCandidate.linkedProjectID = focus.linkedProjectID
                enrichedCandidate.selectedTaskCount = focus.selectedTaskCount
                if let projectID = focus.linkedProjectID {
                    enrichedCandidate.linkedProjectName = cachedProjectsByID[projectID]?.name
                }
                return enrichedCandidate
            }

            let matchResult = matcher.match(eventTitle: candidate.title, projects: Array(cachedProjectsByID.values))
            guard let projectID = matchResult.matchedProjectID else {
                return enrichedCandidate
            }

            enrichedCandidate.linkedProjectID = projectID
            enrichedCandidate.linkedProjectName = cachedProjectsByID[projectID]?.name
            return enrichedCandidate
        }
    }

    private func focus(for candidate: CalendarDebriefCandidate) -> CalendarBlockFocus? {
        guard
            let eventIdentifier = candidate.eventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            eventIdentifier.isEmpty == false,
            let calendarIdentifier = candidate.calendarIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            calendarIdentifier.isEmpty == false
        else {
            return nil
        }

        return cachedFocusesByEventLookupKey[Self.focusLookupKey(
            eventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier
        )]
    }

    private func applyTaskOutcomeUpdates(
        _ taskOutcomes: [DebriefTaskOutcome],
        at date: Date
    ) {
        for outcome in taskOutcomes where outcome.outcome == .completed && outcome.didUpdateTaskStatus {
            guard var task = try taskRepository.task(withID: outcome.taskID) else {
                continue
            }

            task.status = .done
            task.completedAt = date
            task.updatedAt = date
            try? taskRepository.saveTask(task, replacingTaskWithID: task.id)
        }
    }

    private static func focusLookupKey(
        eventIdentifier: String,
        calendarIdentifier: String
    ) -> String {
        "\(eventIdentifier.trimmingCharacters(in: .whitespacesAndNewlines))|\(calendarIdentifier.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}

struct DebriefListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DebriefQueueViewModel
    @State private var selectedCandidate: CalendarDebriefCandidate?

    let onChanged: () -> Void

    init(
        debriefRepository: any DebriefRepository,
        captureRepository: any CaptureRepository,
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        calendarBlockFocusRepository: any CalendarBlockFocusRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarReader: any CalendarReading,
        onChanged: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(
            wrappedValue: DebriefQueueViewModel(
                debriefRepository: debriefRepository,
                captureRepository: captureRepository,
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                calendarBlockFocusRepository: calendarBlockFocusRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarReader: calendarReader
            )
        )
        self.onChanged = onChanged
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.pendingCandidates.isEmpty ? "All caught up" : "\(viewModel.pendingCandidates.count) Debriefs waiting")
                        .font(.headline)
                    Text(viewModel.completedTodayCount > 0 ? "\(viewModel.completedTodayCount) loop\(viewModel.completedTodayCount == 1 ? "" : "s") closed today" : "Close the loop on meaningful events.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Debriefs pending") {
                if viewModel.pendingCandidates.isEmpty {
                    ContentUnavailableView(
                        "No Debriefs pending",
                        systemImage: "checkmark.circle",
                        description: Text("Recent ended calendar events are all processed.")
                    )
                } else {
                    ForEach(viewModel.pendingCandidates) { candidate in
                        Button {
                            selectedCandidate = candidate
                        } label: {
                            DebriefCandidateRow(candidate: candidate)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Debriefs")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedCandidate) { candidate in
            NavigationStack {
                DebriefFormView(
                    candidate: candidate,
                    initialDraft: viewModel.draft(for: candidate),
                    onComplete: { draft in
                        try viewModel.completeDebrief(for: candidate, draft: draft)
                        Task {
                            await viewModel.load()
                        }
                        onChanged()
                    },
                    onSkip: {
                        try viewModel.skipDebrief(for: candidate)
                        Task {
                            await viewModel.load()
                        }
                        onChanged()
                    }
                )
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .alert("Debriefs", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.clearError()
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

private struct DebriefCandidateRow: View {
    let candidate: CalendarDebriefCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(candidate.title)
                .font(.headline)

            Text(timeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var timeText: String {
        "\(candidate.start.formatted(date: .abbreviated, time: .shortened)) - \(candidate.end.formatted(date: .omitted, time: .shortened))"
    }

    private var subtitleText: String {
        var parts: [String] = [candidate.suggestedTemplate.displayName, candidate.calendarTitle]

        if let linkedProjectName = candidate.linkedProjectName {
            parts.insert(linkedProjectName, at: 0)
        }

        if candidate.selectedTaskCount > 0 {
            parts.append("\(candidate.selectedTaskCount) focus task\(candidate.selectedTaskCount == 1 ? "" : "s")")
        }

        return parts.joined(separator: " · ")
    }
}

private struct DebriefFormView: View {
    @Environment(\.dismiss) private var dismiss
    let candidate: CalendarDebriefCandidate
    let onComplete: (DebriefDraft) throws -> Void
    let onSkip: () throws -> Void

    @State private var draft: DebriefDraft
    @State private var captureInput = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        candidate: CalendarDebriefCandidate,
        initialDraft: DebriefDraft,
        onComplete: @escaping (DebriefDraft) throws -> Void,
        onSkip: @escaping () throws -> Void
    ) {
        self.candidate = candidate
        self.onComplete = onComplete
        self.onSkip = onSkip
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        Form {
            Section("Event") {
                Text(candidate.title)
                    .font(.headline)
                Text("\(candidate.start.formatted(date: .abbreviated, time: .shortened)) - \(candidate.end.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(candidate.calendarTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Template") {
                Picker("Debrief type", selection: $draft.templateKind) {
                    ForEach(DebriefTemplateKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            essentialSection

            Section {
                DisclosureGroup("More detail") {
                    optionalSectionBody
                }
            }

            if draft.taskOutcomeDrafts.isEmpty == false {
                Section("Tasks from this block") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach($draft.taskOutcomeDrafts) { $taskOutcomeDraft in
                            DebriefTaskOutcomeCard(
                                taskOutcomeDraft: $taskOutcomeDraft
                            )
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Capture from this event")
                        .font(.headline)
                    HStack {
                        TextField("Loose task, idea, promise, reminder...", text: $captureInput)
                        Button("Add") {
                            addCaptureLine()
                        }
                        .disabled(CaptureItem.cleanedTitle(from: captureInput) == nil)
                    }

                    if draft.captureLines.isEmpty == false {
                        ForEach(Array(draft.captureLines.enumerated()), id: \.offset) { index, line in
                            HStack {
                                Text(line)
                                    .font(.subheadline)
                                Spacer()
                                Button(role: .destructive) {
                                    draft.captureLines.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    completeDebrief()
                } label: {
                    Text(isSaving ? "Saving..." : "Complete Debrief")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Button("No Debrief needed") {
                    skipDebrief()
                }
                .frame(maxWidth: .infinity)
                .disabled(isSaving)
            }
        }
        .navigationTitle("Debrief")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Debrief", isPresented: Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var essentialSection: some View {
        switch draft.templateKind {
        case .workBlock:
            Section("Work Block") {
                Picker("Did you do what you planned?", selection: $draft.workPlannedOutcome) {
                    ForEach(WorkBlockPlannedOutcome.allCases) { outcome in
                        Text(outcome.displayName).tag(Optional(outcome))
                    }
                }

                DebriefRatingPicker(
                    title: "How productive did it feel?",
                    selection: $draft.workProductivityRating
                )

                TextField(
                    "What should future-you remember?",
                    text: $draft.workWhatHappened,
                    axis: .vertical
                )
            }
        case .meeting:
            Section("Meeting") {
                TextField(
                    "What were the main outcomes?",
                    text: $draft.meetingOutcomes,
                    axis: .vertical
                )
                TextField(
                    "Any follow-ups? One per line is fine.",
                    text: $draft.meetingFollowUps,
                    axis: .vertical
                )
                DebriefRatingPicker(
                    title: "How useful was this meeting?",
                    selection: $draft.meetingUsefulnessRating
                )
            }
        case .social:
            Section("Social") {
                TextField(
                    "Anything worth remembering?",
                    text: $draft.socialWorthRemembering,
                    axis: .vertical
                )
                TextField(
                    "Any follow-up?",
                    text: $draft.socialFollowUp,
                    axis: .vertical
                )
                Picker("How did it feel?", selection: $draft.socialMood) {
                    ForEach(SocialDebriefMood.allCases) { mood in
                        Text(mood.displayName).tag(Optional(mood))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var optionalSectionBody: some View {
        switch draft.templateKind {
        case .workBlock:
            workOptionalFields
        case .meeting:
            meetingOptionalFields
        case .social:
            socialOptionalFields
        }
    }

    private var workOptionalFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What got in the way?")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(WorkBlockBlocker.allCases) { blocker in
                    Button {
                        if draft.workBlockers.contains(blocker) {
                            draft.workBlockers.remove(blocker)
                        } else {
                            draft.workBlockers.insert(blocker)
                        }
                    } label: {
                        Text(blocker.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                draft.workBlockers.contains(blocker)
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.secondary.opacity(0.16),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("Was the block length right?", selection: $draft.workBlockLengthFit) {
                Text("Not set").tag(Optional<WorkBlockLengthFit>.none)
                ForEach(WorkBlockLengthFit.allCases) { value in
                    Text(value.displayName).tag(Optional(value))
                }
            }

            DebriefRatingPicker(title: "Energy before", selection: $draft.workEnergyBeforeRating)
            DebriefRatingPicker(title: "Energy after", selection: $draft.workEnergyAfterRating)
            DebriefRatingPicker(title: "Focus quality", selection: $draft.workFocusQualityRating)

            TextField("Next concrete step", text: $draft.workNextStep, axis: .vertical)
        }
    }

    private var meetingOptionalFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Decisions made", text: $draft.meetingDecisions, axis: .vertical)
            TextField("Open questions", text: $draft.meetingOpenQuestions, axis: .vertical)
            TextField("Deadlines mentioned", text: $draft.meetingDeadlines, axis: .vertical)
            DebriefRatingPicker(title: "Was I prepared enough?", selection: $draft.meetingPreparednessRating)
            TextField("People involved", text: $draft.meetingPeopleInvolved, axis: .vertical)
            TextField("Anything to remember before the next meeting?", text: $draft.meetingRememberBeforeNext, axis: .vertical)
        }
    }

    private var socialOptionalFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Who was there?", text: $draft.socialWhoWasThere, axis: .vertical)
            TextField("Anything I learned about someone?", text: $draft.socialLearnedAboutSomeone, axis: .vertical)
            TextField("Anything I promised?", text: $draft.socialPromised, axis: .vertical)
            TextField("Anything I want to do differently next time?", text: $draft.socialDifferentNextTime, axis: .vertical)
            Picker("Did this feel nourishing or obligatory?", selection: $draft.socialNourishment) {
                Text("Not set").tag(Optional<SocialDebriefNourishment>.none)
                ForEach(SocialDebriefNourishment.allCases) { value in
                    Text(value.displayName).tag(Optional(value))
                }
            }
        }
    }

    private func addCaptureLine() {
        guard let cleanedTitle = CaptureItem.cleanedTitle(from: captureInput) else {
            return
        }

        draft.captureLines.append(cleanedTitle)
        captureInput = ""
    }

    private func completeDebrief() {
        isSaving = true
        defer { isSaving = false }

        do {
            try onComplete(draft)
            dismiss()
        } catch {
            errorMessage = "Unable to complete Debrief: \(error.localizedDescription)"
        }
    }

    private func skipDebrief() {
        isSaving = true
        defer { isSaving = false }

        do {
            try onSkip()
            dismiss()
        } catch {
            errorMessage = "Unable to skip Debrief: \(error.localizedDescription)"
        }
    }
}

private struct DebriefRatingPicker: View {
    let title: String
    @Binding var selection: Int?

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Not set").tag(Optional<Int>.none)
            ForEach(1...5, id: \.self) { value in
                Text("\(value)").tag(Optional(value))
            }
        }
    }
}

private struct DebriefTaskOutcomeCard: View {
    @Binding var taskOutcomeDraft: DebriefTaskOutcomeDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(taskOutcomeDraft.taskTitleSnapshot)
                        .font(.subheadline.weight(.semibold))

                    if taskOutcomeDraft.isMissingTask {
                        Text("Task no longer exists")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("Mark task complete", isOn: $taskOutcomeDraft.didUpdateTaskStatus)
                    .disabled(taskOutcomeDraft.outcome != .completed)
                    .opacity(taskOutcomeDraft.outcome == .completed ? 1 : 0.45)
            }

            Picker("Outcome", selection: $taskOutcomeDraft.outcome) {
                ForEach(DebriefTaskOutcomeStatus.allCases) { outcome in
                    Text(outcome.displayName).tag(outcome)
                }
            }
            .onChange(of: taskOutcomeDraft.outcome) { _, newOutcome in
                if newOutcome == .completed {
                    taskOutcomeDraft.didUpdateTaskStatus = true
                } else if taskOutcomeDraft.didUpdateTaskStatus && newOutcome != .completed {
                    taskOutcomeDraft.didUpdateTaskStatus = false
                }
            }

            TextField(
                taskOutcomeDraft.notePlaceholder,
                text: $taskOutcomeDraft.note,
                axis: .vertical
            )
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DebriefDraft {
    var templateKind: DebriefTemplateKind

    var workPlannedOutcome: WorkBlockPlannedOutcome?
    var workProductivityRating: Int?
    var workWhatHappened: String
    var workBlockers: Set<WorkBlockBlocker>
    var workBlockLengthFit: WorkBlockLengthFit?
    var workEnergyBeforeRating: Int?
    var workEnergyAfterRating: Int?
    var workFocusQualityRating: Int?
    var workNextStep: String

    var meetingOutcomes: String
    var meetingFollowUps: String
    var meetingUsefulnessRating: Int?
    var meetingDecisions: String
    var meetingOpenQuestions: String
    var meetingDeadlines: String
    var meetingPreparednessRating: Int?
    var meetingPeopleInvolved: String
    var meetingRememberBeforeNext: String

    var socialWorthRemembering: String
    var socialFollowUp: String
    var socialMood: SocialDebriefMood?
    var socialWhoWasThere: String
    var socialLearnedAboutSomeone: String
    var socialPromised: String
    var socialDifferentNextTime: String
    var socialNourishment: SocialDebriefNourishment?

    var taskOutcomeDrafts: [DebriefTaskOutcomeDraft]
    var captureLines: [String]

    init(
        candidate: CalendarDebriefCandidate,
        existingDebrief: CalendarDebriefRecord?,
        blockFocus: CalendarBlockFocus? = nil,
        selectedTasks: [MyTask] = []
    ) {
        templateKind = existingDebrief?.templateKind ?? candidate.suggestedTemplate

        workPlannedOutcome = existingDebrief?.workPlannedOutcome
        workProductivityRating = existingDebrief?.workProductivityRating
        workWhatHappened = existingDebrief?.workWhatHappened ?? ""
        workBlockers = Set(existingDebrief?.workBlockers ?? [])
        workBlockLengthFit = existingDebrief?.workBlockLengthFit
        workEnergyBeforeRating = existingDebrief?.workEnergyBeforeRating
        workEnergyAfterRating = existingDebrief?.workEnergyAfterRating
        workFocusQualityRating = existingDebrief?.workFocusQualityRating
        workNextStep = existingDebrief?.workNextStep ?? ""

        meetingOutcomes = existingDebrief?.meetingOutcomes ?? ""
        meetingFollowUps = existingDebrief?.meetingFollowUps ?? ""
        meetingUsefulnessRating = existingDebrief?.meetingUsefulnessRating
        meetingDecisions = existingDebrief?.meetingDecisions ?? ""
        meetingOpenQuestions = existingDebrief?.meetingOpenQuestions ?? ""
        meetingDeadlines = existingDebrief?.meetingDeadlines ?? ""
        meetingPreparednessRating = existingDebrief?.meetingPreparednessRating
        meetingPeopleInvolved = existingDebrief?.meetingPeopleInvolved ?? ""
        meetingRememberBeforeNext = existingDebrief?.meetingRememberBeforeNext ?? ""

        socialWorthRemembering = existingDebrief?.socialWorthRemembering ?? ""
        socialFollowUp = existingDebrief?.socialFollowUp ?? ""
        socialMood = existingDebrief?.socialMood
        socialWhoWasThere = existingDebrief?.socialWhoWasThere ?? ""
        socialLearnedAboutSomeone = existingDebrief?.socialLearnedAboutSomeone ?? ""
        socialPromised = existingDebrief?.socialPromised ?? ""
        socialDifferentNextTime = existingDebrief?.socialDifferentNextTime ?? ""
        socialNourishment = existingDebrief?.socialNourishment

        taskOutcomeDrafts = Self.taskOutcomeDrafts(
            from: blockFocus,
            selectedTasks: selectedTasks,
            existingDebrief: existingDebrief
        )
        captureLines = []
    }

    func makeDebriefRecord(
        candidate: CalendarDebriefCandidate,
        status: CalendarDebriefStatus,
        completedAt: Date?,
        noDebriefNeeded: Bool,
        captureIDs: [UUID],
        taskOutcomes: [DebriefTaskOutcome],
        preserving existingDebrief: CalendarDebriefRecord?
    ) -> CalendarDebriefRecord {
        CalendarDebriefRecord(
            id: existingDebrief?.id ?? UUID(),
            eventKey: candidate.eventKey,
            eventIdentifier: candidate.eventIdentifier,
            calendarIdentifier: candidate.calendarIdentifier,
            calendarTitleSnapshot: candidate.calendarTitle,
            titleSnapshot: candidate.title,
            startDateSnapshot: candidate.start,
            endDateSnapshot: candidate.end,
            templateKind: templateKind,
            createdAt: existingDebrief?.createdAt ?? Date(),
            updatedAt: Date(),
            completedAt: completedAt,
            status: status,
            noDebriefNeeded: noDebriefNeeded,
            essentialNote: essentialNote,
            createdCaptureIDs: (existingDebrief?.createdCaptureIDs ?? []) + captureIDs,
            workPlannedOutcome: workPlannedOutcome,
            workProductivityRating: workProductivityRating,
            workWhatHappened: workWhatHappened,
            workBlockers: Array(workBlockers),
            workBlockLengthFit: workBlockLengthFit,
            workEnergyBeforeRating: workEnergyBeforeRating,
            workEnergyAfterRating: workEnergyAfterRating,
            workFocusQualityRating: workFocusQualityRating,
            workNextStep: workNextStep,
            meetingOutcomes: meetingOutcomes,
            meetingFollowUps: meetingFollowUps,
            meetingUsefulnessRating: meetingUsefulnessRating,
            meetingDecisions: meetingDecisions,
            meetingOpenQuestions: meetingOpenQuestions,
            meetingDeadlines: meetingDeadlines,
            meetingPreparednessRating: meetingPreparednessRating,
            meetingPeopleInvolved: meetingPeopleInvolved,
            meetingRememberBeforeNext: meetingRememberBeforeNext,
            socialWorthRemembering: socialWorthRemembering,
            socialFollowUp: socialFollowUp,
            socialMood: socialMood,
            socialWhoWasThere: socialWhoWasThere,
            socialLearnedAboutSomeone: socialLearnedAboutSomeone,
            socialPromised: socialPromised,
            socialDifferentNextTime: socialDifferentNextTime,
            socialNourishment: socialNourishment,
            taskOutcomes: taskOutcomes
        )
    }

    private var essentialNote: String? {
        switch templateKind {
        case .workBlock:
            return workWhatHappened
        case .meeting:
            return meetingOutcomes
        case .social:
            return socialWorthRemembering
        }
    }

    private static func taskOutcomeDrafts(
        from blockFocus: CalendarBlockFocus?,
        selectedTasks: [MyTask],
        existingDebrief: CalendarDebriefRecord?
    ) -> [DebriefTaskOutcomeDraft] {
        guard let blockFocus, blockFocus.selectedTaskIDs.isEmpty == false else {
            return existingDebrief?.taskOutcomes.map { taskOutcome in
                DebriefTaskOutcomeDraft(
                    taskID: taskOutcome.taskID,
                    taskTitleSnapshot: taskOutcome.taskTitleSnapshot,
                    outcome: taskOutcome.outcome,
                    note: taskOutcome.note ?? "",
                    didUpdateTaskStatus: taskOutcome.didUpdateTaskStatus,
                    isMissingTask: false
                )
            } ?? []
        }

        let selectedTaskLookup = Dictionary(uniqueKeysWithValues: selectedTasks.map { ($0.id, $0) })
        let existingOutcomeLookup = Dictionary(uniqueKeysWithValues: existingDebrief?.taskOutcomes.map {
            ($0.taskID, $0)
        } ?? [])

        return blockFocus.selectedTaskIDs.map { taskID in
            if let task = selectedTaskLookup[taskID] {
                let existingOutcome = existingOutcomeLookup[taskID]
                return DebriefTaskOutcomeDraft(
                    taskID: task.id,
                    taskTitleSnapshot: task.title,
                    outcome: existingOutcome?.outcome ?? .notTouched,
                    note: existingOutcome?.note ?? "",
                    didUpdateTaskStatus: existingOutcome?.didUpdateTaskStatus ?? false,
                    isMissingTask: false
                )
            }

            let existingOutcome = existingOutcomeLookup[taskID]
            return DebriefTaskOutcomeDraft(
                taskID: taskID,
                taskTitleSnapshot: existingOutcome?.taskTitleSnapshot ?? "Deleted task",
                outcome: existingOutcome?.outcome ?? .notTouched,
                note: existingOutcome?.note ?? "",
                didUpdateTaskStatus: existingOutcome?.didUpdateTaskStatus ?? false,
                isMissingTask: true
            )
        }
    }
}

private struct DebriefTaskOutcomeDraft: Identifiable, Equatable, Sendable {
    let taskID: UUID
    var taskTitleSnapshot: String
    var outcome: DebriefTaskOutcomeStatus
    var note: String
    var didUpdateTaskStatus: Bool
    var isMissingTask: Bool

    var id: UUID {
        taskID
    }

    var notePlaceholder: String {
        switch outcome {
        case .completed:
            return "What got finished?"
        case .partlyDone:
            return "What changed?"
        case .stillOpen:
            return "What remains?"
        case .blocked:
            return "Why blocked?"
        case .notTouched:
            return "What happened instead?"
        }
    }
}
