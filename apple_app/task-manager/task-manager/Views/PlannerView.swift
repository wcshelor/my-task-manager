import SwiftUI
#if os(iOS)
import UIKit
#endif

private enum PlannerCalendarDisplayMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }

    var navigationTitle: String {
        switch self {
        case .day:
            return "Day"
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }
}

struct PlannerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel: PlannerViewModel
    private let promiseRepository: (any PromiseRepository)?
    private let navigationTitle: String
    @State private var calendarDisplayMode: PlannerCalendarDisplayMode = .day
    @State private var isHorizonPlanSheetPresented = false
    @State private var isCalendarSetupSheetPresented = false
    @State private var scheduledBlockEditDraft: PlannerScheduledBlockEditDraft?
    @State private var scheduledBlockAlert: PlannerScheduledBlockAlert?

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
        promiseRepository: (any PromiseRepository)? = nil,
        navigationTitle: String = "Calendar"
    ) {
        self.promiseRepository = promiseRepository
        self.navigationTitle = navigationTitle
        _viewModel = StateObject(
            wrappedValue: PlannerViewModel(
                taskRepository: taskRepository,
                scheduledBlockRepository: scheduledBlockRepository,
                settingsRepository: settingsRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarListingService: calendarListingService,
                calendarReader: calendarReader,
                calendarWriter: calendarWriter,
                calendarReconciler: calendarReconciler,
                calendarChangeObserver: calendarChangeObserver
            )
        )
    }

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Picker("Calendar View", selection: $calendarDisplayMode) {
                    ForEach(PlannerCalendarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, isCompactWidth ? 16 : 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if let promiseRepository {
                    PromisePresenceBanner(promiseRepository: promiseRepository)
                        .padding(.horizontal, isCompactWidth ? 16 : 20)
                        .padding(.bottom, 12)
                }

                PlannerDayNavigationCard(
                    selectedDay: viewModel.selectedDay,
                    title: calendarDisplayMode.navigationTitle,
                    onPreviousDay: {
                        Task {
                            await moveCalendarBackward()
                        }
                    },
                    onToday: {
                        Task {
                            await viewModel.goToToday()
                        }
                    },
                    onNextDay: {
                        Task {
                            await moveCalendarForward()
                        }
                    }
                )
                .padding(.horizontal, isCompactWidth ? 16 : 20)
                .padding(.bottom, 12)

                PlannerMorningBriefCard(
                    brief: viewModel.morningBrief,
                    selectedEnergy: viewModel.morningEnergy,
                    onSelectEnergy: { energy in
                        viewModel.setMorningEnergy(energy)
                    },
                    onAction: handleMorningBriefAction
                )
                .padding(.horizontal, isCompactWidth ? 16 : 20)
                .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 8) {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let reconciliationNotice = viewModel.reconciliationNotice {
                        Text(reconciliationNotice)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, isCompactWidth ? 16 : 20)

                plannerContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)

                    Menu {
                        Button("Plan by Horizon") {
                            isHorizonPlanSheetPresented = true
                        }

                        if viewModel.permissionStatus == .fullAccessGranted {
                            Button("Calendar Setup") {
                                isCalendarSetupSheetPresented = true
                            }
                        }

                        if viewModel.permissionStatus != .fullAccessGranted,
                           viewModel.permissionStatus != .notDetermined {
                            Button("Grant Calendar Access") {
                                Task {
                                    await viewModel.requestCalendarAccess()
                                }
                            }
                        }
                    } label: {
                        Label("Calendar Options", systemImage: "ellipsis.circle")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let selectedTimeRange = viewModel.selectedTimeRange {
                    PlannerSelectedSlotActionBar(
                        selectedTimeRange: selectedTimeRange,
                        hasGeneratedSuggestions: viewModel.hasGeneratedSuggestionsForSelectedTimeRange,
                        suggestionCount: viewModel.selectedSlotSuggestionItems.count,
                        isLoading: viewModel.isLoading,
                        canGenerate: viewModel.permissionStatus == .fullAccessGranted,
                        onGenerateSuggestions: {
                            Task {
                                await viewModel.generatePlanForSelectedTimeRange()
                            }
                        },
                        onClearSelection: {
                            viewModel.clearSelectedTimeRange()
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $isHorizonPlanSheetPresented) {
            HorizonPlanSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isCalendarSetupSheetPresented) {
            NavigationStack {
                PlannerCalendarSetupCard(
                    writableCalendars: viewModel.writableCalendars,
                    selectedWriteCalendarIdentifier: viewModel.selectedWriteCalendarIdentifier,
                    selectedWriteCalendarTitle: viewModel.selectedWriteCalendarTitle,
                    onSelectWriteCalendar: { calendarID in
                        viewModel.selectWriteCalendar(withID: calendarID)
                    }
                )
                .padding()
                .navigationTitle("Calendar Setup")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isCalendarSetupSheetPresented = false
                        }
                    }
                }
            }
        }
        .sheet(item: $scheduledBlockEditDraft) { draft in
            PlannerScheduledBlockEditSheet(
                draft: draft,
                isSaving: viewModel.activeScheduledBlockOperationIDs.contains(draft.blockID),
                onSave: { updatedDraft in
                    scheduledBlockEditDraft = nil
                    Task {
                        await viewModel.editAcceptedBlock(
                            withID: updatedDraft.blockID,
                            start: updatedDraft.start,
                            end: updatedDraft.end
                        )
                    }
                },
                onCancel: {
                    scheduledBlockEditDraft = nil
                }
            )
        }
        .alert(item: $scheduledBlockAlert) { alert in
            switch alert.action {
            case .cancel:
                return Alert(
                    title: Text("Cancel Scheduled Block?"),
                    message: Text("This removes the linked calendar event and keeps the block as canceled history."),
                    primaryButton: .destructive(Text("Cancel Block")) {
                        Task {
                            await viewModel.cancelAcceptedBlock(withID: alert.blockID)
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .delete:
                return Alert(
                    title: Text("Delete Scheduled Block?"),
                    message: Text("This removes the linked calendar event and deletes the block record."),
                    primaryButton: .destructive(Text("Delete Block")) {
                        Task {
                            await viewModel.deleteAcceptedBlock(withID: alert.blockID)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.setCalendarStoreChangeObservationEnabled(newPhase == .active)

            guard newPhase == .active else {
                return
            }

            Task {
                await viewModel.handleSceneDidBecomeActive()
            }
        }
        .task {
            viewModel.setCalendarStoreChangeObservationEnabled(scenePhase == .active)
            await viewModel.loadIfNeeded()
        }
    }

    private func moveCalendarBackward() async {
        switch calendarDisplayMode {
        case .day:
            await viewModel.goToPreviousDay()
        case .week:
            await viewModel.goToPreviousWeek()
        case .month:
            await viewModel.goToPreviousMonth()
        }
    }

    private func moveCalendarForward() async {
        switch calendarDisplayMode {
        case .day:
            await viewModel.goToNextDay()
        case .week:
            await viewModel.goToNextWeek()
        case .month:
            await viewModel.goToNextMonth()
        }
    }

    private func makeScheduledBlockEditDraft(
        for blockID: UUID
    ) -> PlannerScheduledBlockEditDraft? {
        guard let block = viewModel.scheduledBlocks.first(where: { $0.id == blockID }) else {
            return nil
        }

        return PlannerScheduledBlockEditDraft(
            blockID: block.id,
            title: viewModel.visibleScheduledBlockItems.first(where: { $0.block.id == blockID })?.taskTitle
                ?? "Scheduled Task",
            originalInterval: block.interval,
            start: block.start,
            end: block.end
        )
    }

    private func handleMorningBriefAction(_ action: PlannerMorningBriefAction) {
        switch action {
        case .requestCalendarAccess:
            Task {
                await viewModel.requestCalendarAccess()
            }
        case .openCalendarSetup:
            isCalendarSetupSheetPresented = true
        case .planToday:
            Task {
                viewModel.selectedPlanningHorizon = .restOfToday
                await viewModel.generatePlan()
            }
        case .reviewTasks:
            break
        }
    }

    @ViewBuilder
    private var plannerContent: some View {
        if calendarDisplayMode == .day {
            VStack(alignment: .leading, spacing: 12) {
                plannerDayCalendarSection
                    .padding(.horizontal, isCompactWidth ? 16 : 20)

                ScrollView {
                    plannerSlotFillerCard
                        .padding(.horizontal, isCompactWidth ? 16 : 20)
                        .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                plannerDayCalendarSection
                    .padding(.horizontal, isCompactWidth ? 16 : 20)

                plannerSlotFillerCard
                    .padding(.horizontal, isCompactWidth ? 16 : 20)
                    .padding(.bottom, 20)
            }
        }
    }

    private var plannerDayCalendarSection: some View {
        PlannerDayCalendarSection(
            displayMode: calendarDisplayMode,
            permissionStatus: viewModel.permissionStatus,
            isLoading: viewModel.isLoading,
            selectedDay: viewModel.selectedDay,
            calendar: viewModel.timelineCalendar,
            visibleDayInterval: viewModel.visibleDayInterval,
            timelineEntries: viewModel.timelineEntries,
            selectedTimeRange: viewModel.selectedTimeRange,
            selectedSlotSuggestionItems: viewModel.selectedSlotSuggestionItems,
            activeSuggestionOperationIDs: viewModel.activeSuggestionOperationIDs,
            onSelectionChange: { selection in
                viewModel.updateSelectedTimeRange(selection)
            },
            onClearSelection: {
                viewModel.clearSelectedTimeRange()
            },
            onAcceptSuggestion: { suggestionID in
                Task {
                    await viewModel.acceptSuggestion(withID: suggestionID)
                }
            },
            onRejectSuggestion: { suggestionID in
                viewModel.rejectSuggestion(withID: suggestionID)
            }
        )
    }

    private var plannerSlotFillerCard: some View {
        PlannerManualSlotFillerCard(
            viewModel: viewModel,
            selectedDay: viewModel.selectedDay,
            selectedTimeRange: viewModel.selectedTimeRange,
            suggestionItems: viewModel.selectedSlotSuggestionItems,
            hasGeneratedSuggestions: viewModel.hasGeneratedSuggestionsForSelectedTimeRange,
            activeSuggestionOperationIDs: viewModel.activeSuggestionOperationIDs,
            onSelectRange: { selection in
                viewModel.updateSelectedTimeRange(selection)
            },
            onGenerateSuggestions: {
                Task {
                    await viewModel.generatePlanForSelectedTimeRange()
                }
            },
            onClearSelection: {
                viewModel.clearSelectedTimeRange()
            },
            onAcceptSuggestion: { suggestionID in
                Task {
                    await viewModel.acceptSuggestion(withID: suggestionID)
                }
            },
            onRejectSuggestion: { suggestionID in
                viewModel.rejectSuggestion(withID: suggestionID)
            }
        )
    }
}

private struct PlannerMorningBriefCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let brief: PlannerMorningBrief
    let selectedEnergy: PlannerMorningEnergy?
    let onSelectEnergy: (PlannerMorningEnergy?) -> Void
    let onAction: (PlannerMorningBriefAction) -> Void

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactWidth ? 14 : 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Morning Brief")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(brief.title)
                        .font(isCompactWidth ? .headline : .title3.weight(.semibold))

                    Text(brief.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: 72), spacing: 10),
                    count: isCompactWidth ? 3 : min(3, max(1, brief.metrics.count))
                ),
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(brief.metrics) { metric in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(metric.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(metric.value)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(brief.calendarStatus, systemImage: "calendar.badge.checkmark")
                Label(brief.scheduledSummary, systemImage: "clock")
                Label(brief.taskSummary, systemImage: "checklist")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Energy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(PlannerMorningEnergy.allCases) { energy in
                        Button {
                            onSelectEnergy(selectedEnergy == energy ? nil : energy)
                        } label: {
                            Text(energy.title)
                                .font(.caption.weight(.semibold))
                                .frame(minWidth: 58)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedEnergy == energy ? .accentColor : .secondary)
                    }
                }
            }

            Divider()

            ViewThatFits {
                HStack(alignment: .center, spacing: 12) {
                    actionCopy
                    Spacer(minLength: 0)
                    actionButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    actionCopy
                    actionButton
                }
            }
        }
        .padding(isCompactWidth ? 16 : 18)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    Color.green.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var actionCopy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(brief.actionTitle)
                .font(.subheadline.weight(.semibold))
            Text(brief.actionMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch brief.action {
        case .requestCalendarAccess, .openCalendarSetup, .planToday:
            Button(brief.actionTitle) {
                onAction(brief.action)
            }
            .buttonStyle(.borderedProminent)
        case .reviewTasks:
            Text("Use the Tasks tab when you are ready.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PlannerCalendarSetupCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let writableCalendars: [ReadableCalendar]
    let selectedWriteCalendarIdentifier: String
    let selectedWriteCalendarTitle: String?
    let onSelectWriteCalendar: (String) -> Void

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calendar Setup")
                        .font(.headline)

                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(selectedWriteCalendarIdentifier.isEmpty ? "Selection Required" : "Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectedWriteCalendarIdentifier.isEmpty ? .orange : .green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (selectedWriteCalendarIdentifier.isEmpty ? Color.orange : Color.green)
                            .opacity(0.12),
                        in: Capsule()
                    )
            }

            if writableCalendars.isEmpty {
                Text("No writable calendars are available. Create or enable an editable iPhone calendar before accepting planner suggestions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker(
                    "Write Accepted Blocks To",
                    selection: Binding(
                        get: { selectedWriteCalendarIdentifier },
                        set: onSelectWriteCalendar
                    )
                ) {
                    Text("Select a Calendar").tag("")

                    ForEach(writableCalendars) { calendar in
                        Text(calendar.title).tag(calendar.id)
                    }
                }
                .pickerStyle(.menu)

                Text(helperText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(isCompactWidth ? 16 : 18)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var statusMessage: String {
        if writableCalendars.isEmpty {
            return "Planner suggestions can only be written back after you have a writable calendar."
        }

        if let selectedWriteCalendarTitle, selectedWriteCalendarIdentifier.isEmpty == false {
            return "Accepted suggestions are written to \(selectedWriteCalendarTitle)."
        }

        if let selectedWriteCalendarTitle {
            return "The saved calendar selection \"\(selectedWriteCalendarTitle)\" needs to be confirmed on this device."
        }

        return "Choose which calendar should receive accepted planner suggestions."
    }

    private var helperText: String {
        if selectedWriteCalendarTitle != nil, selectedWriteCalendarIdentifier.isEmpty == false {
            return "Busy-time reads continue to use every readable calendar that is not excluded by settings."
        }

        if selectedWriteCalendarTitle != nil {
            return "Re-select a writable calendar to replace the older title-based setting."
        }

        return "This is stored by stable calendar identifier, so calendar renames do not break event writes."
    }
}

private struct PlannerOverviewCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let permissionStatus: CalendarPermissionStatus
    let readableCalendarCount: Int
    let selectedDay: Date
    let visibleDayInterval: DateInterval
    let activePlanningRequestWindow: PlannerRequestWindow
    let activePlanningWindow: DateInterval
    let filterState: PlannerFilterState
    let suggestionCount: Int
    let isLoading: Bool
    let onRequestAccess: () -> Void
    let onRefresh: () -> Void
    let onGeneratePlan: () -> Void

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactWidth ? 14 : 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar Planner")
                        .font(isCompactWidth ? .title3.weight(.semibold) : .title2.weight(.semibold))

                    Text(plannerSummaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(calendarStatusLabel)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(calendarStatusTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(calendarStatusTint.opacity(0.12), in: Capsule())
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    PlannerMetricLabel("Visible Day")
                    Text(selectedDay.formatted(date: .complete, time: .omitted))
                }

                GridRow {
                    PlannerMetricLabel("Visible Period")
                    Text(visibleDayInterval.dayLabel)
                }

                GridRow {
                    PlannerMetricLabel("Plan Target")
                    Text("\(activePlanningRequestWindow.title) • \(activePlanningWindow.planningLabel)")
                }

                GridRow {
                    PlannerMetricLabel("Filters")
                    Text(filterState.summaryText)
                }

                GridRow {
                    PlannerMetricLabel("Calendars")
                    Text(
                        permissionStatus == .fullAccessGranted
                        ? "\(readableCalendarCount) readable"
                        : "Waiting for access"
                    )
                }

                GridRow {
                    PlannerMetricLabel("Draft Suggestions")
                    Text(suggestionCount == 0 ? "None yet" : "\(suggestionCount) in memory")
                }
            }

            ViewThatFits {
                HStack(spacing: 12) {
                    overviewActionButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    overviewActionButtons
                }
            }

            Text(planningHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(isCompactWidth ? 16 : 18)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var planningHint: String {
        switch activePlanningRequestWindow {
        case .selectedTimeRange:
            return "Selected-slot planning is active below. Use the secondary horizon flow when you want broader suggestions."
        case .horizon(let horizon):
            #if os(iOS)
            return "Primary flow: press and hold on open time in the day timeline, then drag to fill that slot. Horizon planning is still available for \(horizon.title.lowercased())."
            #else
            return "Primary flow: drag across open time in the day timeline, then fill that slot. Horizon planning is still available for \(horizon.title.lowercased())."
            #endif
        }
    }

    @ViewBuilder
    private var overviewActionButtons: some View {
        Button("Plan by Horizon") {
            onGeneratePlan()
        }
        .buttonStyle(.bordered)
        .disabled(isLoading)

        if permissionStatus != .fullAccessGranted, permissionStatus != .notDetermined {
            Button("Grant Calendar Access") {
                onRequestAccess()
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
        }

        Button("Refresh") {
            onRefresh()
        }
        .buttonStyle(.bordered)
        .disabled(isLoading)
    }

    private var plannerSummaryText: String {
        switch permissionStatus {
        case .fullAccessGranted:
            return "Busy time and accepted planner blocks stay synced with Calendar."
        case .notDetermined:
            return "The planner will prompt for Calendar access the first time it needs live busy time."
        case .writeOnlyGrantedButInsufficient, .denied, .restricted:
            return "Calendar access still needs attention before the planner can read busy time."
        case .error(let message):
            return message
        }
    }

    private var calendarStatusLabel: String {
        if permissionStatus == .fullAccessGranted {
            return readableCalendarCount == 1 ? "1 Calendar" : "\(readableCalendarCount) Calendars"
        }

        return permissionStatus.displayTitle
    }

    private var calendarStatusTint: Color {
        if permissionStatus == .fullAccessGranted {
            return .green
        }

        return permissionStatus.tintColor
    }
}

private struct PlannerMetricLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

private struct PlannerDayNavigationCard: View {
    let selectedDay: Date
    let title: String
    let onPreviousDay: () -> Void
    let onToday: () -> Void
    let onNextDay: () -> Void

    var body: some View {
        ViewThatFits {
            HStack(alignment: .center, spacing: 16) {
                timelineHeading
                Spacer()
                dayNavigationButtons
            }

            VStack(alignment: .leading, spacing: 12) {
                timelineHeading
                dayNavigationButtons
            }
        }
    }

    private var timelineHeading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            Text(selectedDay.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var dayNavigationButtons: some View {
        HStack(spacing: 10) {
            Button(action: onPreviousDay) {
                Label("Previous Day", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)

            Button("Today", action: onToday)
                .buttonStyle(.bordered)

            Button(action: onNextDay) {
                Label("Next Day", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct PlannerDayCalendarSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let displayMode: PlannerCalendarDisplayMode
    let permissionStatus: CalendarPermissionStatus
    let isLoading: Bool
    let selectedDay: Date
    let calendar: Calendar
    let visibleDayInterval: DateInterval
    let timelineEntries: [PlannerTimelineEntry]
    let selectedTimeRange: PlannerSelectedTimeRange?
    let selectedSlotSuggestionItems: [PlannerSuggestionItem]
    let activeSuggestionOperationIDs: Set<UUID>
    let onSelectionChange: (PlannerSelectedTimeRange?) -> Void
    let onClearSelection: () -> Void
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    private var timelineMetrics: PlannerDayTimelineMetrics {
        isCompactWidth ? .compactPhone : PlannerDayTimelineMetrics()
    }

    private let selectionHoldDuration: TimeInterval = 1.0
    private let selectionScrollTolerance: CGFloat = 12

    private var layout: PlannerDayCalendarLayout {
        PlannerDayCalendarLayout(
            dayInterval: visibleDayInterval,
            entries: timelineEntries
        )
    }

    private var shouldShowSelectionOverlay: Bool {
        guard selectedTimeRange != nil else {
            return false
        }

        return selectedSlotSuggestionItems.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Calendar")
                    .font(.headline)

                Spacer()

                if let selectedTimeRange {
                    Text("Fill \(selectedTimeRange.interval.timelineLabel)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())

                    Button("Clear", action: onClearSelection)
                        .buttonStyle(.borderless)
                        .font(.caption)
                } else {
                    Text(selectionHintText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Updating day calendar…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if permissionStatus == .notDetermined {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Preparing calendar access…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if permissionStatus != .fullAccessGranted {
                ContentUnavailableView(
                    "Calendar Access Needed",
                    systemImage: "calendar",
                    description: Text("Turn on Calendar access to render busy time and planner suggestions here.")
                )
                .frame(maxWidth: .infinity)
            } else {
                if layout.allDayEntries.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Day")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        ForEach(layout.allDayEntries, id: \.id) { entry in
                            PlannerAllDayEntryChip(entry: entry)
                        }
                    }
                }

                calendarContent
                .animation(.easeInOut(duration: 0.2), value: timelineEntries.map(\.id))
                .animation(.easeInOut(duration: 0.15), value: selectedTimeRange)
            }
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch displayMode {
        case .day:
            GeometryReader { geometry in
                let contentSize = CGSize(
                    width: geometry.size.width,
                    height: timelineMetrics.totalHeight
                )

                ScrollView(.vertical, showsIndicators: true) {
                    dayCalendarCanvas(totalWidth: contentSize.width)
                        .frame(
                            width: contentSize.width,
                            height: contentSize.height,
                            alignment: .topLeading
                        )
                }
            }
            .frame(height: min(timelineMetrics.totalHeight, isCompactWidth ? 560 : 620))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

        case .week:
            PlannerWeekGridView(
                selectedDay: selectedDay,
                calendar: calendar,
                entries: timelineEntries
            )

        case .month:
            PlannerMonthGridView(
                selectedDay: selectedDay,
                calendar: calendar,
                entries: timelineEntries
            )
        }
    }

    private var occupiedIntervals: [DateInterval] {
        timelineEntries
            .filter { $0.isAllDay == false }
            .map { DateInterval(start: $0.start, end: $0.end) }
    }

    private func dayCalendarCanvas(totalWidth: CGFloat) -> some View {
        let contentSize = CGSize(
            width: totalWidth,
            height: timelineMetrics.totalHeight
        )

        return ZStack(alignment: .topLeading) {
            dayGridBackground(totalWidth: totalWidth)

            selectionCaptureLayer(totalWidth: totalWidth)

            if let selectedTimeRange, shouldShowSelectionOverlay {
                let metrics = selectionMetrics(
                    for: selectedTimeRange,
                    totalWidth: totalWidth
                )

                PlannerDaySelectionBlock(
                    selectedTimeRange: selectedTimeRange,
                    onResizeTop: { point in
                        resizeSelection(edge: .top, point: point, in: contentSize)
                    },
                    onResizeBottom: { point in
                        resizeSelection(edge: .bottom, point: point, in: contentSize)
                    }
                )
                    .frame(width: metrics.width, height: metrics.height)
                    .offset(x: metrics.x, y: metrics.y)
            }

            ForEach(layout.timedEntries) { item in
                let metrics = blockMetrics(
                    for: item,
                    totalWidth: totalWidth
                )

                PlannerDayCalendarBlock(
                    entry: item.entry,
                    isProcessingSuggestion: item.entry.suggestionID.map(activeSuggestionOperationIDs.contains) ?? false,
                    onAcceptSuggestion: onAcceptSuggestion,
                    onRejectSuggestion: onRejectSuggestion
                )
                    .frame(width: metrics.width, height: metrics.height)
                    .offset(x: metrics.x, y: metrics.y)
            }
        }
        .coordinateSpace(name: "plannerDayCalendarCanvas")
    }

    @ViewBuilder
    private func selectionCaptureLayer(totalWidth: CGFloat) -> some View {
        let contentSize = CGSize(
            width: totalWidth,
            height: timelineMetrics.totalHeight
        )

        #if os(iOS)
        PlannerSelectionGestureOverlay(
            contentSize: contentSize,
            minimumPressDuration: selectionHoldDuration,
            allowableMovement: selectionScrollTolerance
        ) { anchorPoint, currentPoint in
            updateSelection(
                anchorPoint: anchorPoint,
                currentPoint: currentPoint,
                in: contentSize
            )
        }
        .frame(width: totalWidth, height: timelineMetrics.totalHeight)
        #else
        Color.clear
            .frame(width: totalWidth, height: timelineMetrics.totalHeight)
            .contentShape(Rectangle())
            .simultaneousGesture(selectionGesture(in: contentSize))
        #endif
    }

    private func selectionGesture(in contentSize: CGSize) -> some Gesture {
        #if os(iOS)
        LongPressGesture(
            minimumDuration: selectionHoldDuration,
            maximumDistance: selectionScrollTolerance
        )
        .sequenced(before: DragGesture(minimumDistance: 0))
        .onChanged { value in
            switch value {
            case .second(true, let drag?):
                updateSelection(
                    anchorPoint: drag.startLocation,
                    currentPoint: drag.location,
                    in: contentSize
                )
            default:
                break
            }
        }
        .onEnded { value in
            switch value {
            case .second(true, let drag?):
                updateSelection(
                    anchorPoint: drag.startLocation,
                    currentPoint: drag.location,
                    in: contentSize
                )
            default:
                break
            }
        }
        #else
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                updateSelection(
                    anchorPoint: value.startLocation,
                    currentPoint: value.location,
                    in: contentSize
                )
            }
            .onEnded { value in
                updateSelection(
                    anchorPoint: value.startLocation,
                    currentPoint: value.location,
                    in: contentSize
                )
            }
        #endif
    }

    private func updateSelection(
        anchorPoint: CGPoint,
        currentPoint: CGPoint,
        in contentSize: CGSize
    ) {
        let selection = PlannerTimelineGrid.selectedRange(
            anchorPoint: anchorPoint,
            currentPoint: currentPoint,
            in: contentSize,
            metrics: timelineMetrics,
            day: selectedDay,
            calendar: calendar,
            occupiedIntervals: occupiedIntervals
        )
        onSelectionChange(selection)
    }

    private func resizeSelection(
        edge: PlannerSelectionResizeEdge,
        point: CGPoint,
        in contentSize: CGSize
    ) {
        guard let selectedTimeRange else {
            return
        }

        let selection = PlannerTimelineGrid.resizedRange(
            selectedTimeRange,
            edge: edge,
            point: point,
            in: contentSize,
            metrics: timelineMetrics,
            day: selectedDay,
            calendar: calendar,
            occupiedIntervals: occupiedIntervals
        )
        onSelectionChange(selection)
    }

    private func dayGridBackground(totalWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.025),
                    Color.primary.opacity(0.045)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: timelineMetrics.timedAreaHeight)
                .offset(x: timelineMetrics.contentStartX - 6, y: timelineMetrics.topInset)

            ForEach(0...PlannerTimelineGrid.slotsPerDay, id: \.self) { slotBoundary in
                Rectangle()
                    .fill(slotBoundary.isMultiple(of: PlannerTimelineGrid.slotsPerHour)
                        ? Color.primary.opacity(0.12)
                        : Color.primary.opacity(0.05))
                    .frame(
                        width: max(totalWidth - timelineMetrics.contentStartX, 0),
                        height: slotBoundary.isMultiple(of: PlannerTimelineGrid.slotsPerHour) ? 1 : 0.5
                    )
                    .offset(
                        x: timelineMetrics.contentStartX,
                        y: timelineMetrics.topInset + CGFloat(slotBoundary) * timelineMetrics.slotHeight
                    )
            }

            ForEach(0..<24, id: \.self) { hour in
                Text(hourLabel(for: hour))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: timelineMetrics.timeColumnWidth, alignment: .trailing)
                    .offset(
                        x: 0,
                        y: timelineMetrics.topInset + CGFloat(hour) * timelineMetrics.hourHeight - 7
                    )
            }
        }
    }

    private func hourLabel(for hour: Int) -> String {
        let normalizedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let meridiem = hour < 12 ? "AM" : "PM"
        return "\(normalizedHour) \(meridiem)"
    }

    private func blockMetrics(
        for item: PlannerDayCalendarLayoutItem,
        totalWidth: CGFloat
    ) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let usableWidth = max(totalWidth - timelineMetrics.timeColumnWidth - 16, 0)
        let laneCount = max(item.laneCount, 1)
        let columnWidth = max(
            (usableWidth - (CGFloat(laneCount - 1) * timelineMetrics.laneSpacing)) / CGFloat(laneCount),
            0
        )
        let dayStart = visibleDayInterval.start
        let minutesFromStart = max(item.entry.start.timeIntervalSince(dayStart) / 60, 0)
        let durationMinutes = max(item.entry.end.timeIntervalSince(item.entry.start) / 60, 0)

        return (
            x: timelineMetrics.timeColumnWidth + timelineMetrics.contentLeadingInset
                + CGFloat(item.laneIndex) * (columnWidth + timelineMetrics.laneSpacing),
            y: timelineMetrics.topInset + CGFloat(minutesFromStart / 60) * timelineMetrics.hourHeight,
            width: columnWidth,
            height: max(CGFloat(durationMinutes / 60) * timelineMetrics.hourHeight, 28)
        )
    }

    private func selectionMetrics(
        for selectedTimeRange: PlannerSelectedTimeRange,
        totalWidth: CGFloat
    ) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let startSlotIndex = PlannerTimelineGrid.slotIndex(
            for: selectedTimeRange.start,
            on: selectedDay,
            calendar: calendar
        )
        let slotCount = max(selectedTimeRange.durationMinutes / PlannerTimelineGrid.slotMinutes, 1)

        return (
            x: timelineMetrics.contentStartX + 2,
            y: timelineMetrics.topInset + CGFloat(startSlotIndex) * timelineMetrics.slotHeight,
            width: max(totalWidth - timelineMetrics.contentStartX - 4, 0),
            height: CGFloat(slotCount) * timelineMetrics.slotHeight
        )
    }

    private var selectionHintText: String {
        #if os(iOS)
        return "Press and hold on open time, then drag to plan a slot"
        #else
        return "Drag across open time to plan a slot"
        #endif
    }
}

#if os(iOS)
private struct PlannerSelectionGestureOverlay: UIViewRepresentable {
    let contentSize: CGSize
    let minimumPressDuration: TimeInterval
    let allowableMovement: CGFloat
    let onSelectionChange: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.allowableMovement = allowableMovement
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)

        context.coordinator.contentSize = contentSize
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.contentSize = contentSize
        context.coordinator.onSelectionChange = onSelectionChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(contentSize: contentSize, onSelectionChange: onSelectionChange)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var contentSize: CGSize
        var onSelectionChange: (CGPoint, CGPoint) -> Void
        private var anchorPoint: CGPoint?

        init(
            contentSize: CGSize,
            onSelectionChange: @escaping (CGPoint, CGPoint) -> Void
        ) {
            self.contentSize = contentSize
            self.onSelectionChange = onSelectionChange
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard let view = recognizer.view else {
                return
            }

            let currentPoint = clampedPoint(recognizer.location(in: view))

            switch recognizer.state {
            case .began:
                anchorPoint = currentPoint
                onSelectionChange(currentPoint, currentPoint)
            case .changed:
                guard let anchorPoint else {
                    return
                }

                onSelectionChange(anchorPoint, currentPoint)
            case .ended:
                if let anchorPoint {
                    onSelectionChange(anchorPoint, currentPoint)
                }
                anchorPoint = nil
            case .cancelled, .failed:
                anchorPoint = nil
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func clampedPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(point.x, 0), contentSize.width),
                y: min(max(point.y, 0), contentSize.height)
            )
        }
    }
}
#endif

private struct PlannerSelectedSlotActionBar: View {
    let selectedTimeRange: PlannerSelectedTimeRange
    let hasGeneratedSuggestions: Bool
    let suggestionCount: Int
    let isLoading: Bool
    let canGenerate: Bool
    let onGenerateSuggestions: () -> Void
    let onClearSelection: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTimeRange.interval.timelineLabel)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("Clear", action: onClearSelection)
                .buttonStyle(.bordered)
                .disabled(isLoading)

            Button("Fill", action: onGenerateSuggestions)
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || canGenerate == false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var statusText: String {
        if hasGeneratedSuggestions {
            return suggestionCount == 1 ? "1 suggestion" : "\(suggestionCount) suggestions"
        }

        return "\(selectedTimeRange.durationMinutes) minutes selected"
    }
}

private struct PlannerWeekGridView: View {
    let selectedDay: Date
    let calendar: Calendar
    let entries: [PlannerTimelineEntry]

    private var weekDays: [Date] {
        let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDay)
        let start = interval?.start ?? calendar.startOfDay(for: selectedDay)

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7),
            spacing: 1
        ) {
            ForEach(weekDays, id: \.self) { day in
                PlannerCalendarDayCell(
                    day: day,
                    calendar: calendar,
                    entries: entriesForDay(day),
                    isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                    isInDisplayedMonth: true
                )
                .frame(minHeight: 132)
            }
        }
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func entriesForDay(_ day: Date) -> [PlannerTimelineEntry] {
        entries.filter { entry in
            entry.isAllDay
                ? calendar.isDate(entry.start, inSameDayAs: day)
                : entry.end > calendar.startOfDay(for: day)
                    && entry.start < (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))
                        ?? calendar.startOfDay(for: day).addingTimeInterval(86_400))
        }
    }
}

private struct PlannerMonthGridView: View {
    let selectedDay: Date
    let calendar: Calendar
    let entries: [PlannerTimelineEntry]

    private var displayedDays: [Date] {
        let monthInterval = calendar.dateInterval(of: .month, for: selectedDay)
        let monthStart = monthInterval?.start ?? calendar.startOfDay(for: selectedDay)
        let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart

        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7),
            spacing: 1
        ) {
            ForEach(displayedDays, id: \.self) { day in
                PlannerCalendarDayCell(
                    day: day,
                    calendar: calendar,
                    entries: entriesForDay(day),
                    isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                    isInDisplayedMonth: calendar.isDate(day, equalTo: selectedDay, toGranularity: .month)
                )
                .frame(minHeight: 86)
            }
        }
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func entriesForDay(_ day: Date) -> [PlannerTimelineEntry] {
        entries.filter { entry in
            entry.isAllDay
                ? calendar.isDate(entry.start, inSameDayAs: day)
                : entry.end > calendar.startOfDay(for: day)
                    && entry.start < (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))
                        ?? calendar.startOfDay(for: day).addingTimeInterval(86_400))
        }
    }
}

private struct PlannerCalendarDayCell: View {
    let day: Date
    let calendar: Calendar
    let entries: [PlannerTimelineEntry]
    let isSelected: Bool
    let isInDisplayedMonth: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dayNumber)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(dayNumberStyle)
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Color.accentColor : Color.clear, in: Circle())

                Spacer(minLength: 0)
            }

            ForEach(entries.prefix(3)) { entry in
                Text(entry.dayCalendarTitle)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(isInDisplayedMonth ? Color.primary : Color.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(entry.dayCalendarTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
            }

            if entries.count > 3 {
                Text("+\(entries.count - 3) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isInDisplayedMonth ? Color.plannerSurfaceBackground : Color.primary.opacity(0.03))
    }

    private var dayNumber: String {
        day.formatted(.dateTime.day())
    }

    private var dayNumberStyle: Color {
        if isSelected {
            return .white
        }

        return isInDisplayedMonth ? .primary : .secondary
    }
}

private extension Color {
    static var plannerSurfaceBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

private struct PlannerTimelineSection: View {
    let permissionStatus: CalendarPermissionStatus
    let isLoading: Bool
    let timelineEntries: [PlannerTimelineEntry]
    let activeSuggestionOperationIDs: Set<UUID>
    let activeScheduledBlockOperationIDs: Set<UUID>
    let selectedTimeRange: PlannerSelectedTimeRange?
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void
    let onEditScheduledBlock: (UUID) -> Void
    let onRescheduleScheduledBlock: (UUID) -> Void
    let onCancelScheduledBlock: (UUID) -> Void
    let onDeleteScheduledBlock: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agenda")
                .font(.headline)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading calendar events…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if permissionStatus == .notDetermined {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Preparing calendar…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if permissionStatus != .fullAccessGranted {
                ContentUnavailableView(
                    "Calendar Access Needed",
                    systemImage: "calendar",
                    description: Text("Turn on Calendar access to load busy time into the planner.")
                )
                .frame(maxWidth: .infinity)
            } else if timelineEntries.isEmpty {
                ContentUnavailableView(
                    "No Events or Suggestions",
                    systemImage: "calendar",
                    description: Text("This day is currently open. Select a time range to fill a slot, or use the secondary horizon planner.")
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(timelineEntries) { entry in
                        PlannerTimelineRow(
                            entry: entry,
                            isProcessingSuggestion: entry.suggestionID.map(activeSuggestionOperationIDs.contains) ?? false,
                            isProcessingScheduledBlock: entry.scheduledBlockID.map(activeScheduledBlockOperationIDs.contains) ?? false,
                            selectedTimeRange: selectedTimeRange,
                            onAcceptSuggestion: onAcceptSuggestion,
                            onRejectSuggestion: onRejectSuggestion,
                            onEditScheduledBlock: onEditScheduledBlock,
                            onRescheduleScheduledBlock: onRescheduleScheduledBlock,
                            onCancelScheduledBlock: onCancelScheduledBlock,
                            onDeleteScheduledBlock: onDeleteScheduledBlock
                        )
                    }
                }
            }
        }
    }
}

private struct PlannerAllDayEntryChip: View {
    let entry: PlannerTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.dayCalendarTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(entry.dayCalendarBadge)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(entry.dayCalendarTint.opacity(0.14), in: Capsule())
            }

            Text(entry.dayCalendarSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry.dayCalendarTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PlannerTimelineRow: View {
    let entry: PlannerTimelineEntry
    let isProcessingSuggestion: Bool
    let isProcessingScheduledBlock: Bool
    let selectedTimeRange: PlannerSelectedTimeRange?
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void
    let onEditScheduledBlock: (UUID) -> Void
    let onRescheduleScheduledBlock: (UUID) -> Void
    let onCancelScheduledBlock: (UUID) -> Void
    let onDeleteScheduledBlock: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(primaryTimeLabel)
                    .font(.subheadline.weight(.medium))

                if let secondaryTimeLabel {
                    Text(secondaryTimeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)

            entryContent
        }
    }

    @ViewBuilder
    private var entryContent: some View {
        switch entry {
        case .calendarEvent(let event):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(event.title)
                        .font(.headline)

                    Spacer()

                    Text(event.calendarTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }

                Text(event.timelineLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(entry.rowTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .scheduledBlock(let block):
            PlannerScheduledBlockCard(
                block: block,
                selectedTimeRange: selectedTimeRange,
                isProcessing: isProcessingScheduledBlock,
                onEdit: onEditScheduledBlock,
                onReschedule: onRescheduleScheduledBlock,
                onCancel: onCancelScheduledBlock,
                onDelete: onDeleteScheduledBlock
            )

        case .suggestion(let suggestion):
            PlannerSuggestionCard(
                suggestion: suggestion,
                isProcessingSuggestion: isProcessingSuggestion,
                onAcceptSuggestion: onAcceptSuggestion,
                onRejectSuggestion: onRejectSuggestion
            )
        }
    }

    private var primaryTimeLabel: String {
        switch entry {
        case .calendarEvent(let event):
            return event.isAllDay ? "All Day" : event.start.formatted(date: .omitted, time: .shortened)
        case .scheduledBlock(let block):
            return block.interval.start.formatted(date: .omitted, time: .shortened)
        case .suggestion(let suggestion):
            return suggestion.interval.start.formatted(date: .omitted, time: .shortened)
        }
    }

    private var secondaryTimeLabel: String? {
        switch entry {
        case .calendarEvent(let event):
            return event.isAllDay ? nil : event.end.formatted(date: .omitted, time: .shortened)
        case .scheduledBlock(let block):
            return block.interval.end.formatted(date: .omitted, time: .shortened)
        case .suggestion(let suggestion):
            return suggestion.interval.end.formatted(date: .omitted, time: .shortened)
        }
    }

    private var accentColor: Color {
        entry.rowTint
    }
}

private struct PlannerDayCalendarBlock: View {
    let entry: PlannerTimelineEntry
    let isProcessingSuggestion: Bool
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.dayCalendarTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)

                Text(entry.dayCalendarTimeRange)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.dayCalendarBadge)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(entry.dayCalendarTint.opacity(0.16), in: Capsule())
                    .fixedSize()

                Spacer(minLength: 0)
            }
            .padding(.trailing, suggestionID == nil ? 0 : 52)

            if let suggestionID {
                PlannerSuggestionInlineActionStrip(
                    suggestionID: suggestionID,
                    isProcessing: isProcessingSuggestion,
                    onAcceptSuggestion: onAcceptSuggestion,
                    onRejectSuggestion: onRejectSuggestion
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(entry.dayCalendarFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(entry.dayCalendarStroke, lineWidth: 1)
        )
    }

    private var suggestionID: UUID? {
        entry.suggestionID
    }
}

private struct PlannerDaySelectionBlock: View {
    let selectedTimeRange: PlannerSelectedTimeRange
    let onResizeTop: (CGPoint) -> Void
    let onResizeBottom: (CGPoint) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.orange)

                Text(selectedTimeRange.interval.timelineLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(10)

            VStack(spacing: 0) {
                PlannerSelectionResizeHandle(edge: .top, onResize: onResizeTop)

                Spacer(minLength: 0)

                PlannerSelectionResizeHandle(edge: .bottom, onResize: onResizeBottom)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }
}

private struct PlannerSelectionResizeHandle: View {
    let edge: PlannerSelectionResizeEdge
    let onResize: (CGPoint) -> Void

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 24)
            .contentShape(Rectangle())
            .overlay(alignment: edge == .top ? .top : .bottom) {
                Capsule()
                    .fill(Color.orange)
                    .frame(width: 42, height: 5)
                    .padding(.vertical, 5)
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("plannerDayCalendarCanvas"))
                    .onChanged { value in
                        onResize(value.location)
                    }
                    .onEnded { value in
                        onResize(value.location)
                    }
            )
    }
}

private struct PlannerManualSlotFillerCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject var viewModel: PlannerViewModel
    let selectedDay: Date
    let selectedTimeRange: PlannerSelectedTimeRange?
    let suggestionItems: [PlannerSuggestionItem]
    let hasGeneratedSuggestions: Bool
    let activeSuggestionOperationIDs: Set<UUID>
    let onSelectRange: (PlannerSelectedTimeRange?) -> Void
    let onGenerateSuggestions: () -> Void
    let onClearSelection: () -> Void
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    @State private var draftStart = Date.now
    @State private var draftEnd = Date.now.addingTimeInterval(60 * 60)

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    private var draftRange: PlannerSelectedTimeRange? {
        PlannerSelectedTimeRange(start: draftStart, end: draftEnd)
    }

    private var validationMessage: String? {
        guard draftRange != nil else {
            return "End time must be after start time."
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactWidth ? 14 : 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Detailed Task Filler")
                        .font(.headline)

                    Text(selectedRangeSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if selectedTimeRange != nil {
                    Button("Clear", action: onClearSelection)
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .disabled(viewModel.isLoading)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                DatePicker(
                    "Start",
                    selection: $draftStart,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)

                DatePicker(
                    "End",
                    selection: $draftEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }

            ViewThatFits {
                HStack(alignment: .center, spacing: 12) {
                    filterControls
                }

                VStack(alignment: .leading, spacing: 10) {
                    filterControls
                }
            }

            if viewModel.availableTags.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                PlannerFilterTagChip(
                                    title: tag,
                                    isSelected: viewModel.filterState.selectedTags.contains(tag)
                                ) {
                                    let isEnabled = viewModel.filterState.selectedTags.contains(tag) == false
                                    viewModel.setSelectedTag(tag, isEnabled: isEnabled)
                                }
                            }
                        }
                    }
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            ViewThatFits {
                HStack(spacing: 12) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    actionButtons
                }
            }

            if hasGeneratedSuggestions {
                if suggestionItems.isEmpty {
                    Text("No matching tasks fit this time span.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(suggestionItems.count == 1 ? "Suggested Task" : "Suggested Tasks")
                            .font(.subheadline.weight(.medium))

                        ForEach(suggestionItems) { suggestion in
                            PlannerSuggestionCard(
                                suggestion: suggestion,
                                isProcessingSuggestion: activeSuggestionOperationIDs.contains(suggestion.id),
                                onAcceptSuggestion: onAcceptSuggestion,
                                onRejectSuggestion: onRejectSuggestion
                            )
                        }
                    }
                }
            }
        }
        .padding(isCompactWidth ? 16 : 18)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    Color.orange.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear(perform: syncDraftWithSelectionOrDay)
        .onChange(of: selectedDay) { _, _ in
            syncDraftWithSelectionOrDay()
        }
        .onChange(of: selectedTimeRange) { _, newSelection in
            guard let newSelection else {
                return
            }

            draftStart = newSelection.start
            draftEnd = newSelection.end
        }
    }

    @ViewBuilder
    private var filterControls: some View {
        LabeledContent("Mode") {
            Picker("Work Mode", selection: selectedWorkModeBinding) {
                Text("Any").tag(nil as WorkModeKind?)

                ForEach(viewModel.availableWorkModes, id: \.self) { workMode in
                    Text(workMode.displayName).tag(Optional(workMode))
                }
            }
            .pickerStyle(.menu)
        }

        LabeledContent("Priority") {
            Picker("Priority Emphasis", selection: selectedPriorityEmphasisBinding) {
                ForEach(PlannerPriorityEmphasis.allCases) { emphasis in
                    Text(emphasis.title).tag(emphasis)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Use Time Span") {
            onSelectRange(draftRange)
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isLoading || validationMessage != nil)

        Button("Fill Tasks") {
            onSelectRange(draftRange)
            onGenerateSuggestions()
        }
        .buttonStyle(.borderedProminent)
        .disabled(
            viewModel.isLoading
                || validationMessage != nil
                || viewModel.permissionStatus != .fullAccessGranted
        )
    }

    private var selectedWorkModeBinding: Binding<WorkModeKind?> {
        Binding {
            viewModel.filterState.workMode
        } set: { workMode in
            viewModel.filterState.workMode = workMode
        }
    }

    private var selectedPriorityEmphasisBinding: Binding<PlannerPriorityEmphasis> {
        Binding {
            viewModel.filterState.priorityEmphasis
        } set: { emphasis in
            viewModel.filterState.priorityEmphasis = emphasis
        }
    }

    private var selectedRangeSummary: String {
        if let selectedTimeRange {
            return "\(selectedTimeRange.interval.timelineLabel) selected"
        }

        return "Choose an exact time span, then narrow the kind of task you want."
    }

    private func syncDraftWithSelectionOrDay() {
        if let selectedTimeRange {
            draftStart = selectedTimeRange.start
            draftEnd = selectedTimeRange.end
            return
        }

        let calendar = viewModel.timelineCalendar
        let dayStart = calendar.startOfDay(for: selectedDay)
        let now = Date.now

        let defaultStart: Date
        if calendar.isDate(selectedDay, inSameDayAs: now), now > dayStart {
            let minute = calendar.component(.minute, from: now)
            let minutesToNextSlot = PlannerTimelineGrid.slotMinutes - (minute % PlannerTimelineGrid.slotMinutes)
            defaultStart = calendar.date(
                byAdding: .minute,
                value: minutesToNextSlot == PlannerTimelineGrid.slotMinutes ? 0 : minutesToNextSlot,
                to: now
            ) ?? now
        } else {
            defaultStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart)
                ?? dayStart.addingTimeInterval(9 * 60 * 60)
        }

        draftStart = defaultStart
        draftEnd = defaultStart.addingTimeInterval(60 * 60)
    }
}

private struct PlannerSlotPlanningCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject var viewModel: PlannerViewModel
    let selectedTimeRange: PlannerSelectedTimeRange
    let suggestionItems: [PlannerSuggestionItem]
    let hasGeneratedSuggestions: Bool
    let activeSuggestionOperationIDs: Set<UUID>
    let onGenerateSuggestions: () -> Void
    let onClearSelection: () -> Void
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fill \(selectedTimeRange.interval.timelineLabel)")
                        .font(.headline)

                    Text("\(selectedTimeRange.durationMinutes) minutes available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear", action: onClearSelection)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Work Mode")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Work Mode", selection: selectedWorkModeBinding) {
                        Text("Any").tag(nil as WorkModeKind?)

                        ForEach(viewModel.availableWorkModes, id: \.self) { workMode in
                            Text(workMode.displayName).tag(Optional(workMode))
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Priority")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Priority Emphasis", selection: selectedPriorityEmphasisBinding) {
                        ForEach(PlannerPriorityEmphasis.allCases) { emphasis in
                            Text(emphasis.title).tag(emphasis)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Spacer()

                Button("Get Suggestions", action: onGenerateSuggestions)
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading || viewModel.permissionStatus != .fullAccessGranted)
            }

            if viewModel.availableTags.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                PlannerFilterTagChip(
                                    title: tag,
                                    isSelected: viewModel.filterState.selectedTags.contains(tag)
                                ) {
                                    let isEnabled = viewModel.filterState.selectedTags.contains(tag) == false
                                    viewModel.setSelectedTag(tag, isEnabled: isEnabled)
                                }
                            }
                        }
                    }
                }
            }

            Text(slotStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if hasGeneratedSuggestions {
                if suggestionItems.isEmpty {
                    Text("No tasks fit this selected slot with the current filters. Try a longer slot, fewer filters, or a smaller task.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(suggestionItems.count == 1 ? "Suggestion" : "Suggestions")
                            .font(.subheadline.weight(.medium))

                        ForEach(suggestionItems) { suggestion in
                            PlannerSuggestionCard(
                                suggestion: suggestion,
                                isProcessingSuggestion: activeSuggestionOperationIDs.contains(suggestion.id),
                                onAcceptSuggestion: onAcceptSuggestion,
                                onRejectSuggestion: onRejectSuggestion
                            )
                        }
                    }
                }
            }
        }
        .padding(isCompactWidth ? 16 : 18)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private var selectedWorkModeBinding: Binding<WorkModeKind?> {
        Binding {
            viewModel.filterState.workMode
        } set: { workMode in
            viewModel.filterState.workMode = workMode
        }
    }

    private var selectedPriorityEmphasisBinding: Binding<PlannerPriorityEmphasis> {
        Binding {
            viewModel.filterState.priorityEmphasis
        } set: { emphasis in
            viewModel.filterState.priorityEmphasis = emphasis
        }
    }

    private var slotStatusText: String {
        if hasGeneratedSuggestions {
            return "Suggestions stay inside this exact \(selectedTimeRange.interval.timelineLabel) window and continue to use the current planner fit rules. Accept or reject them inline on the calendar or from the list below."
        }

        return "Select the slot first, add light constraints second, then ask the planner to fill exactly this window."
    }
}

private struct PlannerScheduledBlockCard: View {
    let block: PlannerScheduledBlockItem
    let selectedTimeRange: PlannerSelectedTimeRange?
    let isProcessing: Bool
    let onEdit: (UUID) -> Void
    let onReschedule: (UUID) -> Void
    let onCancel: (UUID) -> Void
    let onDelete: (UUID) -> Void

    private var canRescheduleToSelection: Bool {
        guard let selectedTimeRange else {
            return false
        }

        return selectedTimeRange.interval != block.interval
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(block.taskTitle)
                    .font(.headline)

                Spacer()

                Text(block.block.linkStateBadgeTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(block.block.linkStateTint.opacity(0.14), in: Capsule())
            }

            Text(block.interval.timelineLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let stateMessage = block.block.linkStateMessage {
                Text(stateMessage)
                    .font(.caption)
                    .foregroundStyle(block.block.linkStateTint)
            }

            ViewThatFits {
                HStack(spacing: 10) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 8) {
                    actionButtons
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(block.block.linkStateTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Edit") {
            onEdit(block.id)
        }
        .buttonStyle(.bordered)
        .disabled(isProcessing)

        Button("Move to Selected Slot") {
            onReschedule(block.id)
        }
        .buttonStyle(.bordered)
        .disabled(isProcessing || canRescheduleToSelection == false)

        Button("Cancel", role: .destructive) {
            onCancel(block.id)
        }
        .buttonStyle(.bordered)
        .disabled(isProcessing)

        Button("Delete", role: .destructive) {
            onDelete(block.id)
        }
        .buttonStyle(.bordered)
        .disabled(isProcessing)
    }
}

private struct PlannerScheduledBlockEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlannerScheduledBlockEditDraft

    let isSaving: Bool
    let onSave: (PlannerScheduledBlockEditDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: PlannerScheduledBlockEditDraft,
        isSaving: Bool,
        onSave: @escaping (PlannerScheduledBlockEditDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Block") {
                    Text(draft.title)
                        .font(.headline)

                    Text(draft.originalInterval.timelineLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Timing") {
                    DatePicker(
                        "Start",
                        selection: $draft.start,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "End",
                        selection: $draft.end,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                if let validationMessage = draft.validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Scheduled Block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(isSaving || draft.validationMessage != nil)
                }
            }
        }
    }
}

private struct PlannerSuggestionCard: View {
    let suggestion: PlannerSuggestionItem
    let isProcessingSuggestion: Bool
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.taskTitle)
                        .font(.headline)

                    Text(suggestion.interval.timelineLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(suggestionBadgeTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.18), in: Capsule())
            }

            Text(suggestion.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    onAcceptSuggestion(suggestion.id)
                } label: {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .disabled(isProcessingSuggestion)

                Button(role: .destructive) {
                    onRejectSuggestion(suggestion.id)
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isProcessingSuggestion)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var suggestionBadgeTitle: String {
        if isProcessingSuggestion {
            return "Saving..."
        }

        switch suggestion.decision {
        case .pending:
            return "Suggestion"
        case .accepted:
            return "Accepted"
        }
    }
}

private struct PlannerSuggestionInlineActionStrip: View {
    let suggestionID: UUID
    let isProcessing: Bool
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    var body: some View {
        Group {
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.7), in: Circle())
            } else {
                HStack(spacing: 6) {
                    inlineActionButton(
                        systemName: "checkmark.circle.fill",
                        tint: .green,
                        accessibilityLabel: "Accept suggestion"
                    ) {
                        onAcceptSuggestion(suggestionID)
                    }

                    inlineActionButton(
                        systemName: "xmark.circle.fill",
                        tint: .red,
                        accessibilityLabel: "Reject suggestion"
                    ) {
                        onRejectSuggestion(suggestionID)
                    }
                }
            }
        }
        .padding(8)
    }

    private func inlineActionButton(
        systemName: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.72), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PlannerFilterTagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct HorizonPlanSheet: View {
    @ObservedObject var viewModel: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.permissionStatus != .fullAccessGranted {
                    Section("Calendar Access") {
                        Text(viewModel.permissionStatus.displayTitle)
                            .font(.headline)
                            .foregroundStyle(viewModel.permissionStatus.tintColor)

                        Text(viewModel.permissionStatus.detailText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if viewModel.permissionStatus != .notDetermined {
                            Button("Grant Calendar Access") {
                                Task {
                                    await viewModel.requestCalendarAccess()
                                }
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                }

                Section("Planning Horizon") {
                    Picker("Window", selection: $viewModel.selectedPlanningHorizon) {
                        ForEach(PlannerHorizon.allCases) { horizon in
                            Text(horizon.title).tag(horizon)
                        }
                    }

                    Text(viewModel.selectedHorizonPlanningWindow.planningLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Task Filters") {
                    Picker("Work Mode", selection: selectedWorkModeBinding) {
                        Text("Any").tag(nil as WorkModeKind?)

                        ForEach(viewModel.availableWorkModes, id: \.self) { workMode in
                            Text(workMode.displayName).tag(Optional(workMode))
                        }
                    }

                    Picker("Priority Emphasis", selection: selectedPriorityEmphasisBinding) {
                        ForEach(PlannerPriorityEmphasis.allCases) { emphasis in
                            Text(emphasis.title).tag(emphasis)
                        }
                    }

                    if viewModel.availableTags.isEmpty {
                        Text("No task tags are available yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.availableTags, id: \.self) { tag in
                            Toggle(tag, isOn: tagBinding(for: tag))
                        }
                    }

                    Text("These filters shape the first-pass planner ranking for transient suggestions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Plan by Horizon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        Task {
                            await viewModel.generatePlan()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.permissionStatus != .fullAccessGranted)
                }
            }
        }
    }

    private var selectedWorkModeBinding: Binding<WorkModeKind?> {
        Binding {
            viewModel.filterState.workMode
        } set: { workMode in
            viewModel.filterState.workMode = workMode
        }
    }

    private var selectedPriorityEmphasisBinding: Binding<PlannerPriorityEmphasis> {
        Binding {
            viewModel.filterState.priorityEmphasis
        } set: { emphasis in
            viewModel.filterState.priorityEmphasis = emphasis
        }
    }

    private func tagBinding(for tag: String) -> Binding<Bool> {
        Binding {
            viewModel.filterState.selectedTags.contains(tag)
        } set: { isEnabled in
            viewModel.setSelectedTag(tag, isEnabled: isEnabled)
        }
    }
}

private struct PlannerScheduledBlockEditDraft: Identifiable {
    let blockID: UUID
    let title: String
    let originalInterval: DateInterval
    var start: Date
    var end: Date

    var id: UUID {
        blockID
    }

    var validationMessage: String? {
        guard end > start else {
            return "End time must be after the start time."
        }

        return nil
    }
}

private struct PlannerScheduledBlockAlert: Identifiable {
    enum Action {
        case cancel
        case delete
    }

    let blockID: UUID
    let action: Action

    var id: String {
        "\(blockID.uuidString)-\(action)"
    }
}

private extension CalendarPermissionStatus {
    var displayTitle: String {
        switch self {
        case .notDetermined:
            return "Preparing Calendar"
        case .fullAccessGranted:
            return "Calendar Ready"
        case .writeOnlyGrantedButInsufficient:
            return "Needs Full Access"
        case .denied:
            return "Calendar Access Needed"
        case .restricted:
            return "Calendar Restricted"
        case .error:
            return "Calendar Unavailable"
        }
    }

    var detailText: String {
        switch self {
        case .notDetermined:
            return "The planner will ask for Calendar access as soon as it needs live busy time."
        case .fullAccessGranted:
            return "Real calendar events show up as busy time, and accepted suggestions write back to the selected calendar."
        case .writeOnlyGrantedButInsufficient:
            return "Write-only permission is not enough. The planner needs full access to read busy time."
        case .denied:
            return "Turn Calendar access back on in Settings to show busy time and planner suggestions."
        case .restricted:
            return "Calendar access is restricted on this device."
        case .error(let message):
            return message
        }
    }

    var tintColor: Color {
        switch self {
        case .fullAccessGranted:
            return .green
        case .notDetermined:
            return .secondary
        case .writeOnlyGrantedButInsufficient, .restricted:
            return .orange
        case .denied, .error:
            return .red
        }
    }
}

private extension PlannerTimelineEntry {
    var suggestionID: UUID? {
        switch self {
        case .calendarEvent:
            return nil
        case .scheduledBlock:
            return nil
        case .suggestion(let item):
            return item.id
        }
    }

    var scheduledBlockID: UUID? {
        switch self {
        case .scheduledBlock(let item):
            return item.id
        case .calendarEvent, .suggestion:
            return nil
        }
    }

    var dayCalendarTitle: String {
        switch self {
        case .calendarEvent(let event):
            return event.title
        case .scheduledBlock(let item):
            return item.taskTitle
        case .suggestion(let suggestion):
            return suggestion.taskTitle
        }
    }

    var dayCalendarSubtitle: String {
        switch self {
        case .calendarEvent(let event):
            return event.calendarTitle
        case .scheduledBlock(let item):
            return item.block.calendarTitle ?? "Accepted scheduled block"
        case .suggestion(let suggestion):
            return suggestion.explanation
        }
    }

    var dayCalendarBadge: String {
        switch self {
        case .calendarEvent(let event):
            return event.calendarTitle
        case .scheduledBlock(let item):
            return item.block.linkStateBadgeTitle
        case .suggestion:
            return "Suggestion"
        }
    }

    var dayCalendarTint: Color {
        switch self {
        case .calendarEvent:
            return .blue
        case .scheduledBlock(let item):
            return item.block.linkStateTint
        case .suggestion:
            return .gray
        }
    }

    var dayCalendarFill: Color {
        switch self {
        case .calendarEvent:
            return dayCalendarTint.opacity(0.14)
        case .scheduledBlock:
            return dayCalendarTint.opacity(0.18)
        case .suggestion:
            return dayCalendarTint.opacity(0.1)
        }
    }

    var dayCalendarStroke: Color {
        switch self {
        case .calendarEvent:
            return dayCalendarTint.opacity(0.28)
        case .scheduledBlock:
            return dayCalendarTint.opacity(0.36)
        case .suggestion:
            return dayCalendarTint.opacity(0.24)
        }
    }

    var rowTint: Color {
        switch self {
        case .calendarEvent:
            return .blue
        case .scheduledBlock(let item):
            return item.block.linkStateTint
        case .suggestion:
            return .gray
        }
    }

    var dayCalendarTimeRange: String {
        switch self {
        case .calendarEvent(let event):
            return event.isAllDay ? "All day" : event.interval.timelineLabel
        case .scheduledBlock(let item):
            return item.interval.timelineLabel
        case .suggestion(let suggestion):
            return suggestion.interval.timelineLabel
        }
    }
}

private extension ScheduledBlock {
    var linkStateBadgeTitle: String {
        switch calendarLinkState {
        case .linked:
            return calendarTitle ?? "Scheduled"
        case .movedExternally:
            return "Moved in Calendar"
        case .syncError:
            return "Sync Error"
        case .identifierStale:
            return "Missing Link"
        case .deletedExternally:
            return "Deleted Externally"
        case .writePending:
            return "Syncing"
        case .notWritten:
            return "Canceled"
        }
    }

    var linkStateMessage: String? {
        switch calendarLinkState {
        case .movedExternally:
            return "The linked calendar event was changed outside the app. This block now mirrors the calendar copy."
        case .syncError, .identifierStale:
            return syncErrorMessage
        case .deletedExternally:
            return "The linked calendar event was deleted outside the app."
        case .linked, .writePending, .notWritten:
            return nil
        }
    }

    var linkStateTint: Color {
        switch calendarLinkState {
        case .linked, .writePending:
            return .mint
        case .movedExternally:
            return .orange
        case .syncError, .identifierStale, .deletedExternally:
            return .red
        case .notWritten:
            return .gray
        }
    }
}

private extension PlannerFilterState {
    var summaryText: String {
        let workModeText = workMode?.displayName ?? "Any work mode"
        let tagsText: String

        if selectedTags.isEmpty {
            tagsText = "Any tags"
        } else {
            tagsText = selectedTags.sorted().joined(separator: ", ")
        }

        return "\(workModeText) • \(priorityEmphasis.title) • \(tagsText)"
    }
}

private extension DateInterval {
    var dayLabel: String {
        "\(start.formatted(date: .abbreviated, time: .omitted)) • 12:00 AM – 11:59 PM"
    }

    var planningLabel: String {
        let startLabel = start.formatted(date: .abbreviated, time: .shortened)
        let endLabel = end.formatted(date: .abbreviated, time: .shortened)
        return "\(startLabel) – \(endLabel)"
    }

    var timelineLabel: String {
        let startLabel = start.formatted(date: .omitted, time: .shortened)
        let endLabel = end.formatted(date: .omitted, time: .shortened)
        return "\(startLabel) – \(endLabel)"
    }
}

private extension CalendarEventSnapshot {
    var timelineLabel: String {
        if isAllDay {
            return "All-day calendar event"
        }

        return interval.timelineLabel
    }
}

private struct PlannerDayCalendarLayout {
    let allDayEntries: [PlannerTimelineEntry]
    let timedEntries: [PlannerDayCalendarLayoutItem]

    init(
        dayInterval: DateInterval,
        entries: [PlannerTimelineEntry]
    ) {
        let visibleEntries = entries.filter { entry in
            entry.isAllDay || entry.end > dayInterval.start && entry.start < dayInterval.end
        }

        allDayEntries = visibleEntries.filter(\.isAllDay)

        let sortedTimedEntries = visibleEntries
            .filter { $0.isAllDay == false }
            .sorted { lhs, rhs in
                if lhs.start != rhs.start {
                    return lhs.start < rhs.start
                }

                if lhs.end != rhs.end {
                    return lhs.end < rhs.end
                }

                return lhs.id < rhs.id
            }

        var laidOutEntries: [PlannerDayCalendarLayoutItem] = []
        var cluster: [PlannerTimelineEntry] = []
        var clusterEnd: Date?

        for entry in sortedTimedEntries {
            if let currentClusterEnd = clusterEnd, entry.start < currentClusterEnd {
                cluster.append(entry)
                if entry.end > currentClusterEnd {
                    clusterEnd = entry.end
                }
            } else {
                laidOutEntries += Self.layoutCluster(cluster)
                cluster = [entry]
                clusterEnd = entry.end
            }
        }

        laidOutEntries += Self.layoutCluster(cluster)
        timedEntries = laidOutEntries
    }

    private static func layoutCluster(
        _ cluster: [PlannerTimelineEntry]
    ) -> [PlannerDayCalendarLayoutItem] {
        guard cluster.isEmpty == false else {
            return []
        }

        var laneEnds: [Date] = []
        var assignments: [(entry: PlannerTimelineEntry, laneIndex: Int)] = []

        for entry in cluster {
            if let laneIndex = laneEnds.firstIndex(where: { $0 <= entry.start }) {
                laneEnds[laneIndex] = entry.end
                assignments.append((entry: entry, laneIndex: laneIndex))
            } else {
                laneEnds.append(entry.end)
                assignments.append((entry: entry, laneIndex: laneEnds.count - 1))
            }
        }

        let laneCount = max(laneEnds.count, 1)
        return assignments.map { assignment in
            PlannerDayCalendarLayoutItem(
                entry: assignment.entry,
                laneIndex: assignment.laneIndex,
                laneCount: laneCount
            )
        }
    }
}

private struct PlannerDayCalendarLayoutItem: Identifiable {
    let entry: PlannerTimelineEntry
    let laneIndex: Int
    let laneCount: Int

    var id: String {
        entry.id
    }
}

#Preview("Planner Loaded") {
    let previewContainer = AppContainer.makePreview(
        seedTasks: [
            MyTask(
                title: "Write project update",
                estimatedMinutes: 45,
                priority: .high,
                workMode: .shallowAdmin,
                tags: ["work", "writing"]
            ),
            MyTask(
                title: "Deep work on planner engine",
                estimatedMinutes: 90,
                priority: .urgent,
                workMode: .deepWork,
                tags: ["work", "planning"]
            ),
            MyTask(
                title: "Grocery run",
                estimatedMinutes: 30,
                priority: .medium,
                workMode: .errand,
                tags: ["home"]
            ),
        ]
    )

    PlannerView(
        taskRepository: previewContainer.taskRepository,
        scheduledBlockRepository: previewContainer.scheduledBlockRepository,
        settingsRepository: previewContainer.settingsRepository,
        calendarPermissionProvider: StubCalendarPermissionService(status: .fullAccessGranted),
        calendarListingService: StubCalendarListingService(
            calendars: [
                ReadableCalendar(
                    id: "work",
                    title: "Work",
                    allowsContentModifications: true,
                    isExcludedBySettings: false
                ),
                ReadableCalendar(
                    id: "personal",
                    title: "Personal",
                    allowsContentModifications: true,
                    isExcludedBySettings: false
                ),
            ]
        ),
        calendarReader: StubCalendarReader(
            events: [
                CalendarEventSnapshot(
                    identifier: "standup",
                    title: "Team Standup",
                    start: Date.now.addingTimeInterval(60 * 60),
                    end: Date.now.addingTimeInterval(90 * 60),
                    isAllDay: false,
                    calendarTitle: "Work"
                ),
                CalendarEventSnapshot(
                    identifier: "lunch",
                    title: "Lunch",
                    start: Date.now.addingTimeInterval(4 * 60 * 60),
                    end: Date.now.addingTimeInterval(5 * 60 * 60),
                    isAllDay: false,
                    calendarTitle: "Personal"
                ),
            ]
        ),
        calendarWriter: StubCalendarWriter(),
        calendarReconciler: StubCalendarReconciler(),
        calendarChangeObserver: StubCalendarChangeObserver(),
        promiseRepository: previewContainer.promiseRepository
    )
}
