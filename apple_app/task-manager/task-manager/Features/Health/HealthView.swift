import SwiftUI

struct HealthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: HealthViewModel
    @State private var mode: HealthViewMode = .today
    @State private var presentedSheet: HealthSheet?

    private let onChange: () -> Void

    init(
        healthRepository: any HealthRepository,
        onChange: @escaping () -> Void = {}
    ) {
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: HealthViewModel(healthRepository: healthRepository)
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Health View", selection: $mode) {
                ForEach(HealthViewMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            content
        }
        .navigationTitle("Health")
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .sleepCheckIn:
                    SleepCheckInFormView(initialCheckIn: viewModel.todaysSleepCheckIn) { checkIn in
                        viewModel.saveSleepCheckIn(
                            checkIn,
                            replacingCheckInWithID: viewModel.todaysSleepCheckIn?.id
                        )
                        onChange()
                        presentedSheet = nil
                    }
                case .mealLog(let log):
                    MealLogFormView(initialLog: log) { savedLog in
                        viewModel.saveMealLog(savedLog, replacingLogWithID: log?.id)
                        onChange()
                        presentedSheet = nil
                    }
                case .workoutLog(let log):
                    WorkoutLogFormView(initialLog: log) { savedLog in
                        viewModel.saveWorkoutLog(savedLog, replacingLogWithID: log?.id)
                        onChange()
                        presentedSheet = nil
                    }
                case .pvtTest:
                    PVTTestView { session in
                        viewModel.savePVTSession(session)
                        onChange()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .today:
            todayContent
        case .meals:
            mealContent
        case .workouts:
            workoutContent
        case .trends:
            trendsContent
        }
    }

    private var todayContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HealthSummaryCard(
                    title: "Morning Check-in",
                    systemImage: "bed.double.fill",
                    summary: viewModel.sleepStatusSummary,
                    actionTitle: viewModel.todaysSleepCheckIn == nil ? "Check In" : "Update"
                ) {
                    presentedSheet = .sleepCheckIn
                }

                HStack(spacing: 12) {
                    HealthQuickActionCard(
                        title: "Meal",
                        systemImage: "fork.knife",
                        value: viewModel.mealsTodaySummary
                    ) {
                        presentedSheet = .mealLog(nil)
                    }

                    HealthQuickActionCard(
                        title: "Workout",
                        systemImage: "figure.strengthtraining.traditional",
                        value: viewModel.workoutsTodaySummary
                    ) {
                        presentedSheet = .workoutLog(nil)
                    }
                }

                HealthSummaryCard(
                    title: "PVT Test",
                    systemImage: "timer",
                    summary: viewModel.pvtStatusSummary,
                    actionTitle: "Start"
                ) {
                    presentedSheet = .pvtTest
                }

                if viewModel.todaysMealLogs.isEmpty == false {
                    healthSection("Meals Today") {
                        ForEach(viewModel.todaysMealLogs) { log in
                            MealLogRow(log: log)
                        }
                    }
                }

                if viewModel.todaysWorkoutLogs.isEmpty == false {
                    healthSection("Workouts Today") {
                        ForEach(viewModel.todaysWorkoutLogs) { log in
                            WorkoutLogRow(log: log)
                        }
                    }
                }

                if viewModel.todaysPVTSessions.isEmpty == false {
                    healthSection("PVT Today") {
                        ForEach(viewModel.todaysPVTSessions) { session in
                            PVTSessionRow(session: session)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var mealContent: some View {
        Group {
            if viewModel.recentMealLogs.isEmpty {
                ContentUnavailableView(
                    "No Meal Logs",
                    systemImage: "fork.knife",
                    description: Text("Log lightweight meal context when food seems relevant to energy or planning.")
                )
            } else {
                List {
                    ForEach(viewModel.recentMealLogs) { log in
                        MealLogRow(log: log)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                presentedSheet = .mealLog(log)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteMealLog(withID: log.id)
                                    onChange()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom) {
            addButton("Log Meal", systemImage: "plus.circle.fill") {
                presentedSheet = .mealLog(nil)
            }
        }
    }

    private var workoutContent: some View {
        Group {
            if viewModel.recentWorkoutLogs.isEmpty {
                ContentUnavailableView(
                    "No Workout Logs",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Log what happened after a workout, without turning routines into records.")
                )
            } else {
                List {
                    ForEach(viewModel.recentWorkoutLogs) { log in
                        WorkoutLogRow(log: log)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                presentedSheet = .workoutLog(log)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteWorkoutLog(withID: log.id)
                                    onChange()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom) {
            addButton("Log Workout", systemImage: "plus.circle.fill") {
                presentedSheet = .workoutLog(nil)
            }
        }
    }

    private var trendsContent: some View {
        let trends = viewModel.trendSummary

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TrendSummaryCard(
                    title: "Sleep / PVT",
                    systemImage: "bed.double.fill",
                    rows: [
                        TrendMetricRowData(
                            label: "Sleep logged",
                            value: "\(trends.sleepPVT.current7Days.daysLogged) days",
                            detail: "30-day: \(trends.sleepPVT.current30Days.daysLogged) days"
                        ),
                        TrendMetricRowData(
                            label: "Sleep duration",
                            value: formattedMinutesAverage(trends.sleepPVT.current7Days.averageSleepDurationMinutes),
                            detail: "7-day average"
                        ),
                        TrendMetricRowData(
                            label: "Sleep quality",
                            value: formattedRatingAverage(trends.sleepPVT.current7Days.averageSleepQualityRating),
                            detail: "7-day average"
                        ),
                        TrendMetricRowData(
                            label: "Energy",
                            value: formattedRatingAverage(trends.sleepPVT.current7Days.averageEnergyRating),
                            detail: "7-day average"
                        ),
                        TrendMetricRowData(
                            label: "PVT median",
                            value: formattedMillisecondsAverage(trends.sleepPVT.current7Days.averagePVTMedianMilliseconds),
                            detail: "Previous 7 days: \(formattedMillisecondsAverage(trends.sleepPVT.previous7Days.averagePVTMedianMilliseconds))"
                        ),
                        TrendMetricRowData(
                            label: "PVT lapses",
                            value: formattedCountAverage(trends.sleepPVT.current7Days.averagePVTLapseCount),
                            detail: "\(trends.sleepPVT.current7Days.pvtDaysLogged) PVT days logged"
                        ),
                    ]
                )

                TrendSummaryCard(
                    title: "Nutrition",
                    systemImage: "fork.knife",
                    rows: [
                        TrendMetricRowData(
                            label: "Meals logged",
                            value: "\(trends.nutrition.current7Days.mealCount)",
                            detail: "30-day: \(trends.nutrition.current30Days.mealCount)"
                        ),
                        TrendMetricRowData(
                            label: "Meal mix",
                            value: topCountText(trends.nutrition.current7Days.mealTypeCounts),
                            detail: "7-day counts"
                        ),
                        TrendMetricRowData(
                            label: "Common tags",
                            value: topCountText(trends.nutrition.current30Days.tagCounts),
                            detail: "30-day counts"
                        ),
                        TrendMetricRowData(
                            label: "Energy after",
                            value: formattedRatingAverage(trends.nutrition.current7Days.averageEnergyAfterRating),
                            detail: "7-day average"
                        ),
                    ]
                )

                TrendSummaryCard(
                    title: "Workouts",
                    systemImage: "figure.strengthtraining.traditional",
                    rows: [
                        TrendMetricRowData(
                            label: "Workouts logged",
                            value: "\(trends.workouts.current7Days.workoutCount)",
                            detail: "30-day: \(trends.workouts.current30Days.workoutCount)"
                        ),
                        TrendMetricRowData(
                            label: "Duration",
                            value: formattedMinutesTotal(trends.workouts.current7Days.totalDurationMinutes),
                            detail: "7-day total"
                        ),
                        TrendMetricRowData(
                            label: "Workout mix",
                            value: topCountText(trends.workouts.current7Days.workoutTypeCounts),
                            detail: "7-day counts"
                        ),
                        TrendMetricRowData(
                            label: "Intensity",
                            value: formattedRatingAverage(trends.workouts.current7Days.averageIntensityRating),
                            detail: "7-day average"
                        ),
                        TrendMetricRowData(
                            label: "Energy change",
                            value: formattedSignedAverage(trends.workouts.current7Days.averageEnergyDelta),
                            detail: "After minus before"
                        ),
                    ]
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func addButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .background(.regularMaterial)
    }

    private func healthSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func formattedMinutesAverage(_ value: Double?) -> String {
        guard let value else {
            return "not enough data yet"
        }

        let hours = Int(value) / 60
        let minutes = Int(value.rounded()) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func formattedMinutesTotal(_ value: Int) -> String {
        guard value > 0 else {
            return "not enough data yet"
        }

        let hours = value / 60
        let minutes = value % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func formattedRatingAverage(_ value: Double?) -> String {
        guard let value else {
            return "not enough data yet"
        }

        return "\(formattedDecimal(value))/5"
    }

    private func formattedMillisecondsAverage(_ value: Double?) -> String {
        guard let value else {
            return "not enough data yet"
        }

        return "\(Int(value.rounded()))ms"
    }

    private func formattedCountAverage(_ value: Double?) -> String {
        guard let value else {
            return "not enough data yet"
        }

        return formattedDecimal(value)
    }

    private func formattedSignedAverage(_ value: Double?) -> String {
        guard let value else {
            return "not enough data yet"
        }

        let formattedValue = formattedDecimal(abs(value))
        if value > 0 {
            return "+\(formattedValue)"
        }

        if value < 0 {
            return "-\(formattedValue)"
        }

        return "0"
    }

    private func formattedDecimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }

        return "\(rounded)"
    }

    private func topCountText<T: HealthDisplayNamed>(_ counts: [T: Int]) -> String {
        let topCounts = counts
            .sorted { left, right in
                if left.value != right.value {
                    return left.value > right.value
                }

                return left.key.displayName < right.key.displayName
            }
            .prefix(2)

        guard topCounts.isEmpty == false else {
            return "not enough data yet"
        }

        return topCounts
            .map { "\($0.key.displayName) \($0.value)" }
            .joined(separator: ", ")
    }
}

private enum HealthViewMode: String, CaseIterable, Identifiable {
    case today
    case meals
    case workouts
    case trends

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today:
            return "Today"
        case .meals:
            return "Meals"
        case .workouts:
            return "Workouts"
        case .trends:
            return "Trends"
        }
    }
}

private enum HealthSheet: Identifiable {
    case sleepCheckIn
    case mealLog(MealLog?)
    case workoutLog(WorkoutLog?)
    case pvtTest

    var id: String {
        switch self {
        case .sleepCheckIn:
            return "sleepCheckIn"
        case .mealLog(let log):
            return "mealLog-\(log?.id.uuidString ?? "new")"
        case .workoutLog(let log):
            return "workoutLog-\(log?.id.uuidString ?? "new")"
        case .pvtTest:
            return "pvtTest"
        }
    }
}

private protocol HealthDisplayNamed: Hashable {
    var displayName: String { get }
}

extension MealType: HealthDisplayNamed {}
extension MealTag: HealthDisplayNamed {}
extension WorkoutType: HealthDisplayNamed {}

private struct HealthSummaryCard: View {
    let title: String
    let systemImage: String
    let summary: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(actionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct HealthQuickActionCard: View {
    let title: String
    let systemImage: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct HealthPlannedCard: View {
    let title: String
    let systemImage: String
    let summary: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MealLogRow: View {
    let log: MealLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.summary)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label(log.mealType.displayName, systemImage: "fork.knife")
                if let energy = log.energyAfterRating {
                    Label("Energy \(energy)/5", systemImage: "bolt.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if log.tags.isEmpty == false {
                Text(log.tags.map(\.displayName).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WorkoutLogRow: View {
    let log: WorkoutLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.workoutType.displayName)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if let duration = log.durationMinutes {
                    Label("\(duration)m", systemImage: "clock")
                }
                if let intensity = log.intensityRating {
                    Label("Intensity \(intensity)/5", systemImage: "speedometer")
                }
                if let energy = log.energyAfterRating {
                    Label("Energy \(energy)/5", systemImage: "bolt.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let notes = log.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PVTSessionRow: View {
    let session: PVTSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PVT Session")
                    .font(.body.weight(.semibold))
                Spacer()
                Text(session.startedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if let median = session.medianReactionMilliseconds {
                    Label("Median \(Int(median.rounded()))ms", systemImage: "timer")
                }
                Label("\(session.lapseCount) lapses", systemImage: "gauge")
                if session.missCount > 0 {
                    Label("\(session.missCount) misses", systemImage: "circle.dashed")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct TrendMetricRowData: Identifiable {
    let label: String
    let value: String
    let detail: String

    var id: String {
        label
    }
}

private struct TrendSummaryCard: View {
    let title: String
    let systemImage: String
    let rows: [TrendMetricRowData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(rows) { row in
                    TrendMetricRow(row: row)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TrendMetricRow: View {
    let row: TrendMetricRowData

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .font(.subheadline.weight(.semibold))
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(row.value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SleepCheckInFormView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (SleepCheckIn) -> Void

    @State private var durationText: String
    @State private var sleepQualityRating: Int?
    @State private var tirednessRating: Int?
    @State private var energyRating: Int?
    @State private var selectedTags: Set<HealthContextTag>
    @State private var notes: String
    private let initialCheckIn: SleepCheckIn?

    init(initialCheckIn: SleepCheckIn?, onSave: @escaping (SleepCheckIn) -> Void) {
        self.initialCheckIn = initialCheckIn
        self.onSave = onSave
        _durationText = State(initialValue: initialCheckIn?.sleepDurationMinutes.map(String.init) ?? "")
        _sleepQualityRating = State(initialValue: initialCheckIn?.sleepQualityRating)
        _tirednessRating = State(initialValue: initialCheckIn?.tirednessRating)
        _energyRating = State(initialValue: initialCheckIn?.energyRating)
        _selectedTags = State(initialValue: Set(initialCheckIn?.contextTags ?? []))
        _notes = State(initialValue: initialCheckIn?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Sleep") {
                TextField("Duration minutes", text: $durationText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                RatingPicker(title: "Sleep Quality", rating: $sleepQualityRating)
                RatingPicker(title: "Tiredness", rating: $tirednessRating)
                RatingPicker(title: "Energy", rating: $energyRating)
            }

            Section("Context") {
                ForEach(HealthContextTag.allCases, id: \.self) { tag in
                    Toggle(tag.displayName, isOn: binding(for: tag))
                }
            }

            Section("Notes") {
                TextField("Optional note", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Sleep Check-in")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        SleepCheckIn(
                            id: initialCheckIn?.id ?? UUID(),
                            day: Date(),
                            sleepDurationMinutes: Int(durationText),
                            sleepQualityRating: sleepQualityRating,
                            tirednessRating: tirednessRating,
                            energyRating: energyRating,
                            contextTags: Array(selectedTags),
                            notes: notes,
                            createdAt: initialCheckIn?.createdAt ?? Date(),
                            updatedAt: Date()
                        )
                    )
                }
            }
        }
    }

    private func binding(for tag: HealthContextTag) -> Binding<Bool> {
        Binding {
            selectedTags.contains(tag)
        } set: { isSelected in
            if isSelected {
                selectedTags.insert(tag)
            } else {
                selectedTags.remove(tag)
            }
        }
    }
}

private struct MealLogFormView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MealLog) -> Void

    @State private var timestamp: Date
    @State private var mealType: MealType
    @State private var summary: String
    @State private var selectedTags: Set<MealTag>
    @State private var energyAfterRating: Int?
    @State private var notes: String
    private let initialLog: MealLog?

    init(initialLog: MealLog?, onSave: @escaping (MealLog) -> Void) {
        self.initialLog = initialLog
        self.onSave = onSave
        _timestamp = State(initialValue: initialLog?.timestamp ?? Date())
        _mealType = State(initialValue: initialLog?.mealType ?? .other)
        _summary = State(initialValue: initialLog?.summary ?? "")
        _selectedTags = State(initialValue: Set(initialLog?.tags ?? []))
        _energyAfterRating = State(initialValue: initialLog?.energyAfterRating)
        _notes = State(initialValue: initialLog?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Meal") {
                DatePicker("Time", selection: $timestamp)
                Picker("Type", selection: $mealType) {
                    ForEach(MealType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("Summary", text: $summary)
                RatingPicker(title: "Energy After", rating: $energyAfterRating)
            }

            Section("Tags") {
                ForEach(MealTag.allCases, id: \.self) { tag in
                    Toggle(tag.displayName, isOn: binding(for: tag))
                }
            }

            Section("Notes") {
                TextField("Optional note", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle(initialLog == nil ? "Log Meal" : "Edit Meal")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        MealLog(
                            id: initialLog?.id ?? UUID(),
                            timestamp: timestamp,
                            mealType: mealType,
                            summary: summary,
                            tags: Array(selectedTags),
                            energyAfterRating: energyAfterRating,
                            notes: notes,
                            createdAt: initialLog?.createdAt ?? timestamp,
                            updatedAt: Date()
                        )
                    )
                }
                .disabled(MealLog.cleanedSummary(from: summary) == nil)
            }
        }
    }

    private func binding(for tag: MealTag) -> Binding<Bool> {
        Binding {
            selectedTags.contains(tag)
        } set: { isSelected in
            if isSelected {
                selectedTags.insert(tag)
            } else {
                selectedTags.remove(tag)
            }
        }
    }
}

private struct WorkoutLogFormView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (WorkoutLog) -> Void

    @State private var timestamp: Date
    @State private var workoutType: WorkoutType
    @State private var durationText: String
    @State private var intensityRating: Int?
    @State private var energyBeforeRating: Int?
    @State private var energyAfterRating: Int?
    @State private var notes: String
    private let initialLog: WorkoutLog?

    init(initialLog: WorkoutLog?, onSave: @escaping (WorkoutLog) -> Void) {
        self.initialLog = initialLog
        self.onSave = onSave
        _timestamp = State(initialValue: initialLog?.timestamp ?? Date())
        _workoutType = State(initialValue: initialLog?.workoutType ?? .other)
        _durationText = State(initialValue: initialLog?.durationMinutes.map(String.init) ?? "")
        _intensityRating = State(initialValue: initialLog?.intensityRating)
        _energyBeforeRating = State(initialValue: initialLog?.energyBeforeRating)
        _energyAfterRating = State(initialValue: initialLog?.energyAfterRating)
        _notes = State(initialValue: initialLog?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Workout") {
                DatePicker("Time", selection: $timestamp)
                Picker("Type", selection: $workoutType) {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("Duration minutes", text: $durationText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                RatingPicker(title: "Intensity", rating: $intensityRating)
                RatingPicker(title: "Energy Before", rating: $energyBeforeRating)
                RatingPicker(title: "Energy After", rating: $energyAfterRating)
            }

            Section("Notes") {
                TextField("Optional note", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle(initialLog == nil ? "Log Workout" : "Edit Workout")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        WorkoutLog(
                            id: initialLog?.id ?? UUID(),
                            timestamp: timestamp,
                            workoutType: workoutType,
                            durationMinutes: Int(durationText),
                            intensityRating: intensityRating,
                            energyBeforeRating: energyBeforeRating,
                            energyAfterRating: energyAfterRating,
                            notes: notes,
                            createdAt: initialLog?.createdAt ?? timestamp,
                            updatedAt: Date()
                        )
                    )
                }
            }
        }
    }
}

private enum PVTTestPhase {
    case idle
    case waiting
    case stimulus
    case complete
}

private struct PVTTestView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: (PVTSession) -> Void

    @State private var phase: PVTTestPhase = .idle
    @State private var startedAt: Date?
    @State private var stimulusAt: Date?
    @State private var reactionTimesMilliseconds: [Int] = []
    @State private var falseStartCount = 0
    @State private var missCount = 0
    @State private var completedSession: PVTSession?
    @State private var didSaveCompletedSession = false
    @State private var runTask: Task<Void, Never>?

    private let durationSeconds = 60
    private let stimulusTimeoutSeconds = 4.0

    var body: some View {
        VStack(spacing: 18) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 6) {
                    Text(titleText)
                        .font(.headline)
                    Text(remainingText(at: context.date))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                if phase == .idle || phase == .complete {
                    startTest()
                } else {
                    recordTap()
                }
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: actionSystemImage)
                        .font(.largeTitle)
                    Text(actionTitle)
                        .font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(actionBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                PVTMetricTile(title: "Responses", value: "\(reactionTimesMilliseconds.count)")
                PVTMetricTile(title: "False Starts", value: "\(falseStartCount)")
                PVTMetricTile(title: "Misses", value: "\(missCount)")
            }

            if let completedSession {
                VStack(spacing: 6) {
                    if let median = completedSession.medianReactionMilliseconds {
                        Text("Median \(Int(median.rounded()))ms")
                            .font(.headline.monospacedDigit())
                    }
                    Text(didSaveCompletedSession ? "Saved" : "Complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer()
        }
        .padding()
        .navigationTitle("PVT Test")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(phase == .complete ? "Done" : "Cancel") {
                    cancelRunningTest()
                    dismiss()
                }
            }
        }
        .onDisappear {
            cancelRunningTest()
        }
    }

    private var titleText: String {
        switch phase {
        case .idle:
            return "1-minute PVT"
        case .waiting:
            return "Wait"
        case .stimulus:
            return "Tap"
        case .complete:
            return "Complete"
        }
    }

    private var actionTitle: String {
        switch phase {
        case .idle:
            return "Start"
        case .waiting:
            return "Wait"
        case .stimulus:
            return "Tap"
        case .complete:
            return "Start Again"
        }
    }

    private var actionSystemImage: String {
        switch phase {
        case .idle, .complete:
            return "timer"
        case .waiting:
            return "circle"
        case .stimulus:
            return "largecircle.fill.circle"
        }
    }

    private var actionBackground: some ShapeStyle {
        phase == .stimulus ? Color.blue.opacity(0.22) : Color.primary.opacity(0.04)
    }

    private func remainingText(at date: Date) -> String {
        guard let startedAt, phase != .idle else {
            return "\(durationSeconds)s"
        }

        if phase == .complete {
            return "0s"
        }

        let elapsedSeconds = Int(date.timeIntervalSince(startedAt).rounded(.down))
        return "\(max(0, durationSeconds - elapsedSeconds))s"
    }

    private func startTest() {
        let startDate = Date()
        cancelRunningTest()
        startedAt = startDate
        stimulusAt = nil
        reactionTimesMilliseconds = []
        falseStartCount = 0
        missCount = 0
        completedSession = nil
        didSaveCompletedSession = false
        phase = .waiting

        runTask = Task {
            await runTest(startDate: startDate)
        }
    }

    private func runTest(startDate: Date) async {
        while Task.isCancelled == false,
              Date().timeIntervalSince(startDate) < Double(durationSeconds) {
            let waitSeconds = Double.random(in: 2...5)
            try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
            guard Task.isCancelled == false else {
                return
            }

            guard Date().timeIntervalSince(startDate) < Double(durationSeconds) else {
                break
            }

            await MainActor.run {
                guard phase == .waiting else {
                    return
                }

                stimulusAt = Date()
                phase = .stimulus
            }

            try? await Task.sleep(nanoseconds: UInt64(stimulusTimeoutSeconds * 1_000_000_000))
            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                if phase == .stimulus {
                    missCount += 1
                    stimulusAt = nil
                    phase = .waiting
                }
            }
        }

        await MainActor.run {
            completeTest()
        }
    }

    private func recordTap() {
        switch phase {
        case .waiting:
            falseStartCount += 1
        case .stimulus:
            guard let stimulusAt else {
                return
            }

            let milliseconds = max(0, Int(Date().timeIntervalSince(stimulusAt) * 1_000))
            reactionTimesMilliseconds.append(milliseconds)
            self.stimulusAt = nil
            phase = .waiting
        case .idle, .complete:
            break
        }
    }

    private func completeTest() {
        guard phase != .complete else {
            return
        }

        let now = Date()
        let session = PVTSession(
            startedAt: startedAt ?? now,
            durationSeconds: durationSeconds,
            reactionTimesMilliseconds: reactionTimesMilliseconds,
            falseStartCount: falseStartCount,
            missCount: missCount,
            createdAt: startedAt ?? now,
            updatedAt: now
        )
        completedSession = session
        phase = .complete
        stimulusAt = nil
        runTask = nil
        onComplete(session)
        didSaveCompletedSession = true
    }

    private func cancelRunningTest() {
        runTask?.cancel()
        runTask = nil
        if phase == .waiting || phase == .stimulus {
            phase = .idle
            startedAt = nil
            stimulusAt = nil
        }
    }
}

private struct PVTMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct RatingPicker: View {
    let title: String
    @Binding var rating: Int?

    var body: some View {
        Picker(title, selection: $rating) {
            Text("None").tag(Optional<Int>.none)
            ForEach(1...5, id: \.self) { value in
                Text("\(value)").tag(Optional(value))
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthView(
            healthRepository: SwiftDataHealthRepository(
                modelContainer: AppContainer.makePreview().modelContainer
            )
        )
    }
}
